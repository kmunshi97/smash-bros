import 'dart:math' as math;

/// The engine's scalar number type (ADR-1 preparation).
///
/// All simulation math goes through [Fix] instead of raw [double] so that the
/// Milestone 3 switch to Q16.16 fixed-point arithmetic is a mechanical change
/// of this file's internals: call sites, signatures, and serialized layouts
/// stay untouched.
///
/// Currently backed by a [double] via a zero-cost extension type — there is
/// no wrapper allocation at runtime.
///
/// Rules for engine code:
///
/// * Never call `dart:math` directly — use [FixMath] (its internals become
///   deterministic lookup tables in Milestone 3).
/// * Never convert through [toDouble] inside simulation logic; it exists for
///   the rendering layer and debugging only.
extension type const Fix._(double _raw) implements Object {
  /// Creates a [Fix] from a [double] literal or expression.
  const Fix.of(double value) : _raw = value;

  /// Creates a [Fix] from an integer.
  const Fix.fromInt(int value) : _raw = value + 0.0;

  /// The additive identity.
  static const Fix zero = Fix.of(0);

  /// The multiplicative identity.
  static const Fix one = Fix.of(1);

  /// The smaller of [a] and [b].
  static Fix min(Fix a, Fix b) => a < b ? a : b;

  /// The larger of [a] and [b].
  static Fix max(Fix a, Fix b) => a > b ? a : b;

  /// Adds two scalars.
  Fix operator +(Fix other) => Fix._(_raw + other._raw);

  /// Subtracts [other] from this scalar.
  Fix operator -(Fix other) => Fix._(_raw - other._raw);

  /// Multiplies two scalars.
  Fix operator *(Fix other) => Fix._(_raw * other._raw);

  /// Divides this scalar by [other].
  Fix operator /(Fix other) => Fix._(_raw / other._raw);

  /// The negation of this scalar.
  Fix operator -() => Fix._(-_raw);

  /// Whether this scalar is strictly less than [other].
  bool operator <(Fix other) => _raw < other._raw;

  /// Whether this scalar is less than or equal to [other].
  bool operator <=(Fix other) => _raw <= other._raw;

  /// Whether this scalar is strictly greater than [other].
  bool operator >(Fix other) => _raw > other._raw;

  /// Whether this scalar is greater than or equal to [other].
  bool operator >=(Fix other) => _raw >= other._raw;

  /// The absolute value of this scalar.
  Fix abs() => Fix._(_raw.abs());

  /// This scalar limited to the inclusive range [lower]..[upper].
  Fix clamp(Fix lower, Fix upper) => Fix._(_raw.clamp(lower._raw, upper._raw));

  /// Whether this scalar is negative.
  bool get isNegative => _raw < 0;

  /// Converts to a [double] for rendering and debugging.
  ///
  /// Must not be used inside simulation logic (see class docs).
  double toDouble() => _raw;
}

/// Deterministic math functions over [Fix] (ADR-1 preparation).
///
/// Currently delegates to `dart:math`. In Milestone 3 the trigonometric
/// functions become lookup-table/CORDIC implementations because platform
/// `sin`/`cos` are not bit-identical across CPU architectures — which would
/// desync lockstep netcode. Keeping every transcendental call behind this
/// facade makes that swap invisible to the rest of the engine.
abstract final class FixMath {
  /// The circle constant.
  static const Fix pi = Fix.of(math.pi);

  /// The sine of [radians].
  static Fix sin(Fix radians) => Fix.of(math.sin(radians.toDouble()));

  /// The cosine of [radians].
  static Fix cos(Fix radians) => Fix.of(math.cos(radians.toDouble()));

  /// The non-negative square root of [value].
  static Fix sqrt(Fix value) => Fix.of(math.sqrt(value.toDouble()));
}
