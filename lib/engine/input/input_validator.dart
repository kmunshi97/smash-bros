import 'package:meta/meta.dart';
import 'package:smash_bros/engine/input/input_action.dart';

/// The match phase that determines which actions are currently legal.
///
/// The FSM (a later PR) maps concrete match states onto this two-value context
/// so the validator stays decoupled from the full state machine.
enum InputContext {
  /// The serving player is about to toss; the rally has not begun.
  serving,

  /// The shuttle is in play; normal rally inputs are legal.
  rally,
}

/// Pure, stateless sanitisation of a raw input bitmask.
///
/// ## Contract
///
/// [sanitize] accepts whatever the input layer produced this frame and returns
/// a semantically valid bitmask according to the current game context.  It is
/// **pure and deterministic**: same arguments always produce the same output
/// with no observable side-effects.  The engine calls it once per tick per
/// player immediately before passing the bitmask to the action-processing
/// systems.
///
/// ## Tick order
///
/// Runs at the very start of the input-processing phase, before any system
/// reads the frame's bitmask.
@immutable
abstract final class InputValidator {
  /// Returns a sanitised copy of [bitmask] according to the rules below.
  ///
  /// Rules are applied in strict priority order; each operates on the result
  /// of the rule before it:
  ///
  /// 1. **Stun**: if [isStunned] is `true`, return [InputAction.none]
  ///    immediately.  A stunned player has zero agency — no partial inputs are
  ///    forwarded.
  ///
  /// 2. **Contradictory movement**: if both [InputAction.moveLeft] and
  ///    [InputAction.moveRight] are set, both are cleared.  Simultaneous
  ///    left+right is physically impossible on a d-pad and ambiguous on a
  ///    keyboard; cancelling both is the least-surprising resolution.
  ///
  /// 3. **Toss legality**: [InputAction.toss] is only legal when
  ///    `context == InputContext.serving` AND [isServer] is `true`.  Any other
  ///    combination clears the toss bit.
  ///
  /// 4. **Serving isolation**: during [InputContext.serving] all rally-shot
  ///    bits ([InputAction.normalShot], [InputAction.smash],
  ///    [InputAction.dropShot]) are cleared.  You cannot rally before the serve;
  ///    the only legal shot action during a serve is the toss (rule 3).
  ///
  /// 5. **Shot-priority de-duplication**: if more than one rally-shot bit is
  ///    set simultaneously, exactly one is kept by priority
  ///    **smash > dropShot > normalShot**.  The higher-priority shot wins
  ///    because mashing multiple buttons at once more likely signals intent for
  ///    the deliberate special move than for the default clear.  [InputAction.toss]
  ///    is excluded from this contest — rules 3/4 already isolated it.
  static int sanitize({
    required int bitmask,
    required bool isStunned,
    required InputContext context,
    required bool isServer,
  }) {
    // Rule 1 — stun overrides everything.
    if (isStunned) {
      return InputAction.none;
    }

    // Work on a local copy so we never assign back to the parameter.
    var bits = bitmask;

    // Rule 2 — contradictory movement cancels out.
    if (InputAction.has(bits, InputAction.moveLeft) &&
        InputAction.has(bits, InputAction.moveRight)) {
      bits &= ~InputAction.allMovement;
    }

    // Rule 3 — toss only legal for the server during a serve.
    if (InputAction.has(bits, InputAction.toss)) {
      if (context != InputContext.serving || !isServer) {
        bits &= ~InputAction.toss;
      }
    }

    // Rule 4 — during a serve, rally shots are illegal.
    if (context == InputContext.serving) {
      bits &=
          ~(InputAction.normalShot | InputAction.smash | InputAction.dropShot);
    }

    // Rule 5 — shot de-duplication by priority: smash > dropShot > normalShot.
    // Toss is excluded (already handled above).
    const rallyShots =
        InputAction.normalShot | InputAction.smash | InputAction.dropShot;
    final activeShotBits = bits & rallyShots;
    if (InputAction.countShotBits(activeShotBits) > 1) {
      // Clear all rally-shot bits, then restore exactly the highest-priority one.
      bits &= ~rallyShots;
      if (InputAction.has(activeShotBits, InputAction.smash)) {
        bits |= InputAction.smash;
      } else if (InputAction.has(activeShotBits, InputAction.dropShot)) {
        bits |= InputAction.dropShot;
      } else {
        bits |= InputAction.normalShot;
      }
    }

    return bits;
  }
}
