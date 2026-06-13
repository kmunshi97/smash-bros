// Unit tests for the ScreenShake controller (M2-003). Pure: no Flame harness.
import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/game/effects/screen_shake.dart';

void main() {
  group('ScreenShake', () {
    test('is idle with zero offset before any trigger', () {
      final shake = ScreenShake(seed: 1);
      expect(shake.isShaking, isFalse);
      expect(shake.offset.length, 0);
    });

    test('a trigger produces a non-zero offset within the amplitude', () {
      final shake = ScreenShake(seed: 1)..shake(10);
      expect(shake.isShaking, isTrue);
      final o = shake.offset;
      // Each axis is within [-amplitude, amplitude] at full strength.
      expect(o.x.abs(), lessThanOrEqualTo(10));
      expect(o.y.abs(), lessThanOrEqualTo(10));
    });

    test('offset magnitude decays toward zero as the timer runs out', () {
      final shake = ScreenShake(seed: 2, decaySeconds: 0.3)..shake(10);
      // Sample early strength, then advance most of the decay window.
      final early = shake.offset.length;
      shake.update(0.27); // 0.03 s remaining → ~10% strength
      final late = shake.offset.length;
      expect(late, lessThan(early));
    });

    test('fully decays after the decay window and reports idle', () {
      final shake = ScreenShake(seed: 3, decaySeconds: 0.3)
        ..shake(10)
        ..update(0.3);
      expect(shake.isShaking, isFalse);
      expect(shake.offset.length, 0);
    });

    test('a stronger trigger mid-shake wins (max amplitude)', () {
      final shake = ScreenShake(seed: 4, decaySeconds: 0.3)
        ..shake(4)
        ..update(0.15) // halfway through the small shake
        ..shake(20) // bigger hit refreshes timer + raises amplitude
        ..update(0); // no time elapsed
      // At full strength of the new amplitude, an axis can exceed the old peak.
      // Sample several times since the offset is random per call.
      var sawLarge = false;
      for (var i = 0; i < 50; i++) {
        if (shake.offset.x.abs() > 4 || shake.offset.y.abs() > 4) {
          sawLarge = true;
          break;
        }
      }
      expect(sawLarge, isTrue, reason: 'amplitude should have grown to 20');
      expect(shake.isShaking, isTrue);
    });

    test('is deterministic for a given seed', () {
      final a = ScreenShake(seed: 9)..shake(10);
      final b = ScreenShake(seed: 9)..shake(10);
      final oa = a.offset;
      final ob = b.offset;
      expect(oa.x, ob.x);
      expect(oa.y, ob.y);
    });
  });
}
