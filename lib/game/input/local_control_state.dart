import 'package:smash_bros/engine/input/input_action.dart';

// ---------------------------------------------------------------------------
// LocalControlState — M1-025
//
// Bridge between the input widgets/keyboard and the simulation's InputBuffer.
// Written to by UI components and the keyboard handler; drained once per
// simulation tick by BadmintonGame's onTick callback.
//
// ## Level vs. edge contract
//
// * LEVEL-triggered holds (moveLeft, moveRight): set by button-press/key-down,
//   cleared by button-release/key-up. Each drainTick() call includes the hold
//   bit as long as the button remains down — one drain per tick the key is held.
//
// * EDGE-triggered one-shots (jump, smash, drop, normal, toss): set by a
//   single call to the press* method and consumed (cleared) by the very next
//   drainTick() call. Holding the button does NOT repeat the bit; the player
//   must release and press again to fire the action a second time.
//
// The engine's InputValidator owns all game-rule sanitisation (stun gating,
// shot deduplication, serve isolation). This class only shapes press semantics
// — it does NOT enforce any game rules itself.
// ---------------------------------------------------------------------------

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

  // -- Edge-triggered one-shot flags -----------------------------------------

  bool _pendingJump = false;
  bool _pendingSmash = false;
  bool _pendingDrop = false;
  bool _pendingNormal = false;
  bool _pendingToss = false;

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

  /// Schedules a serve toss for the next [drainTick] call.
  void pressToss() => _pendingToss = true;

  // -- Drain -----------------------------------------------------------------

  /// Builds the [InputAction] bitmask for one simulation tick and clears all
  /// pending one-shot flags.
  ///
  /// * Move bits reflect the *current* hold state (level-triggered) — they are
  ///   NOT cleared; they remain set across multiple ticks until the button is
  ///   released.
  /// * Each pending one-shot bit is included exactly once — the flag is cleared
  ///   immediately, so subsequent ticks see `0` for that action until the
  ///   player presses the button again.
  ///
  /// Call this exactly once per simulation tick in the fixed-timestep driver's
  /// onTick callback, BEFORE calling `simulation.tick()`.
  int drainTick() {
    var bits = InputAction.none;

    // Level-triggered: include hold bits without clearing.
    if (moveLeft) bits |= InputAction.moveLeft;
    if (moveRight) bits |= InputAction.moveRight;

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
    if (_pendingToss) {
      bits |= InputAction.toss;
      _pendingToss = false;
    }

    return bits;
  }
}
