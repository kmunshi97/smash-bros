import 'package:meta/meta.dart';
import 'package:smash_bros/engine/entities/tunables.dart';
import 'package:smash_bros/engine/math/fix.dart';

/// Which half of the court an entity belongs to.
///
/// The net divides the court at [Court.netX]: [left] is everything with
/// `x < netX`, [right] is everything with `x > netX`.
enum CourtSide {
  /// The left half of the court (smaller x).
  left,

  /// The right half of the court (larger x).
  right,
}

/// Immutable description of the playing field.
///
/// ## Coordinate convention
///
/// All coordinates are in game units (the court is 1280x720). The x axis
/// grows rightward; the **y axis grows downward**, matching `FixVec2` and the
/// rendering layer. Consequently:
///
/// * the ground plane is at the *largest* relevant y ([groundY] = 600);
/// * the top of the net ([netTopY] = 350) is *above* the ground even though
///   it is a *smaller* y value — smaller y means higher on screen.
///
/// [Court] holds no mutable state; it is a value object the collision, shot
/// and movement systems read from. A single shared instance per match is the
/// expected usage, so it is not snapshotted.
@immutable
final class Court {
  /// Creates a court with the standard tuned dimensions.
  const Court();

  /// The x coordinate of the net (court centre line).
  Fix get netX => Tunables.netX;

  /// The y coordinate of the top of the net (above the ground; see class
  /// docs for why this is a smaller y than [groundY]).
  Fix get netTopY => Tunables.netTopY;

  /// The y coordinate of the ground plane.
  Fix get groundY => Tunables.groundY;

  /// The leftmost playable x (outer boundary).
  Fix get leftBound => Tunables.courtLeftBound;

  /// The rightmost playable x (outer boundary).
  Fix get rightBound => Tunables.courtRightBound;

  /// The short-service line on the left half.
  Fix get shortServeLineLeft => Tunables.shortServeLineLeft;

  /// The short-service line on the right half.
  Fix get shortServeLineRight => Tunables.shortServeLineRight;

  /// The short-service line for [side].
  Fix shortServeLineFor(CourtSide side) =>
      side == CourtSide.left ? shortServeLineLeft : shortServeLineRight;

  /// The side of the net the point [x] lies on.
  ///
  /// Exactly on the net (`x == netX`) is treated as [CourtSide.left] by
  /// convention: the boundary is assigned to the lower-x half so the mapping
  /// is total and deterministic. Callers that care about the net line itself
  /// should compare against [netX] directly.
  CourtSide sideOfX(Fix x) => x <= netX ? CourtSide.left : CourtSide.right;

  /// Clamps a player's centre [x] so a hitbox of half-width [halfWidth] stays
  /// inside both the outer court boundary and its own half of the net.
  ///
  /// Players may not cross the net (M1-004): on [CourtSide.left] the right
  /// edge of the hitbox is kept at or left of [netX]; on [CourtSide.right] the
  /// left edge is kept at or right of [netX]. The outer boundary is honoured
  /// simultaneously, so the returned x always satisfies both limits.
  Fix clampToSide(Fix x, CourtSide side, Fix halfWidth) {
    final Fix lower;
    final Fix upper;
    switch (side) {
      case CourtSide.left:
        lower = leftBound + halfWidth;
        upper = netX - halfWidth;
      case CourtSide.right:
        lower = netX + halfWidth;
        upper = rightBound - halfWidth;
    }
    return x.clamp(lower, upper);
  }
}
