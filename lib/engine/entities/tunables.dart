import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/math/fix.dart';

/// [Fix] mirrors of the gameplay constants the entity layer consumes.
///
/// The raw values in `constants.dart` are plain [double]s (they are also read
/// by the rendering layer and by tools that have no [Fix] dependency). The
/// simulation engine, however, may never mix raw doubles into its math, so we
/// wrap each needed constant exactly once here with [Fix.of] and let entity
/// code reference the wrapped value. This is the single sanctioned
/// double-to-[Fix] boundary for entities — no other engine file should call
/// [Fix.of] on a gameplay constant.
abstract final class Tunables {
  // -- Court ----------------------------------------------------------------

  /// The x coordinate of the net (centre of the court).
  static const Fix netX = Fix.of(kNetX);

  /// The y coordinate of the top of the net. Smaller y is higher on screen,
  /// so this sits *above* the ground.
  static const Fix netTopY = Fix.of(kNetTopY);

  /// The y coordinate of the ground plane (player feet rest here).
  static const Fix groundY = Fix.of(kGroundY);

  /// The leftmost playable x (outer court boundary).
  static const Fix courtLeftBound = Fix.of(kCourtLeftBound);

  /// The rightmost playable x (outer court boundary).
  static const Fix courtRightBound = Fix.of(kCourtRightBound);

  /// The short-service line on the left half of the court.
  static const Fix shortServeLineLeft = Fix.of(kShortServeLineLeft);

  /// The short-service line on the right half of the court.
  static const Fix shortServeLineRight = Fix.of(kShortServeLineRight);

  // -- Player ---------------------------------------------------------------

  /// Player hitbox width in game units.
  static const Fix playerHitboxWidth = Fix.of(kPlayerHitboxWidth);

  /// Player hitbox height in game units.
  static const Fix playerHitboxHeight = Fix.of(kPlayerHitboxHeight);

  /// Half the player hitbox width — the clamp inset from a boundary.
  static const Fix playerHalfWidth = Fix.of(kPlayerHitboxWidth / 2);

  /// Peak height of a jump above the ground, in game units.
  static const Fix playerJumpHeight = Fix.of(kPlayerJumpHeight);

  /// Maximum starting stamina.
  static const Fix staminaMax = Fix.of(kStaminaMax);

  // -- Shuttle --------------------------------------------------------------

  /// Per-tick downward gravity applied to the shuttle's velocity (+y).
  static const Fix shuttleGravity = Fix.of(kShuttleGravity);

  /// Maximum shuttle speed in game units per tick (stability safeguard).
  static const Fix shuttleMaxVelocity = Fix.of(kShuttleMaxVelocity);
}
