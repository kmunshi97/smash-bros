import 'package:meta/meta.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/entities/shuttle.dart';
import 'package:smash_bros/engine/math/fix.dart';
import 'package:smash_bros/engine/rules/match_phase.dart';
import 'package:smash_bros/engine/rules/point_reason.dart';
import 'package:smash_bros/engine/rules/scoreboard.dart';
import 'package:smash_bros/engine/systems/collision_system.dart';
import 'package:smash_bros/engine/systems/rally_state.dart';

/// One logged phase change, recording when and why the FSM moved (M1-013).
///
/// Every [MatchPhase] change in [MatchFsm] is appended to its transition log as
/// one of these, so a replay or debugger can reconstruct exactly how a match
/// progressed and on which frame each decision landed. Value-equal.
@immutable
final class PhaseTransition {
  /// Creates a transition from [from] to [to] on [frame] with a [reason].
  const PhaseTransition({
    required this.frame,
    required this.from,
    required this.to,
    required this.reason,
  });

  /// The simulation frame the transition happened on.
  final int frame;

  /// The phase the FSM moved out of.
  final MatchPhase from;

  /// The phase the FSM moved into.
  final MatchPhase to;

  /// A short human-readable explanation of why the transition happened.
  final String reason;

  @override
  bool operator ==(Object other) =>
      other is PhaseTransition &&
      other.frame == frame &&
      other.from == from &&
      other.to == to &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(frame, from, to, reason);

  @override
  String toString() =>
      'PhaseTransition(frame: $frame, $from -> $to, reason: $reason)';
}

/// The rules brain of a match: the serve/rally/scoring finite-state machine
/// (M1-013/014/015/016).
///
/// ## Contract
///
/// The FSM **consumes facts** — collision events from the [CollisionSystem],
/// serve-timer ticks, point-pause ticks — and **produces decisions** — phase
/// changes and point awards. It never touches entities, physics or randomness:
/// it reads geometric facts the Simulation hands it and updates the
/// [Scoreboard], the current [phase], and who [server] is. The Simulation (a
/// later PR) is the only caller and is also responsible for resetting entities
/// (player positions, the [RallyState], the shuttle) between phases.
///
/// Every phase change flows through one private `_transition`, which appends a
/// [PhaseTransition] to the log, satisfying M1-013's "every transition logged
/// with frame number".
///
/// ## Invalid-phase policy
///
/// Calls that represent a *programmer* error — driving an input from the wrong
/// phase that the Simulation should never issue, e.g. [onServeTossed] outside
/// [MatchPhase.servePending] — assert in debug. Calls that are simply
/// per-tick pumps ([tickServeTimer], [tickPointPause], [onCollisionEvents])
/// are inert no-ops outside their relevant phase, because the Simulation pumps
/// them every tick regardless of phase.
final class MatchFsm {
  /// Creates a match in [MatchPhase.preMatch] with [firstServer] to serve and
  /// a fresh scoreboard playing to [targetScore].
  MatchFsm({
    CourtSide firstServer = CourtSide.left,
    int targetScore = kDefaultTargetScore,
  }) : server = firstServer,
       scoreboard = Scoreboard(targetScore: targetScore);

  /// The current lifecycle phase.
  MatchPhase phase = MatchPhase.preMatch;

  /// The side that serves the current (or next) point.
  CourtSide server;

  /// The running score and win arithmetic.
  final Scoreboard scoreboard;

  /// Ticks elapsed in [MatchPhase.servePending] waiting for a toss.
  int serveTimerTicks = 0;

  /// Ticks elapsed in [MatchPhase.pointScored] presenting the point.
  int pointPauseTicks = 0;

  /// The winner of the most recently scored point (for the HUD), or `null`
  /// before the first point.
  CourtSide? pointWinner;

  /// The reason the most recent point was awarded (for the HUD), or `null`
  /// before the first point.
  PointReason? lastPointReason;

  /// Whether the live flight is the serve, enabling serve-specific net and
  /// short-serve rules. Set true on [onServeTossed], cleared once a point is
  /// scored or a net-cord LET sends the serve back to pending.
  bool _serveRallyActive = false;

  final List<PhaseTransition> _transitions = <PhaseTransition>[];

  /// The logged phase transitions, oldest first (unmodifiable view).
  List<PhaseTransition> get transitions =>
      List<PhaseTransition>.unmodifiable(_transitions);

