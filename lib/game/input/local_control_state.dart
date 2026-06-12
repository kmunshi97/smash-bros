import 'package:smash_bros/engine/input/input_action.dart';

// ---------------------------------------------------------------------------
// LocalControlState — M1-025 (updated M1-034, M1-036 jump-smash)
//
// Bridge between the input widgets/keyboard and the simulation's InputBuffer.
// Written to by UI components and the keyboard handler; drained once per
// simulation tick by BadmintonGame's onTick callback.
//
// ## Level vs. edge contract
//
// * LEVEL-triggered holds (moveLeft, moveRight, tossHeld): set by
//   button-press/key-down, cleared by button-release/key-up. Each drainTick()
//   call includes the hold bit as long as the button remains down — one drain
//   per tick the key is held.
//
//   NOTE (M1-034): toss was promoted from edge-triggered to LEVEL-triggered to
//   support the hold-to-charge serve mechanic. The simulation's serve logic
//   accumulates charge while the toss bit is HIGH and launches on the 1→0
//   transition. The old `pressToss()` one-shot method has been removed.
//
// * EDGE-triggered one-shots (jump, smash, drop, normal): set by a
//   single call to the press* method and consumed (cleared) by the very next
//   drainTick() call. Holding the button does NOT repeat the bit; the player
//   must release and press again to fire the action a second time.
//
// * DELAYED one-shots (pressJumpSmash grounded path): a single button press
//   issues an immediate jump bit AND schedules a smash bit to fire exactly
//   [kJumpSmashApexDelayTicks] drains later (the jump apex). drainTick()
//   decrements the countdown each call and ORs in the smash bit when it
//   reaches zero. A re-press while the countdown is active is silently ignored
//   (the pending delayed smash is already on its way). If the player is
//   already airborne when pressJumpSmash is called, the smash fires on the
//   very next drain and no jump bit is set (same as pressSmash).
//
// The engine's InputValidator owns all game-rule sanitisation (stun gating,
// shot deduplication, serve isolation). This class only shapes press semantics
// — it does NOT enforce any game rules itself.
// ---------------------------------------------------------------------------

/// Ticks between a jump launch and the smash bit in a jump-smash combo.
///
/// Value 20 = the jump apex (half of `kPlayerJumpDuration` = 40 ticks).
/// This is a feel-tuning constant; it will be promoted to BalanceConfig in
/// M1-032b.
const int kJumpSmashApexDelayTicks = 20;

/// Mutable per-frame input accumulator for the local (human) player.
///
/// UI components and the keyboard handler write into this object; the
/// `BadmintonGame` tick callback drains it once per simulation tick via
/// [drainTick].
///
/// See the file-level comment for the level-vs-edge contract.
class LocalControlState {
  // -- Level-triggered holds --------------------------------------------------

  /// Whether the move-left button is currently held.
  bool moveLeft = false;

  /// Whether the move-right button is currently held.
  bool moveRight = false;

  /// Whether the toss button is currently held (M1-034 hold-to-charge serve).
  ///
  /// Set true on button-press/key-down; cleared on button-release/key-up or
  /// when the slot flips away from TOSS (e.g. serve launches and the primary
  /// button becomes SMASH). Each [drainTick] call includes the toss bit while
  /// this is `true`, producing the level-held semantics the charge-serve needs.
  bool tossHeld = false;

  // -- Edge-triggered one-shot flags -----------------------------------------

  bool _pendingJump = false;
  bool _pendingSmash = false;
  bool _pendingDrop = false;
  bool _pendingNormal = false;

  // -- Delayed one-shot countdown (jump-smash) --------------------------------

  /// Remaining drains before the delayed smash bit fires.
  ///
  /// -1 means no countdown is active. When [pressJumpSmash] is called with
  /// `airborne: false`, this is set to [kJumpSmashApexDelayTicks]. Each
  /// [drainTick] decrements it; when it reaches 0 the smash bit is included
  /// and the countdown resets to -1.
  int _jumpSmashCountdown = -1;

  // -- One-shot setters -------------------------------------------------------

  /// Schedules a jump for the next [drainTick] call.
  ///
  /// Pressing again before the tick fires has no additional effect (the flag is
  /// already set). Release and re-press after [drainTick] to issue a second
  /// jump.
  void pressJump() => _pendingJump = true;

  /// Schedules a smash for the next [drainTick] call.
  void pressSmash() => _pendingSmash = true;

  /// Schedules a drop shot for the next [drainTick] call.
  void pressDrop() => _pendingDrop = true;

  /// Schedules a normal (clear/drive) shot for the next [drainTick] call.
  void pressNormal() => _pendingNormal = true;

  // -- Combined jump-smash setter --------------------------------------------

  /// Issues a jump-smash combo action.
  ///
  /// * [airborne] = `true` (player is mid-air): behaves identically to
  ///   [pressSmash] — the smash bit fires on the very next [drainTick]. No
  ///   jump bit is set because the player is already in the air.
  ///
  /// * [airborne] = `false` (player is grounded): sets the jump bit for the
  ///   next [drainTick] AND starts a countdown of [kJumpSmashApexDelayTicks]
  ///   drains. When the countdown expires the smash bit fires automatically,
  ///   delivering the smash at the jump apex without any second button press.
  ///
  /// If called while a grounded countdown is already active, the new press is
  /// silently ignored — the in-flight combo is preserved and does not stack or
  /// reset.
  void pressJumpSmash({required bool airborne}) {
    if (airborne) {
      // Player is already in the air: fire smash immediately.
      _pendingSmash = true;
    } else {
      // Player is grounded: ignore if a countdown is already ticking.
      if (_jumpSmashCountdown >= 0) return;
      _pendingJump = true;
      _jumpSmashCountdown = kJumpSmashApexDelayTicks;
    }
  }

  // -- Drain -----------------------------------------------------------------

  /// Builds the [InputAction] bitmask for one simulation tick and clears all
  /// pending one-shot flags.
  ///
  /// * Move bits and [tossHeld] reflect the *current* hold state
  ///   (level-triggered) — they are NOT cleared; they remain set across
  ///   multiple ticks until the button is released.
  /// * Each pending one-shot bit is included exactly once — the flag is cleared
  ///   immediately, so subsequent ticks see `0` for that action until the
  ///   player presses the button again.
  /// * The delayed jump-smash countdown is decremented each drain; the smash
  ///   bit is ORed in on the tick the countdown reaches zero.
  ///
  /// Call this exactly once per simulation tick in the fixed-timestep driver's
  /// onTick callback, BEFORE calling `simulation.tick()`.
  int drainTick() {
    var bits = InputAction.none;

    // Level-triggered: include hold bits without clearing.
    if (moveLeft) bits |= InputAction.moveLeft;
    if (moveRight) bits |= InputAction.moveRight;
    if (tossHeld) bits |= InputAction.toss;

    // Edge-triggered: include then immediately clear each pending flag.
    if (_pendingJump) {
      bits |= InputAction.jump;
      _pendingJump = false;
    }
    if (_pendingSmash) {
      bits |= InputAction.smash;
      _pendingSmash = false;
    }
    if (_pendingDrop) {
      bits |= InputAction.dropShot;
      _pendingDrop = false;
    }
    if (_pendingNormal) {
      bits |= InputAction.normalShot;
      _pendingNormal = false;
    }

    // Delayed jump-smash: decrement countdown; fire smash when it hits zero.
    if (_jumpSmashCountdown > 0) {
      _jumpSmashCountdown--;
    } else if (_jumpSmashCountdown == 0) {
      bits |= InputAction.smash;
      _jumpSmashCountdown = -1;
    }

    return bits;
  }
}
