import 'package:smash_bros/engine/input/input_action.dart';

/// The kind of shot a player attempts on a swing.
///
/// Lives in its own file (rather than alongside `ShotSystem` in
/// `shot_system.dart`) so it can be referenced by both `shot_system.dart` and
/// `rally_state.dart` without an import cycle: `shot_system.dart` imports
/// `rally_state.dart`, and `rally_state.dart` records the last [ShotType] for
/// the defence logic, so the type itself must sit below both.
enum ShotType {
  /// A normal clear/drive shot — a moderate upward arc.
  normal,

  /// An overhead smash — a fast downward shot, stronger when airborne.
  smash,

  /// A drop shot — a soft shot that bleeds speed near the net (higher drag).
  drop,

  /// A serve toss — a high, soft lob to start a point.
  toss;

  /// Maps an (already-sanitized) input [bitmask] to its [ShotType], or `null`
  /// when no shot bit is set.
  ///
  /// The [bitmask] is assumed to have passed `InputValidator.sanitize`, so at
  /// most one shot bit is present; the first match wins regardless.
  static ShotType? fromBitmask(int bitmask) {
    if (InputAction.has(bitmask, InputAction.normalShot)) {
      return ShotType.normal;
    }
    if (InputAction.has(bitmask, InputAction.smash)) {
      return ShotType.smash;
    }
    if (InputAction.has(bitmask, InputAction.dropShot)) {
      return ShotType.drop;
    }
    if (InputAction.has(bitmask, InputAction.toss)) {
      return ShotType.toss;
    }
    return null;
  }
}