  /// The side receiving the current serve (the opposite of [server]).
  CourtSide get receiver =>
      server == CourtSide.left ? CourtSide.right : CourtSide.left;

  /// Starts the match: [MatchPhase.preMatch] -> [MatchPhase.servePending],
  /// resetting the serve timer. Only legal from [MatchPhase.preMatch].
  void startMatch(int frame) {
    assert(
      phase == MatchPhase.preMatch,
      'startMatch is only valid from preMatch (was $phase)',
    );
    serveTimerTicks = 0;
    _transition(frame, MatchPhase.servePending, 'match started');
  }

  /// Records the serve toss: [MatchPhase.servePending] -> [MatchPhase.inPlay],
  /// marking the live flight as the serve. Only legal from
  /// [MatchPhase.servePending].
  void onServeTossed(int frame) {
    assert(
      phase == MatchPhase.servePending,
      'onServeTossed is only valid from servePending (was $phase)',
    );
    _serveRallyActive = true;
    _transition(frame, MatchPhase.inPlay, 'serve tossed');
  }

  /// Ends the serve-specific rules: the receiver has legally returned the
  /// serve, so the flight is now an ordinary rally.
  ///
  /// A clean serve that clears the net produces no collision event, so the FSM
  /// has no implicit signal that the serve has been returned. The Simulation
  /// (the sole caller) calls this the tick the receiver's return connects,
  /// after which net-cord/net-body/short events follow the mid-rally rules
  /// rather than the serve-fault rules. Idempotent and inert outside
  /// [MatchPhase.inPlay]; [frame] is accepted for signature symmetry but no
  /// transition is logged because the phase does not change.
  void onServeReturned(int frame) {
    if (phase != MatchPhase.inPlay) return;
    _serveRallyActive = false;
  }

  /// Advances the serve timer one tick while in [MatchPhase.servePending].
  ///
  /// On reaching [kServeTimeoutFrames] the server is faulted: the receiver
  /// wins the point with [PointReason.serveTimeoutFault]. Inert in any other
  /// phase.
  void tickServeTimer(int frame) {
    if (phase != MatchPhase.servePending) return;
    serveTimerTicks += 1;
    if (serveTimerTicks >= kServeTimeoutFrames) {
      _awardPoint(frame, receiver, PointReason.serveTimeoutFault);
    }
  }

  /// Resolves this tick's collision [events] against the match rules while in
  /// [MatchPhase.inPlay]. Inert in any other phase.
  ///
  /// Acts on the first decisive event in the natural order the
  /// [CollisionSystem] reports them (ascending sweep parameter). [rally]
  /// supplies the last hitter for out/net attribution; [court] supplies the
  /// geometry for line and short-serve calls.
  void onCollisionEvents(
    int frame,
    List<CollisionEvent> events,
    RallyState rally,
    Court court,
  ) {
    if (phase != MatchPhase.inPlay) return;

    for (final event in events) {
      switch (event) {
        case NetCordHit():
          if (_serveRallyActive) {
            // A net-cord clip on the serve is a LET: replay with the same
            // server, no score change.
            _serveRallyActive = false;
            serveTimerTicks = 0;
            _transition(
              frame,
              MatchPhase.servePending,
              'serve let (net cord)',
            );
            return;
          }
          // Mid-rally net-cord: play on. The collision system already damped
          // the shuttle; the rules do nothing.
          return;

        case NetBodyHit():
          if (_serveRallyActive) {
            _awardPoint(frame, receiver, PointReason.serveNetFault);
          } else {
            _awardPoint(
              frame,
              _opposite(rally.lastHitter),
              PointReason.netFault,
            );
          }
          return;

        case GroundHit(:final landingX, :final side, :final isInBounds):
          if (_serveRallyActive &&
              isInBounds &&
              side == receiver &&
              _isShortServe(landingX, court)) {
            _awardPoint(frame, receiver, PointReason.shortServeFault);
            return;
          }
          if (isInBounds) {
            // Lands IN on [side] -> the OTHER side wins the point.
            _awardPoint(frame, _other(side), PointReason.groundedIn);
          } else {
            // Out of bounds -> the side that hit it last sent it out.
            _awardPoint(
              frame,
              _opposite(rally.lastHitter),
              PointReason.groundedOut,
            );
          }
          return;
      }
    }
  }

