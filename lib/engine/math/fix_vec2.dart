import 'package:meta/meta.dart';
import 'package:smash_bros/engine/math/fix.dart';

/// An immutable 2D vector over the engine scalar type [Fix].
///
/// Coordinate convention (matches the court constants): x grows rightward,
/// y grows downward, units are game units (court is 1280x720).
///
/// This is the only vector type simulation code may use — `vector_math` and
/// Flame's `Vector2` are rendering-layer types and never enter the engine.
@immutable
final class FixVec2 {
  /// Creates a vector with the given components.
  const FixVec2(this.x, this.y);

  /// Creates a unit-ish direction vector from an angle in radians.
  ///
  /// Angle 0 points along +x; positive angles rotate toward +y (downward,
  /// per the coordinate convention).
  FixVec2.fromAngle(Fix radians)
    : x = FixMath.cos(radians),
      y = FixMath.sin(radians);

  /// The zero vector.
  static const FixVec2 zero = FixVec2(Fix.zero, Fix.zero);

  /// Horizontal component.
  final Fix x;

  /// Vertical component (positive is downward).
  final Fix y;

  /// Component-wise sum.
  FixVec2 operator +(FixVec2 other) => FixVec2(x + other.x, y + other.y);

  /// Component-wise difference.
  FixVec2 operator -(FixVec2 other) => FixVec2(x - other.x, y - other.y);

  /// The negation of this vector.
  FixVec2 operator -() => FixVec2(-x, -y);

  /// This vector scaled by [factor].
  FixVec2 scale(Fix factor) => FixVec2(x * factor, y * factor);

  /// The dot product with [other].
  Fix dot(FixVec2 other) => x * other.x + y * other.y;

  /// The squared length of this vector.
  ///
  /// Prefer this over [magnitude] in comparisons — it avoids the square
  /// root entirely.
  Fix get magnitudeSquared => x * x + y * y;

  /// The length of this vector.
  Fix get magnitude => FixMath.sqrt(magnitudeSquared);

  /// This vector with its length limited to [maxMagnitude].
  ///
  /// Returns the vector unchanged when already within the limit, so the
  /// common (non-clamped) path costs no square root.
  FixVec2 clampMagnitude(Fix maxMagnitude) {
    if (magnitudeSquared <= maxMagnitude * maxMagnitude) {
      return this;
    }
    final m = magnitude;
    return FixVec2(x / m * maxMagnitude, y / m * maxMagnitude);
  }

  @override
  bool operator ==(Object other) =>
      other is FixVec2 && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'FixVec2(${x.toDouble()}, ${y.toDouble()})';
}
