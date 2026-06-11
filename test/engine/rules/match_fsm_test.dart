import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/entities/shuttle.dart';
import 'package:smash_bros/engine/math/fix.dart';
import 'package:smash_bros/engine/math/fix_vec2.dart';
import 'package:smash_bros/engine/rules/match_fsm.dart';
import 'package:smash_bros/engine/rules/match_phase.dart';
import 'package:smash_bros/engine/rules/point_reason.dart';
import 'package:smash_bros/engine/systems/collision_system.dart';
import 'package:smash_bros/engine/systems/rally_state.dart';

const _court = Court();

// Court geometry (from constants.dart): netX = 640, groundY = 600,
// bounds [40, 1240], shortServeLineLeft = 440, shortServeLineRight = 840.

GroundHit _groundIn(double x) => GroundHit(
  landingX: Fix.of(x),
  side: _court.sideOfX(Fix.of(x)),
  isInBounds: true,
);

GroundHit _groundOut(double x) => GroundHit(
  landingX: Fix.of(x),
  side: _court.sideOfX(Fix.of(x)),
  isInBounds: false,
);

NetBodyHit _netBody() => const NetBodyHit(FixVec2(Fix.of(640), Fix.of(450)));
NetCordHit _netCord() => const NetCordHit(FixVec2(Fix.of(640), Fix.of(352)));

RallyState _rally({CourtSide? lastHitter}) =>
    RallyState(lastHitter: lastHitter);

/// Drives the FSM from preMatch into inPlay with [server] serving.
MatchFsm _inPlay({CourtSide server = CourtSide.left}) =>
    MatchFsm(firstServer: server)
      ..startMatch(0)
      ..onServeTossed(1);

