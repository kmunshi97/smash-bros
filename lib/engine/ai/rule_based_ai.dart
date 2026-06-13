import 'package:meta/meta.dart';
import 'package:smash_bros/engine/ai/ai_controller.dart';
import 'package:smash_bros/engine/ai/ai_difficulty.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/input/input_action.dart';
import 'package:smash_bros/engine/random/game_random.dart';
import 'package:smash_bros/engine/rules/match_phase.dart';
import 'package:smash_bros/engine/sim/game_state.dart';
import 'package:smash_bros/engine/systems/shot_system.dart';

/// After a toss whiff, retry every this many ticks (shared by all tiers).
const int _kServeTossRetryInterval = 30;

/// The shared skeleton of every rule-based AI tier (M2-022/M2-023 pulled
/// forward into M1 as the difficulty-tier foundation).
///
/// ## Behaviour skeleton
///
/// All tiers share the same three-phase structure; subclasses tune it through
/// the protected knobs instead of reimplementing it:
///
/// ### Serving ([MatchPhase.servePending], AI is server)
///
/// Waits [serveTossDelayTicks] ticks after entering the serve phase, then
/// draws a target charge duration from the private PRNG (a random number of
/// ticks in `[10, kServeChargeMaxTicks]`), HOLDS [InputAction.toss] for that
/// many ticks, then drops the bit to release the serve. If the phase somehow
/// remains `servePending` after the release (the toss whiffed), retries on
/// the next [_kServeTossRetryInterval] boundary.
///
/// ### Rally ([MatchPhase.inPlay])
///
/// 1. **Reaction delay**: when the shuttle first crosses onto the AI's side,
///    the AI does nothing for [reactionDelayTicks] ticks, then starts acting.
/// 2. **Movement**: walks toward [targetX] with a [movementDeadZone] dead
///    zone. Where the AI walks is the main thing that separates the tiers:
///    the easy tier chases the shuttle's *current* x, harder tiers predict
///    where it will come down.
/// 3. **Swing**: when `ShotSystem.isWithinReach` is true for this AI's player
///    and the rally's hit-lockout is NOT this side, emits the bitmask chosen
///    by [chooseShotBit]. After emitting a swing, holds off for
///    [swingCooldownTicks] ticks.
///
/// ### All other phases
///
/// Returns `InputAction.none`.
///
/// ## Private mutable state
///
/// Per the architecture note in `AIController`, private fields are allowed
/// here because rollback/replay records buffered inputs and never re-runs the
/// AI. The skeleton maintains phase-transition trackers, the serve-charge
/// countdown, the reaction-delay countdown, and the swing cooldown across
/// calls; subclasses should stay stateless beyond their PRNG draws.
abstract base class RuleBasedAi implements AIController {
  /// Creates a tier for [side] using [seed] to seed its private PRNG.
  ///
  /// The seed must differ from the match seed so the AI PRNG stream is
  /// independent of the simulation's (see `BadmintonGame`).
  RuleBasedAi({required this.side, required int seed})
    : random = GameRandom(seed);

  @override
  final CourtSide side;

  /// The difficulty tier this controller implements.
  AiDifficulty get difficulty;

  /// Private deterministic PRNG — never draws from `GameState.random`.
  @protected
  final GameRandom random;

  // -- Tier knobs (overridden per difficulty) ---------------------------------

  /// Ticks to wait after entering [MatchPhase.servePending] before tossing.
  ///
  /// Gives a visual pause before the AI serves — feels more natural and
  /// prevents instant-serves that look like a bug.
  @protected
  int get serveTossDelayTicks;

  /// Ticks of inaction after the shuttle crosses onto this AI's side.
  ///
  /// Models the human perception-to-action delay; the dominant skill knob.
  @protected
  int get reactionDelayTicks;

  /// Dead zone (in game units) around [targetX] within which no movement
  /// input is emitted. Prevents oscillation/jitter around the target.
  @protected
  double get movementDeadZone;

  /// After emitting a shot bit, hold off this many ticks before another
  /// swing attempt. The swing animation occupies `kSwingAnimationFrames`
  /// ticks, so retrying sooner would be wasted inputs.
  @protected
  int get swingCooldownTicks;

  /// The x coordinate the AI walks toward this tick during a rally.
  ///
  /// [shuttleSide] is the side of the net the shuttle currently occupies.
  @protected
  double targetX(GameState state, CourtSide shuttleSide);

  /// The shot bitmask to emit when the shuttle is within reach.
  ///
  /// Implementations must pair [InputAction.jump] with [InputAction.smash]
  /// (jump-smash is one action game-wide, M1-036) and may draw from [random].
  @protected
  int chooseShotBit(GameState state);

  // -- Private mutable state (allowed per AIController architecture note) -----

  MatchPhase? _lastSeenPhase;
  int _servePhaseTicksSeen = 0;

  /// Target number of ticks to hold the toss bit this serve, drawn once per
  /// serve attempt from [random]. `null` means the target has not been drawn
  /// yet for the current serve phase entry.
  int? _serveChargeTarget;

  /// How many ticks the toss bit has been held in the current charge window.
  int _serveHeldTicks = 0;

  CourtSide? _lastSeenShuttleSide;
  int _reactionTicksRemaining = 0;
  int _swingCooldownRemaining = 0;

  // -- AIController -----------------------------------------------------------

  @override
  int decide(GameState state) {
    final phase = state.fsm.phase;

    switch (phase) {
      case MatchPhase.servePending:
        return _decideServe(state);
      case MatchPhase.inPlay:
        return _decideRally(state);
      case MatchPhase.preMatch:
      case MatchPhase.pointScored:
      case MatchPhase.matchOver:
        // Reset per-phase tracking on phase changes so state is clean next
        // time we enter serve or rally.
        _resetOnPhaseChange(phase);
        return InputAction.none;
    }
  }

  // -- Serve logic ------------------------------------------------------------

  int _decideServe(GameState state) {
    // Only act when this AI is the server.
    if (state.fsm.server != side) {
      _resetOnPhaseChange(MatchPhase.servePending);
      return InputAction.none;
    }

    // Detect phase entry to reset the tick counter and charge state.
    if (_lastSeenPhase != MatchPhase.servePending) {
      _servePhaseTicksSeen = 0;
      _serveChargeTarget = null;
      _serveHeldTicks = 0;
      _lastSeenPhase = MatchPhase.servePending;
    }

    _servePhaseTicksSeen++;

    // -- Initial delay --------------------------------------------------------
    final ticksInWindow = _servePhaseTicksSeen - serveTossDelayTicks;
    if (ticksInWindow < 0) {
      // Still waiting out the initial pause — emit nothing.
      return InputAction.none;
    }

    // -- Charge window --------------------------------------------------------
    // Draw the target charge on the very first tick past the delay (or on a
    // retry boundary). The target is in [10, kServeChargeMaxTicks].
    if (_serveChargeTarget == null ||
        (ticksInWindow > 0 &&
            ticksInWindow % _kServeTossRetryInterval == 0 &&
            _serveHeldTicks == 0)) {
      // New charge draw: hold for 10..kServeChargeMaxTicks ticks.
      _serveChargeTarget = random.nextInt(kServeChargeMaxTicks - 10) + 10;
      _serveHeldTicks = 0;
    }

    final target = _serveChargeTarget!;
    if (_serveHeldTicks < target) {
      // Still within the charge window — keep the toss bit HIGH.
      _serveHeldTicks++;
      return InputAction.toss;
    }

    // Target reached — drop the bit (release = launch).
    // Reset so a retry starts a fresh charge on the next window boundary.
    _serveChargeTarget = null;
    _serveHeldTicks = 0;
    return InputAction.none;
  }

  // -- Rally logic ------------------------------------------------------------

  int _decideRally(GameState state) {
    // Track phase so we reset cleanly when we next re-enter serve.
    if (_lastSeenPhase != MatchPhase.inPlay) {
      _lastSeenPhase = MatchPhase.inPlay;
      // Do NOT reset _reactionTicksRemaining here — the delay started before
      // this call if the shuttle crossed during the previous tick. We also
      // don't reset _lastSeenShuttleSide so we don't double-trigger the delay.
    }

    final shuttle = state.shuttle;
    final court = state.court;
    final shuttleSide = court.sideOfX(shuttle.position.x);

    // Detect shuttle crossing onto our side → arm reaction delay.
    if (_lastSeenShuttleSide != shuttleSide) {
      _lastSeenShuttleSide = shuttleSide;
      if (shuttleSide == side) {
        _reactionTicksRemaining = reactionDelayTicks;
      }
    }

    // Tick down the reaction delay.
    if (_reactionTicksRemaining > 0) {
      _reactionTicksRemaining--;
      return InputAction.none;
    }

    // Decrement swing cooldown unconditionally each rally tick.
    if (_swingCooldownRemaining > 0) {
      _swingCooldownRemaining--;
    }

    // Build the output bitmask.
    var output = InputAction.none;

    // -- Movement -------------------------------------------------------------
    final player = state.playerOn(side);
    final deltaX = targetX(state, shuttleSide) - player.x.toDouble();
    if (deltaX > movementDeadZone) {
      output |= InputAction.moveRight;
    } else if (deltaX < -movementDeadZone) {
      output |= InputAction.moveLeft;
    }

    // -- Swing ----------------------------------------------------------------
    if (_swingCooldownRemaining == 0) {
      final canHit = ShotSystem.isWithinReach(player, shuttle.position);
      final lockedOut = state.rally.hitLockout == side;

      if (canHit && !lockedOut) {
        output |= chooseShotBit(state);
        _swingCooldownRemaining = swingCooldownTicks;
      }
    }

    return output;
  }

  // -- Helpers ----------------------------------------------------------------

  /// This side's start-of-rally x — where the AI returns between shots.
  @protected
  double get homeX => side == CourtSide.left ? kPlayer1StartX : kPlayer2StartX;

  /// Resets phase-tracking state on a phase change.
  void _resetOnPhaseChange(MatchPhase current) {
    if (_lastSeenPhase != current) {
      _lastSeenPhase = current;
      _servePhaseTicksSeen = 0;
      _serveChargeTarget = null;
      _serveHeldTicks = 0;
      _lastSeenShuttleSide = null;
      _reactionTicksRemaining = 0;
      _swingCooldownRemaining = 0;
    }
  }
}
