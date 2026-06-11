import 'package:meta/meta.dart';

/// Bitmask constants for every action a player can input in a single frame.
///
/// ## Wire-protocol stability guarantee
///
/// These values are **the exact bits that travel inside netcode packets** (M3).
/// Two bytes are reserved in the wire format for this mask.  Values must
/// **never be renumbered or reordered once shipped**: doing so would corrupt
/// replays and break clients on mixed-version servers.  New actions must be
/// assigned the next free bit beyond [toss] (bit 7 onward).
///
/// ## Usage
///
/// Combine actions with `|` and test membership with [has]:
///
/// ```dart
/// final input = InputAction.jump | InputAction.normalShot;
/// assert(InputAction.has(input, InputAction.jump));
/// ```
@immutable
abstract final class InputAction {
  // ---------------------------------------------------------------------------
  // Individual action bits (powers of two — do not renumber)
  // ---------------------------------------------------------------------------

  /// No action pressed.
  static const int none = 0;

  /// Move toward the left of the court (bit 0).
  static const int moveLeft = 1 << 0;

  /// Move toward the right of the court (bit 1).
  static const int moveRight = 1 << 1;

  /// Jump (bit 2).
  static const int jump = 1 << 2;

  /// Normal clear / drive shot (bit 3).
  static const int normalShot = 1 << 3;

  /// Overhead smash (bit 4).
  static const int smash = 1 << 4;

  /// Drop shot (bit 5).
  static const int dropShot = 1 << 5;

  /// Serve toss (bit 6).  Only legal when the player is the server and the
  /// match context is the serving phase — see `InputValidator.sanitize`.
  static const int toss = 1 << 6;

  // ---------------------------------------------------------------------------
  // Composite masks
  // ---------------------------------------------------------------------------

  /// All shot bits except the serve toss.
  static const int allShots = normalShot | smash | dropShot | toss;

  /// Both horizontal movement bits.
  static const int allMovement = moveLeft | moveRight;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Returns `true` when [bitmask] has [action] set.
  ///
  /// ```dart
  /// InputAction.has(InputAction.jump | InputAction.smash, InputAction.jump); // true
  /// InputAction.has(InputAction.jump | InputAction.smash, InputAction.moveLeft); // false
  /// ```
  static bool has(int bitmask, int action) => (bitmask & action) != 0;

  /// Returns the number of distinct shot bits set in [bitmask].
  ///
  /// Only bits within [allShots] are counted
  /// ([normalShot], [smash], [dropShot], [toss]).  Movement or jump bits are
  /// ignored.
  static int countShotBits(int bitmask) {
    var count = 0;
    if (has(bitmask, normalShot)) count++;
    if (has(bitmask, smash)) count++;
    if (has(bitmask, dropShot)) count++;
    if (has(bitmask, toss)) count++;
    return count;
  }
}