void main() {
  group('MatchFsm happy path', () {
    test('full point lifecycle with a logged transition trail', () {
      final fsm = MatchFsm()
        ..startMatch(0)
        ..onServeTossed(1);
      expect(fsm.phase, MatchPhase.inPlay);

      // A deep serve from left lands in-bounds on the right (receiver) side,
      // past the short line (840) -> groundedIn, point AGAINST the right side
      // i.e. to the server (left).
      fsm.onCollisionEvents(
        50,
        [_groundIn(1000)],
        _rally(lastHitter: CourtSide.left),
        _court,
      );
      expect(fsm.phase, MatchPhase.pointScored);
      expect(fsm.pointWinner, CourtSide.left);
      expect(fsm.lastPointReason, PointReason.groundedIn);
      expect(fsm.scoreboard.leftScore, 1);

      // Pause out the presentation.
      for (var f = 51; f < 51 + kPointPauseTicks; f++) {
        fsm.tickPointPause(f);
      }
      expect(fsm.phase, MatchPhase.servePending);
      expect(fsm.server, CourtSide.left, reason: 'point winner serves next');
      expect(fsm.serveTimerTicks, 0);

      // Transition log records every hop with frames and reasons.
      final hops = fsm.transitions;
      expect(hops.length, 4);
      expect(hops[0].from, MatchPhase.preMatch);
      expect(hops[0].to, MatchPhase.servePending);
      expect(hops[0].frame, 0);
      expect(hops[1].to, MatchPhase.inPlay);
      expect(hops[1].frame, 1);
      expect(hops[2].to, MatchPhase.pointScored);
      expect(hops[2].frame, 50);
      expect(hops[3].to, MatchPhase.servePending);
      expect(hops[3].frame, 50 + kPointPauseTicks);
    });
  });

  group('Serve faults', () {
    test('serve timeout faults the server -> point to receiver', () {
      final fsm = MatchFsm()..startMatch(0);
      for (var f = 1; f <= kServeTimeoutFrames; f++) {
        fsm.tickServeTimer(f);
      }
      expect(fsm.phase, MatchPhase.pointScored);
      expect(fsm.pointWinner, CourtSide.right);
      expect(fsm.lastPointReason, PointReason.serveTimeoutFault);
      expect(fsm.scoreboard.rightScore, 1);
    });

    test(
      'serve net-cord is a LET: back to servePending, same server, no score',
      () {
        final fsm = _inPlay()
          ..onCollisionEvents(20, [_netCord()], _rally(), _court);
        expect(fsm.phase, MatchPhase.servePending);
        expect(fsm.server, CourtSide.left);
        expect(fsm.scoreboard.leftScore, 0);
        expect(fsm.scoreboard.rightScore, 0);
        expect(fsm.transitions.last.to, MatchPhase.servePending);
        expect(fsm.transitions.last.reason, contains('let'));
      },
    );

    test('serve net-body faults the server -> point to receiver', () {
      final fsm = _inPlay()
        ..onCollisionEvents(20, [_netBody()], _rally(), _court);
      expect(fsm.phase, MatchPhase.pointScored);
      expect(fsm.pointWinner, CourtSide.right);
      expect(fsm.lastPointReason, PointReason.serveNetFault);
    });

    test('short serve (left server -> right receiver, lands short) faults', () {
      // Right receiver short line is 840; landing at 700 is short.
      final fsm = _inPlay()
        ..onCollisionEvents(
          20,
          [_groundIn(700)],
          _rally(lastHitter: CourtSide.left),
          _court,
        );
      expect(fsm.pointWinner, CourtSide.right);
      expect(fsm.lastPointReason, PointReason.shortServeFault);
    });

    test('short serve (right server -> left receiver, lands short) faults', () {
      // Left receiver short line is 440; landing at 600 (closer to net) is
      // short for a leftward serve.
      final fsm = _inPlay(server: CourtSide.right)
        ..onCollisionEvents(
          20,
          [_groundIn(600)],
          _rally(lastHitter: CourtSide.right),
          _court,
        );
      expect(fsm.pointWinner, CourtSide.left);
      expect(fsm.lastPointReason, PointReason.shortServeFault);
    });

    test('deep serve clears the short line -> normal groundedIn', () {
      // Lands at 900 on the right, past the 840 short line.
      final fsm = _inPlay()
        ..onCollisionEvents(
          20,
          [_groundIn(900)],
          _rally(lastHitter: CourtSide.left),
          _court,
        );
      expect(fsm.lastPointReason, PointReason.groundedIn);
      expect(fsm.pointWinner, CourtSide.left);
    });
  });

  group('Mid-rally outcomes', () {
    test(
      'onServeReturned switches net-body from serveNetFault to netFault',
      () {
        // While the serve is live a net-body hit is a serveNetFault; once the
        // receiver returns it, the same event is a mid-rally netFault instead.
        final fsm = _inPlay()
          ..onServeReturned(2)
          ..onCollisionEvents(
            50,
            [_netBody()],
            _rally(lastHitter: CourtSide.right),
            _court,
          );
        expect(fsm.lastPointReason, PointReason.netFault);
        expect(fsm.pointWinner, CourtSide.left);
      },
    );

    test('mid-rally net-cord: no phase change, no point', () {
      final fsm = _midRally(lastHitter: CourtSide.right)
        ..onCollisionEvents(80, [_netCord()], _rally(), _court);
      expect(fsm.phase, MatchPhase.inPlay);
      expect(fsm.scoreboard.leftScore, 0);
      expect(fsm.scoreboard.rightScore, 0);
    });

    test('mid-rally net-body faults the last hitter', () {
      final fsm = _midRally(lastHitter: CourtSide.right)
        ..onCollisionEvents(
          80,
          [_netBody()],
          _rally(lastHitter: CourtSide.right),
          _court,
        );
      expect(fsm.phase, MatchPhase.pointScored);
      expect(fsm.pointWinner, CourtSide.left);
      expect(fsm.lastPointReason, PointReason.netFault);
    });

    test('groundedOut faults the last hitter (they hit it out)', () {
      // Lands out of bounds; right hit it out -> point to left.
      final fsm = _midRally(lastHitter: CourtSide.right)
        ..onCollisionEvents(
          80,
          [_groundOut(20)],
          _rally(lastHitter: CourtSide.right),
          _court,
        );
      expect(fsm.phase, MatchPhase.pointScored);
      expect(fsm.pointWinner, CourtSide.left);
      expect(fsm.lastPointReason, PointReason.groundedOut);
    });
  });

  group('Match over', () {
    test('winning the last point ends the match after the pause', () {
      // Right serves; drive right to target-1 (10) wins, then win point 11.
      final fsm = MatchFsm(firstServer: CourtSide.right);
      fsm.scoreboard
        ..leftScore = 5
        ..rightScore = 10;
      // Deep serve from right lands in on the left (receiver) -> point to the
      // right (server). Left receiver short line 440; land deep at 200.
      fsm
        ..startMatch(0)
        ..onServeTossed(1)
        ..onCollisionEvents(
          30,
          [_groundIn(200)],
          _rally(lastHitter: CourtSide.right),
          _court,
        );
      expect(fsm.scoreboard.rightScore, 11);
      expect(fsm.phase, MatchPhase.pointScored);

      for (var f = 31; f < 31 + kPointPauseTicks; f++) {
        fsm.tickPointPause(f);
      }
      expect(fsm.phase, MatchPhase.matchOver);
      expect(fsm.scoreboard.winner, CourtSide.right);
    });
  });

  group('Invalid-phase calls', () {
    test('onServeTossed outside servePending asserts', () {
      final fsm = MatchFsm();
      expect(() => fsm.onServeTossed(0), throwsA(isA<AssertionError>()));
    });

    test('startMatch outside preMatch asserts', () {
      final fsm = MatchFsm()..startMatch(0);
      expect(() => fsm.startMatch(1), throwsA(isA<AssertionError>()));
    });

    test('tick methods are inert outside their phase', () {
      final fsm = MatchFsm()
        ..tickServeTimer(0)
        ..tickPointPause(0);
      expect(fsm.serveTimerTicks, 0);
      expect(fsm.pointPauseTicks, 0);
      expect(fsm.phase, MatchPhase.preMatch);
      // Collision events outside inPlay are also inert.
      fsm.onCollisionEvents(0, [_netBody()], _rally(), _court);
      expect(fsm.phase, MatchPhase.preMatch);
    });
  });

  group('PhaseTransition', () {
    test('has value equality', () {
      const a = PhaseTransition(
        frame: 5,
        from: MatchPhase.preMatch,
        to: MatchPhase.servePending,
        reason: 'x',
      );
      const b = PhaseTransition(
        frame: 5,
        from: MatchPhase.preMatch,
        to: MatchPhase.servePending,
        reason: 'x',
      );
      const c = PhaseTransition(
        frame: 6,
        from: MatchPhase.preMatch,
        to: MatchPhase.servePending,
        reason: 'x',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  group('resolveSimultaneousSwing', () {
    test('returns the side the shuttle is on (both directions)', () {
      final left = Shuttle(
        position: const FixVec2(Fix.of(300), Fix.of(300)),
      );
      final right = Shuttle(
        position: const FixVec2(Fix.of(900), Fix.of(300)),
      );
      expect(
        MatchFsm.resolveSimultaneousSwing(left, _court),
        CourtSide.left,
      );
      expect(
        MatchFsm.resolveSimultaneousSwing(right, _court),
        CourtSide.right,
      );
    });
  });

  group('MatchFsm.copy', () {
    test('is independent including the transition log and scoreboard', () {
      final original = _inPlay()
        ..onCollisionEvents(
          40,
          [_groundIn(1000)],
          _rally(lastHitter: CourtSide.left),
          _court,
        );
      final snapshot = original.copy();

      // Mutate the original after the snapshot.
      for (var f = 41; f < 41 + kPointPauseTicks; f++) {
        original.tickPointPause(f);
      }

      expect(snapshot.phase, MatchPhase.pointScored);
      expect(snapshot.scoreboard.leftScore, 1);
      expect(snapshot.transitions.length, 3);
      // The original advanced one more transition past the snapshot.
      expect(original.transitions.length, 4);
    });
  });
}

/// Builds an FSM in [MatchPhase.inPlay] whose live flight is a rally (not the
/// serve): the serve has been tossed and the receiver has returned it via
/// [MatchFsm.onServeReturned], so subsequent collision events follow the
/// mid-rally rules rather than the serve-fault rules.
MatchFsm _midRally({required CourtSide lastHitter}) {
  // The server is whichever side is not the eventual rally last-hitter; the
  // exact server is irrelevant to these mid-rally branch tests.
  final server = lastHitter == CourtSide.right
      ? CourtSide.left
      : CourtSide.right;
  return MatchFsm(firstServer: server)
    ..startMatch(0)
    ..onServeTossed(1)
    ..onServeReturned(2);
}
