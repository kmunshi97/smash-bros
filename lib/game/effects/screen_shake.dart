import 'dart:math' as math;

import 'package:flame/components.dart';

/// A decaying camera-shake controller (M2-003).
///
/// Lives in the **presentation layer**, so it may use `dart:math`'s `Random`
/// freely — screen shake is purely cosmetic, never feeds the deterministic
/// simulation, and is not part of any rollback stream.
///
/// ## Model
///
/// A trigger sets a remaining-duration timer and a peak amplitude. Each
/// [update] decays the remaining time linearly; [offset] returns a random
/// displacement whose magnitude scales with the remaining fraction, so the
/// shake starts strong and eases to zero. A stronger trigger arriving mid-shake
/// takes the **max** of the two amplitudes (and refreshes the timer) so a big
/// hit is never swallowed by a dying small one.
///
/// The caller adds [offset] to the camera's base look-at position each frame.
class ScreenShake {
  /// Creates a controller; [seed] makes the (cosmetic) jitter reproducible for
  /// tests. [decaySeconds] is how long a triggered shake takes to fully decay.
  ScreenShake({int seed = 0, this.decaySeconds = 0.35})
    : _random = math.Random(seed);

  final math.Random _random;

  /// Seconds a triggered shake takes to decay from full amplitude to zero.
  final double decaySeconds;

  double _remaining = 0;
  double _amplitude = 0;

  /// Whether a shake is currently active.
  bool get isShaking => _remaining > 0;

  /// Triggers a shake of peak [amplitude] (in game units of camera offset).
  ///
  /// If a shake is already running, the larger amplitude wins and the timer is
  /// refreshed, so a smash never gets visually swallowed by a lingering minor
  /// shake.
  void shake(double amplitude) {
    _amplitude = math.max(_amplitude, amplitude);
    _remaining = decaySeconds;
  }

  /// Advances the decay timer by [dt] seconds.
  void update(double dt) {
    if (_remaining <= 0) return;
    _remaining = math.max(0, _remaining - dt);
    if (_remaining == 0) _amplitude = 0;
  }

  /// The current camera displacement: a random vector whose magnitude scales
  /// with the remaining fraction of the shake (zero when not shaking).
  Vector2 get offset {
    if (_remaining <= 0) return Vector2.zero();
    final scale = (_remaining / decaySeconds) * _amplitude;
    // Uniform in [-scale, scale] on each axis.
    return Vector2(
      (_random.nextDouble() * 2 - 1) * scale,
      (_random.nextDouble() * 2 - 1) * scale,
    );
  }
}
