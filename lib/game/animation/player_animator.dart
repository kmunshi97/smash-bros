import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

/// The animation state a player avatar is in this frame (M2-005).
///
/// Derived each frame from the player-view-level facts the renderer can see
/// (stun, airborne, rising/falling, moving, mid-swing). Priority, highest
/// first: [stunned] > [swing] > [rise]/[fall] > [land] > [run] > [idle].
enum PlayerAnimState {
  /// Standing still — a gentle breathing bob.
  idle,

  /// Walking — a bouncing gait with a slight forward lean.
  run,

  /// Airborne and gaining height — stretched tall.
  rise,

  /// Airborne and descending — slightly stretched.
  fall,

  /// The brief squash on touchdown after being airborne.
  land,

  /// Mid-swing — an anticipation-then-follow-through racquet arc.
  swing,

  /// Stunned — a dizzy side-to-side wobble.
  stunned,
}

/// The procedural transform a player sprite is drawn with this frame.
///
/// Applied by `PlayerComponent` around the feet pivot: rotate by [rotation],
/// scale by ([scaleX], [scaleY]), and shift vertically by [bobY] (negative is
/// up, matching the +y-down world). The neutral pose is identity.
class PlayerPose {
  /// Creates a pose; every field defaults to its neutral (identity) value.
  const PlayerPose({
    this.scaleX = 1,
    this.scaleY = 1,
    this.rotation = 0,
    this.bobY = 0,
  });

  /// The identity pose (no transform).
  static const PlayerPose neutral = PlayerPose();

  /// Horizontal scale (squash/stretch); 1 is natural width.
  final double scaleX;

  /// Vertical scale (squash/stretch); 1 is natural height.
  final double scaleY;

  /// Rotation in radians, applied around the feet pivot.
  final double rotation;

  /// Vertical offset in game units (negative = up).
  final double bobY;
}

// -- Tuning (presentation-only; never feeds the simulation) -----------------

const double _kIdleFreq = 2.2; // breathing cycles/sec ×2π
const double _kIdleBob = 2; // px

const double _kRunFreq = 13; // bounce cycles
const double _kRunBob = 6; // px upward bounce
const double _kRunLean = 0.10; // rad forward lean

const double _kRiseScaleY = 1.12;
const double _kRiseScaleX = 0.90;
const double _kFallScaleY = 1.05;
const double _kFallScaleX = 0.96;

const double _kLandDuration = 0.13; // s
const double _kLandSquashY = 0.78; // peak squash
const double _kLandStretchX = 1.22;

const double _kStunFreq = 18;
const double _kStunWobble = 0.13; // rad
const double _kStunScaleY = 0.97;

// Swing arc: wind-up (back), swipe (forward peak), settle.
const double _kSwingWindUp = -0.22; // rad, racquet drawn back
const double _kSwingPeak = 0.48; // rad, follow-through
const double _kSwingWindUpEnd = 0.25; // fraction of the swing
const double _kSwingSwipeEnd = 0.55;

/// A small deterministic state machine that turns per-frame player facts into
/// a [PlayerPose] (M2-005).
///
/// Pure presentation: it holds only cosmetic timers, uses `dart:math` freely
/// (never the engine PRNG), and never reads or mutates the simulation. One
/// instance lives per `PlayerComponent`. Given the same `(dt, inputs)`
/// sequence it always produces the same poses, so it is straightforward to
/// unit-test.
class PlayerAnimator {
  /// The current animation state (recomputed each [update]).
  PlayerAnimState get state => _state;
  PlayerAnimState _state = PlayerAnimState.idle;

  /// The pose to draw with this frame (recomputed each [update]).
  PlayerPose get pose => _pose;
  PlayerPose _pose = PlayerPose.neutral;

  // Free-running cosmetic clock for idle/run/stun oscillations.
  double _clock = 0;