  /// Advances the point-presentation pause one tick while in
  /// [MatchPhase.pointScored]. Inert in any other phase.
  ///
  /// On reaching [kPointPauseTicks] the FSM either ends the match
  /// ([MatchPhase.matchOver]) if the scoreboard has a winner, or sets up the
  /// next serve ([MatchPhase.servePending]) with the point winner serving
  /// (v3 ruleset: the winner of the point serves next).
  void tickPointPause(int frame) {
    if (phase != MatchPhase.pointScored) return;
    pointPauseTicks += 1;
    if (pointPauseTicks < kPointPauseTicks) return;

    final gameWinner = scoreboard.winner;
    if (gameWinner != null) {
      _transition(frame, MatchPhase.matchOver, 'match won by $gameWinner');
    } else {
      server = pointWinner!;
      serveTimerTicks = 0;
      _transition(
        frame,
        MatchPhase.servePending,
        'next serve (server: $server)',
      );
    }
  }

  /// Resolves a simultaneous swing (M1-015): when both players press a shot on
  /// the same frame and both could connect, priority goes to the player on the
  /// shuttle's current side of the net.
  ///
  /// Pure helper returning that side via [Court.sideOfX]. The Simulation
  /// consults it to decide whose `trySwing` executes first that frame.
  static CourtSide resolveSimultaneousSwing(Shuttle shuttle, Court court) =>
      court.sideOfX(shuttle.position.x);

  /// A deep, independent copy for the rollback snapshot buffer, including the
  /// scoreboard, the serve flag, and the transition log.
  MatchFsm copy() {
    final clone =
        MatchFsm(
            firstServer: server,
            targetScore: scoreboard.targetScore,
          )
          ..phase = phase
          ..serveTimerTicks = serveTimerTicks
          ..pointPauseTicks = pointPauseTicks
          ..pointWinner = pointWinner
          ..lastPointReason = lastPointReason
          .._serveRallyActive = _serveRallyActive
          ..scoreboard.leftScore = scoreboard.leftScore
          ..scoreboard.rightScore = scoreboard.rightScore;
    clone._transitions.addAll(_transitions);
    return clone;
  }

  /// Awards a point to [winner] for [reason], moving the FSM into
  /// [MatchPhase.pointScored] and resetting the point pause.
  void _awardPoint(int frame, CourtSide winner, PointReason reason) {
    scoreboard.award(winner);
    pointWinner = winner;
    lastPointReason = reason;
    pointPauseTicks = 0;
    _serveRallyActive = false;
    _transition(frame, MatchPhase.pointScored, 'point $winner ($reason)');
  }

  /// Whether an in-bounds serve landing at [landingX] on the receiver's side
  /// fell short of the receiver's short-service line.
  ///
  /// The short-service line is the *minimum depth* a serve must reach on the
  /// receiver's half. Geometry (with the net at `court.netX`):
  ///
  /// * a serve to the LEFT receiver travels leftward and must land deep enough,
  ///   i.e. at `landingX <= shortServeLineLeft` (= netX - 200); landing with a
  ///   *larger* x (closer to the net) is short.
  /// * a serve to the RIGHT receiver travels rightward and must land at
  ///   `landingX >= shortServeLineRight` (= netX + 200); landing with a
  ///   *smaller* x (closer to the net) is short.
  bool _isShortServe(Fix landingX, Court court) {
    final line = court.shortServeLineFor(receiver);
    return receiver == CourtSide.left ? landingX > line : landingX < line;
  }

  /// The opposite of [side].
  CourtSide _other(CourtSide side) =>
      side == CourtSide.left ? CourtSide.right : CourtSide.left;

  /// The side opposite [hitter]; falls back to the [receiver] when [hitter] is
  /// `null`.
  ///
  /// In live play [RallyState.lastHitter] is always set once the serve is
  /// tossed (the toss is itself a hit by the server), so a `null` hitter on a
  /// net/out fault cannot normally occur. The fallback to the receiver keeps
  /// the rule total: an "out serve" with no recorded hitter still awards the
  /// point to the receiver, which is the same answer the natural path gives
  /// once the server is the last hitter.
  CourtSide _opposite(CourtSide? hitter) =>
      hitter == null ? receiver : _other(hitter);

  /// Logs and applies a single phase change.
  void _transition(int frame, MatchPhase to, String reason) {
    _transitions.add(
      PhaseTransition(frame: frame, from: phase, to: to, reason: reason),
    );
    phase = to;
  }
}
