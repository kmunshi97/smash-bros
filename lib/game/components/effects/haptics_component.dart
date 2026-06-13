import 'package:flame/components.dart';
import 'package:flutter/services.dart';
import 'package:smash_bros/engine/render/render_state.dart';
import 'package:smash_bros/engine/systems/shot_type.dart';
import 'package:smash_bros/game/badminton_game.dart';

/// A single haptic impulse. Abstracted behind a typedef so tests can inject a
/// recorder instead of hitting the (platform-channel) `HapticFeedback` API.
typedef HapticImpulse = void Function();

/// Fires device haptics on impactful match events (M2-030).
///
/// The cheapest "feel" win available: a medium buzz on every smash connect and
/// a heavier one on a perfect block. Carries **no game logic** — like every
/// other component it only reads [BadmintonGame.frameEvents], which delivers
/// each simulation tick's events exactly once regardless of display rate, so a
/// 120 Hz screen never double-buzzes.
///
/// The actual impulses are injectable (the `smashImpulse` /
/// `perfectBlockImpulse` constructor arguments) so widget tests can assert "a
/// smash buzzed" without a platform channel; in production they default to
/// [HapticFeedback]. Haptics are a no-op on devices without a vibrator (and
/// harmless on desktop dev targets).
class HapticsComponent extends Component with HasGameReference<BadmintonGame> {
  /// Creates the haptics component. Pass [smashImpulse] / [perfectBlockImpulse]
  /// in tests to capture calls; both default to the real [HapticFeedback].
  HapticsComponent({
    HapticImpulse? smashImpulse,
    HapticImpulse? perfectBlockImpulse,
  }) : _smash = smashImpulse ?? HapticFeedback.mediumImpact,
       _perfectBlock = perfectBlockImpulse ?? HapticFeedback.heavyImpact;

  final HapticImpulse _smash;
  final HapticImpulse _perfectBlock;

  @override
  void update(double dt) => reactTo(game.frameEvents);

  /// Fires the appropriate impulse for each event in [events].
  ///
  /// Extracted from [update] (which calls it with [BadmintonGame.frameEvents])
  /// so it can be unit-tested with crafted events and recorder impulses,
  /// without a mounted game.
  ///
  /// Note: the perfect-[BlockEvent] path is wired but currently dormant — a
  /// perfectly timed block swings *before* the shuttle is in reach, which the
  /// M1 engine resolves as a whiff (no connect → no BlockEvent). It will light
  /// up once the early-swing block-connect mechanic lands.
  void reactTo(Iterable<RenderEvent> events) {
    for (final event in events) {
      switch (event) {
        case SwingEvent(shotType: ShotType.smash):
          _smash();
        case BlockEvent(isPerfect: true):
          _perfectBlock();
        case _:
          // Other events carry no haptic.
          break;
      }
    }
  }
}
