// Verifies Tunables delegates feel fields to the active BalanceConfig and that
// applying a config actually changes engine behaviour (M1-032). Pure Dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/balance/balance.dart';
import 'package:smash_bros/engine/entities/shuttle.dart';
import 'package:smash_bros/engine/entities/tunables.dart';
import 'package:smash_bros/engine/math/fix.dart';
import 'package:smash_bros/engine/math/fix_vec2.dart';

void main() {
  // Every test that mutates the global config must reset it afterward so it
  // never leaks into another test.
  tearDown(Tunables.resetToDefaults);

  group('Tunables feel getters', () {
    test('default to the shipped values', () {
      Tunables.resetToDefaults();
      expect(Tunables.shuttleGravity.toDouble(), kDefaultGravity);
      expect(Tunables.smashSpeed.toDouble(), 16);
      expect(Tunables.playerSpeed.toDouble(), 6);
    });

    test('reflect an applied config', () {
      Tunables.apply(
        const BalanceConfig.defaults().copyWith(
          shuttleGravity: 0.30,
          playerSpeed: 9,
        ),
      );
      expect(Tunables.shuttleGravity.toDouble(), 0.30);
      expect(Tunables.playerSpeed.toDouble(), 9);
      // A field we did not override stays at the default.
      expect(Tunables.smashSpeed.toDouble(), 16);
    });

    test('structural constants are NOT affected by config', () {
      Tunables.apply(
        const BalanceConfig.defaults().copyWith(shuttleGravity: 0.30),
      );
      // Net position / hitbox are structural — they have no config field and
      // must be unchanged.
      expect(Tunables.netTopY.toDouble(), 470);
      expect(Tunables.playerHitboxHeight.toDouble(), 150);
    });
  });

  group('applied gravity changes shuttle integration', () {
    test('higher gravity makes the shuttle fall faster in one tick', () {
      Shuttle freshShuttle() => Shuttle(
        position: const FixVec2(Fix.of(640), Fix.of(300)),
      );

      Tunables.resetToDefaults();
      final low = freshShuttle()
        ..integrate(dragCoefficient: Tunables.shuttleDragCoefficient);
      final lowVy = low.velocity.y.toDouble();

      Tunables.apply(
        const BalanceConfig.defaults().copyWith(shuttleGravity: 0.30),
      );
      final high = freshShuttle()
        ..integrate(dragCoefficient: Tunables.shuttleDragCoefficient);
      final highVy = high.velocity.y.toDouble();

      expect(
        highVy,
        greaterThan(lowVy),
        reason: 'gravity 0.30 must accelerate the shuttle more than 0.14',
      );
    });
  });

  group('resetToDefaults', () {
    test('restores the active config to defaults', () {
      Tunables.apply(
        const BalanceConfig.defaults().copyWith(shuttleGravity: 0.30),
      );
      expect(Tunables.config.shuttleGravity, 0.30);
      Tunables.resetToDefaults();
      expect(Tunables.config, equals(const BalanceConfig.defaults()));
    });
  });
}

/// The shipped default gravity, duplicated here as a literal so the test fails
/// loudly if the default ever changes without the test being revisited.
const double kDefaultGravity = 0.14;
