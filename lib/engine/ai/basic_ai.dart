import 'package:smash_bros/engine/ai/ai_controller.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/input/input_action.dart';
import 'package:smash_bros/engine/random/game_random.dart';
import 'package:smash_bros/engine/rules/match_phase.dart';
import 'package:smash_bros/engine/sim/game_state.dart';
import 'package:smash_bros/engine/systems/shot_system.dart';

// ---------------------------------------------------------------------------
// Tunable private constants (migrate to BalanceConfig in M1-032b)
// ---------------------------------------------------------------------------

/// Ticks to wait after entering [MatchPhase.servePending] before tossing.
///
/// Gives a brief visual pause before the AI serves — feels more natural and
/// prevents instant-serves that look like a bug. ~45 ticks ≈ 0.75 s.
const int _kServeTossDelay = 45;

/// After a toss whiff, retry every this many ticks.
const int _kServeTossRetryInterval = 30;

/// After the shuttle crosses onto the AI's side, do nothing for this many
/// ticks before reacting. Models the human perception-to-action delay.
///
/// 15 ticks = 0.25 s — short enough to feel responsive, long enough that
/// the AI doesn't look inhuman.
const int _kReactionDelayTicks = 15;

/// Dead zone (in game units) around the shuttle's x when following it.
///
/// If the AI is within this distance of the target x, no movement input is
/// emitted. Prevents oscillation/jitter around the target.
const double _kMovementDeadZone = 12;

/// After emitting a shot bit, hold off for this many ticks before attempting
/// another swing. The swing animation occupies [kSwingAnimationFrames] ticks
/// so retrying sooner than this would be wasted inputs.
const int _kSwingCooldownTicks = 12;

/// Shot-mix thresholds for [GameRandom.nextInt] draws in [0, 100):
///   0..69  → normal shot (70 %)
///   70..89 → smash      (20 %)
///   90..99 → drop shot  (10 %)
const int _kShotMixNormalMax = 70; // [0, 70)  → normal
const int _kShotMixSmashMax = 90; // [70, 90) → smash

// ---------------------------------------------------------------------------
// BasicAI
// ---------------------------------------------------------------------------

/// A simple rule-based AI opponent (M1-028).
///
/// ## Behaviour summary
///
/// ### Serving ([MatchPhase.servePending], AI is server)
///
/// Waits [_kServeTossDelay] ticks after entering the serve phase, then draws a
/// target charge duration from its private PRNG: a random number of ticks in
/// `[10, kServeChargeMaxTicks]`. It then HOLDS [InputAction.toss] for that many
/// ticks (emitting the bit every tick while charging), then drops the bit to
/// release the serve. If the phase somehow remains `servePending` after the
/// release (very unlikely — the toss whiffed), retries on the next
/// [_kServeTossRetryInterval] boundary.
///
/// ### Rally ([MatchPhase.inPlay])
///
/// 1. **Reaction delay**: when the shuttle first crosses onto the AI's side,
///    the AI does nothing for [_kReactionDelayTicks] ticks, then starts acting.
/// 2. **Movement**: walks toward the shuttle's current x (clamped to own half)
///    with a [_kMovementDeadZone] dead zone. While the shuttle is on the
///    opponent's side (and not within the reaction window) the AI walks home
///    (its start x).
/// 3. **Swing**: when `ShotSystem.isWithinReach` is true for this AI's player
///    and the rally's hit-lockout is NOT this side, emits a shot drawn via the
///    private PRNG: 70 % normal, 20 % smash, 10 % drop. After emitting a swing,
///    holds off for `_kSwingCooldownTicks` ticks.
///    BasicAI never emits `InputAction.jump` — jump smashes are IntermediateAI's
///    domain (M2).
///
/// ### All other phases
///
/// Returns `InputAction.none`.
///
/// ## Private mutable state
///
/// Per the architecture note in `AIController`, private fields are allowed
/// here because rollback/replay records buffered inputs and never re-runs the
/// AI. The following fields are maintained across calls:
///
/// * `_lastSeenPhase` — detects phase transitions for the serve-delay timer.
/// * `_servePhaseTicksSeen` — ticks since entering the current serve phase.
/// * `_serveChargeTarget` — target hold duration (ticks) drawn once per serve.
/// * `_serveHeldTicks` — how many ticks the toss bit has been held this serve.
/// * `_lastSeenShuttleSide` — detects when the shuttle crosses to this side.
/// * `_reactionTicksRemaining` — countdown for the reaction delay.
/// * `_swingCooldownRemaining` — ticks to hold off before attempting a swing.
final class BasicAI implements AIController {
  /// Creates a [BasicAI] for [side] using [seed] to seed its private PRNG.
  ///
  /// The seed must differ from the match seed so the AI PRNG stream is
  /// independent of the simulation's (see `BadmintonGame`).
  BasicAI({required this.side, required int seed}) : _random = GameRandom(seed);

  @override
  final CourtSide side;

  /// Private deterministic PRNG — never draws from `GameState.random`.
  final GameRandom _random;

  // -- Private mutable state (allowed per AIController architecture note) -----

  MatchPhase? _lastSeenPhase;
  int _servePhaseTicksSeen = 0;

  /// Target number of ticks to hold the toss bit this serve, drawn once per
  /// serve attempt from [_random]. `null` means the target has not been drawn
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
    final ticksInWindow = _servePhaseTicksSeen - _kServeTossDelay;
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
      _serveChargeTarget = _random.nextInt(kServeChargeMaxTicks - 10) + 10;
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
        _reactionTicksRemaining = _kReactionDelayTicks;
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
    final targetX = _targetX(state, shuttleSide);
    final deltaX = targetX - player.x.toDouble();
    if (deltaX > _kMovementDeadZone) {
      output |= InputAction.moveRight;
    } else if (deltaX < -_kMovementDeadZone) {
      output |= InputAction.moveLeft;
    }

    // -- Swing ----------------------------------------------------------------
    if (_swingCooldownRemaining == 0) {
      final enginePlayer = state.playerOn(side);
      final canHit = ShotSystem.isWithinReach(enginePlayer, shuttle.position);
      final lockedOut = state.rally.hitLockout == side;

      if (canHit && !lockedOut) {
        output |= _chooseShotBit();
        _swingCooldownRemaining = _kSwingCooldownTicks;
      }
    }

    return output;
  }

  // -- Helpers ----------------------------------------------------------------

  /// The x coordinate the AI should walk toward this tick.
  ///
  /// While the shuttle is on our side (or in the reaction window that just
  /// expired), track the shuttle's x clamped to our half. While the shuttle
  /// is on the opponent's side and we are not reacting, return home.
  double _targetX(GameState state, CourtSide shuttleSide) {
    if (shuttleSide == side) {
      // Chase the shuttle, but stay on our own half — clampToSide handles that
      // as part of movement; here we just return the raw shuttle x.
      return state.shuttle.position.x.toDouble();
    }
    // Shuttle is on the other side → walk home.
    return side == CourtSide.left ? kPlayer1StartX : kPlayer2StartX;
  }

  /// Chooses a shot InputAction bit from the 70/20/10 distribution.
  int _chooseShotBit() {
    final roll = _random.nextInt(100);
    if (roll < _kShotMixNormalMax) return InputAction.normalShot;
    if (roll < _kShotMixSmashMax) return InputAction.smash;
    return InputAction.dropShot;
  }

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