  // Landing-squash countdown, armed on an airborne→grounded transition.
  double _landTimer = 0;
  bool _wasAirborne = false;

  /// Advances the animator by [dt] seconds against this frame's facts and
  /// updates [state] and [pose].
  ///
  /// * [stunned] / [airborne] / [moving] come straight from the player view.
  /// * [rising] is whether the avatar gained height since last frame (the
  ///   renderer derives it from the feet-y delta); only meaningful while
  ///   [airborne].
  /// * [swing01] is swing progress in `[0, 1)` while mid-swing, or a negative
  ///   value when not swinging.
  void update(
    double dt, {
    required bool stunned,
    required bool airborne,
    required bool rising,
    required bool moving,
    required double swing01,
  }) {
    _clock += dt;

    // Arm the landing squash on touchdown.
    if (_wasAirborne && !airborne) _landTimer = _kLandDuration;
    _wasAirborne = airborne;
    if (_landTimer > 0) _landTimer = math.max(0, _landTimer - dt);

    final swinging = swing01 >= 0 && swing01 < 1;

    _state = _classify(
      stunned: stunned,
      airborne: airborne,
      rising: rising,
      moving: moving,
      swinging: swinging,
    );
    _pose = _poseFor(_state, swing01);
  }

  PlayerAnimState _classify({
    required bool stunned,
    required bool airborne,
    required bool rising,
    required bool moving,
    required bool swinging,
  }) {
    if (stunned) return PlayerAnimState.stunned;
    if (swinging) return PlayerAnimState.swing;
    if (airborne) return rising ? PlayerAnimState.rise : PlayerAnimState.fall;
    if (_landTimer > 0) return PlayerAnimState.land;
    if (moving) return PlayerAnimState.run;
    return PlayerAnimState.idle;
  }

  PlayerPose _poseFor(PlayerAnimState state, double swing01) {
    switch (state) {
      case PlayerAnimState.idle:
        return PlayerPose(bobY: math.sin(_clock * _kIdleFreq) * _kIdleBob);
      case PlayerAnimState.run:
        // |sin| bounce (always upward), plus a forward lean.
        final bounce = -math.sin(_clock * _kRunFreq).abs() * _kRunBob;
        return PlayerPose(bobY: bounce, rotation: _kRunLean);
      case PlayerAnimState.rise:
        return const PlayerPose(scaleX: _kRiseScaleX, scaleY: _kRiseScaleY);
      case PlayerAnimState.fall:
        return const PlayerPose(scaleX: _kFallScaleX, scaleY: _kFallScaleY);
      case PlayerAnimState.land:
        final p = _landTimer / _kLandDuration; // 1 → 0
        return PlayerPose(
          scaleX: lerpDouble(1, _kLandStretchX, p)!,
          scaleY: lerpDouble(1, _kLandSquashY, p)!,
        );
      case PlayerAnimState.swing:
        return PlayerPose(rotation: _swingRotation(swing01), scaleX: 1.04);
      case PlayerAnimState.stunned:
        return PlayerPose(
          rotation: math.sin(_clock * _kStunFreq) * _kStunWobble,
          scaleY: _kStunScaleY,
        );
    }
  }

  /// The racquet-arc rotation across a swing: a quick wind-up *back*, a fast
  /// swipe *forward* to the peak, then a settle to neutral.
  static double _swingRotation(double p) {
    if (p < _kSwingWindUpEnd) {
      return lerpDouble(0, _kSwingWindUp, p / _kSwingWindUpEnd)!;
    }
    if (p < _kSwingSwipeEnd) {
      return lerpDouble(
        _kSwingWindUp,
        _kSwingPeak,
        (p - _kSwingWindUpEnd) / (_kSwingSwipeEnd - _kSwingWindUpEnd),
      )!;
    }
    return lerpDouble(
      _kSwingPeak,
      0,
      (p - _kSwingSwipeEnd) / (1 - _kSwingSwipeEnd),
    )!;
  }
}
