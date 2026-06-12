import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/entities/player.dart';
import 'package:smash_bros/engine/entities/shuttle.dart';
import 'package:smash_bros/engine/input/input_buffer.dart';
import 'package:smash_bros/engine/math/fix.dart';
import 'package:smash_bros/engine/math/fix_vec2.dart';
import 'package:smash_bros/engine/random/game_random.dart';
import 'package:smash_bros/engine/rules/match_fsm.dart';
import 'package:smash_bros/engine/systems/rally_state.dart';

/// The single root of **all** simulation state (M1-017).
///
/// ## Contract
///
/// Every mutable thing the simulation reads or writes lives here: the two
/// [Player]s, the [Shuttle], the [RallyState], the [MatchFsm], the seeded
/// [GameRandom], and both players' [InputBuffer]s. The [Court] is the one const
/// member (it holds no mutable state). Nothing in the engine keeps simulation
/// state outside this object, which is what makes [copy] a complete rollback
/// snapshot and [debugSignature] a complete desync hash.
///
/// ## Determinism
///
/// The only source of randomness is [random]; it is seeded through the
/// constructor and snapshotted by [copy]. Two [GameState]s built from the same
/// seed and driven by the same inputs stay byte-identical forever, which
/// [debugSignature] lets a test (or the M3 netcode) verify frame by frame.
final class GameState {
  /// Creates the start-of-match state.
  ///
  /// [seed] feeds the [GameRandom]. [firstServer] is the side that serves the
  /// opening point; [targetScore] is the points-to-win the [MatchFsm] plays to.
  /// Players spawn at their start x facing each other across the net (the left
  /// player faces right, the right player faces left), the shuttle sits at the
  /// origin with zero velocity (the Simulation places it for the serve), and
  /// the FSM begins in [MatchFsm]'s `preMatch` phase.
  GameState({
    required int seed,
    CourtSide firstServer = CourtSide.left,
    int targetScore = kDefaultTargetScore,
  }) : frame = 0,
       serveChargeTicks = 0,
       court = const Court(),
       random = GameRandom(seed),
       leftPlayer = Player(
         x: const Fix.of(kPlayer1StartX),
         courtSide: CourtSide.left,
         // facing defaults to Facing.right — the left player faces the net.
       ),
       rightPlayer = Player(
         x: const Fix.of(kPlayer2StartX),
         courtSide: CourtSide.right,
         facing: Facing.left,
       ),
       shuttle = Shuttle(position: FixVec2.zero),
       rally = RallyState(),
       fsm = MatchFsm(firstServer: firstServer, targetScore: targetScore),
       leftInputs = InputBuffer(),
       rightInputs = InputBuffer();

  /// Private constructor used by [copy] to rebuild from already-deep-copied
  /// members without re-running start-of-match initialisation.
  GameState._({
    required this.frame,
    required this.serveChargeTicks,
    required this.leftPlayer,
    required this.rightPlayer,
    required this.shuttle,
    required this.court,
    required this.random,
    required this.rally,
    required this.fsm,
    required this.leftInputs,
    required this.rightInputs,
  });

  /// The current simulation frame, starting at 0 and incremented once per tick.
  int frame;

  /// How many consecutive ticks the server has held the toss button, used to
  /// compute the charge fraction for the hold-to-charge serve (M1-034).
  ///
  /// Only meaningful during `MatchPhase.servePending`. Reset to 0 in
  /// `Simulation._placeForServe` so each serve attempt starts uncharged. Must
  /// be included in [copy] and [debugSignature] — omitting either would cause
  /// rollback desyncs if the charge state diverges between peers.
  int serveChargeTicks;

  /// The player on the left half of the court.
  Player leftPlayer;

  /// The player on the right half of the court.
  Player rightPlayer;

  /// The shuttlecock.
  Shuttle shuttle;

  /// The playing field (immutable; shared, never snapshotted).
  final Court court;

  /// The deterministic PRNG — the only source of randomness in the engine.
  GameRandom random;

  /// Per-point rally bookkeeping (last hitter, lockout, active drag).
  RallyState rally;

  /// The serve/rally/scoring finite-state machine.
  MatchFsm fsm;

  /// The left player's per-frame input history.
  InputBuffer leftInputs;

  /// The right player's per-frame input history.
  InputBuffer rightInputs;

  /// The [Player] on [side].
  Player playerOn(CourtSide side) =>
      side == CourtSide.left ? leftPlayer : rightPlayer;

  /// The [InputBuffer] for the player on [side].
  InputBuffer inputsOn(CourtSide side) =>
      side == CourtSide.left ? leftInputs : rightInputs;

  /// A deep, independent copy of the whole simulation — the rollback snapshot.
  ///
  /// Every mutable member is deep-copied; only the const [court] is shared.
  /// Mutating the copy (or the original) after this call never affects the
  /// other.
  GameState copy() => GameState._(
    frame: frame,
    serveChargeTicks: serveChargeTicks,
    leftPlayer: leftPlayer.copy(),
    rightPlayer: rightPlayer.copy(),
    shuttle: shuttle.copy(),
    court: court,
    random: GameRandom.fromState(random.state),
    rally: rally.copy(),
    fsm: fsm.copy(),
    leftInputs: leftInputs.copy(),
    rightInputs: rightInputs.copy(),
  );

  /// A deterministic, human-diffable one-line signature of the entire state.
  ///
  /// Concatenates the frame, both players' kinematic and resource state, the
  /// shuttle's position and velocity, the rally bookkeeping, the FSM's phase,
  /// server and scores, and the PRNG lanes. Two simulations that are truly
  /// identical produce byte-identical signatures *every* frame; the first frame
  /// they differ is the desync frame. This string is also the seed of the M3
  /// desync-detection hash.
  ///
  /// Scalars are rendered via `Fix.toDouble().toString()`. This is a
  /// representation-stable choice *while [Fix] is double-backed*: the same bit
  /// pattern always stringifies identically, so equality of signatures and
  /// equality of state coincide. When [Fix] becomes Q16.16 in Milestone 3 the
  /// rendering swaps to the integer raw value, but the byte-identical guarantee
  /// is unchanged.
  String get debugSignature {
    final l = leftPlayer;
    final r = rightPlayer;
    final s = shuttle;
    return 'f=$frame|'
        'chg=$serveChargeTicks|'
        'L(${_s(l.x)},${_s(l.y)},${l.facing.name},${_s(l.stamina)},'
        '${l.stunTicksRemaining},${l.jumpTick})|'
        'R(${_s(r.x)},${_s(r.y)},${r.facing.name},${_s(r.stamina)},'
        '${r.stunTicksRemaining},${r.jumpTick})|'
        'S(p=${_s(s.position.x)},${_s(s.position.y)};'
        'v=${_s(s.velocity.x)},${_s(s.velocity.y)})|'
        'rally(${rally.lastHitter?.name},${rally.hitLockout?.name},'
        '${rally.lastShotType?.name},${_s(rally.activeDragCoefficient)})|'
        'fsm(${fsm.phase.name},${fsm.server.name},'
        '${fsm.scoreboard.leftScore}-${fsm.scoreboard.rightScore})|'
        'rng=${random.state.join(',')}';
  }

  /// Renders a [Fix] scalar for [debugSignature] (see its docs for stability).
  static String _s(Fix value) => value.toDouble().toString();
}
