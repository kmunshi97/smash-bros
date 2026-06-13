import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/game/badminton_game.dart';

/// How much larger than the court the backdrop is drawn, so it can drift
/// without revealing an edge. 8% overscan ≈ 51 px horizontal / 29 px vertical
/// of margin — comfortably more than the shake + idle drift ever uses.
const double _kOverscan = 1.08;

/// Fraction of the camera's shake the backdrop tracks. < 1 means it moves less
/// on screen than the world-fixed floor, so it reads as *farther away* — the
/// parallax depth cue.
const double _kParallaxFactor = 0.5;

/// Gentle ambient sway so the scene breathes even at rest (game units).
const double _kIdleSwayX = 6;
const double _kIdleSwayY = 3;
const double _kIdleSwayFreqX = 0.4;
const double _kIdleSwayFreqY = 0.27;

/// The stadium background drawn with parallax depth (M2-002).
///
/// Pure presentation. The court floor and net are world-fixed (the playfield),
/// but this far layer drifts: it tracks a fraction of the camera's shake
/// ([BadmintonGame.cameraShakeOffset]) so on a smash the crowd parallaxes
/// behind the action, plus a slow idle sway so the scene is never dead-still.
/// It is oversized by [_kOverscan] and centred so the drift never exposes a
/// court edge.
class ParallaxBackdropComponent extends SpriteComponent
    with HasGameReference<BadmintonGame> {
  /// Creates the backdrop at the given sprite-load [priority] within its parent.
  ParallaxBackdropComponent({super.priority});

  late final Vector2 _base;
  double _t = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await game.loadSprite('stadium_bg.png');
    size = Vector2(kCourtWidth, kCourtHeight) * _kOverscan;
    // Centre the oversized sprite: top-left sits half the overscan up-and-left.
    _base = Vector2(
      -(size.x - kCourtWidth) / 2,
      -(size.y - kCourtHeight) / 2,
    );
    position = _base;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    position = offsetFor(_base, game.cameraShakeOffset, _t);
  }

  /// The backdrop's top-left position given its [base], the current camera
  /// [shake] offset, and the ambient clock [t] (seconds).
  ///
  /// Pure and static so the parallax maths can be unit-tested without a game.
  static Vector2 offsetFor(Vector2 base, Vector2 shake, double t) {
    return Vector2(
      base.x +
          shake.x * _kParallaxFactor +
          math.sin(t * _kIdleSwayFreqX) * _kIdleSwayX,
      base.y +
          shake.y * _kParallaxFactor +
          math.sin(t * _kIdleSwayFreqY) * _kIdleSwayY,
    );
  }
}
