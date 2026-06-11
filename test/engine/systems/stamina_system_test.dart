import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/entities/player.dart';
import 'package:smash_bros/engine/entities/tunables.dart';
import 'package:smash_bros/engine/math/fix.dart';
import 'package:smash_bros/engine/systems/shot_type.dart';
import 'package:smash_bros/engine/systems/stamina_system.dart';

// Stamina constants (constants.dart): max 100, drainMove 0.5, regen 0.3,
// drainNormal 5, drainSmash 15, drainJump 8, debuffThreshold 30, minMult 0.5.

Player _player({double stamina = 100, int jumpTick = -1}) => Player(
  x: const Fix.of(300),
  courtSide: CourtSide.left,
  stamina: Fix.of(stamina),
  jumpTick: jumpTick,
);

/// A jumping (airborne) player at the arc midpoint.
Player _airborne({double stamina = 100}) =>
    _player(stamina: stamina, jumpTick: 20);

void main() {
  group('StaminaSystem.tick', () {
    test('moving drains drainMove', () {
      final p = _player(stamina: 50);
      StaminaSystem.tick(p, moved: true);
      expect(p.stamina, const Fix.of(50 - 0.5));
    });

    test('idle and grounded regenerates regen', () {
      final p = _player(stamina: 50);
      StaminaSystem.tick(p, moved: false);
      expect(p.stamina, const Fix.of(50 + 0.3));
    });

    test('airborne and idle does NOT regenerate', () {
      final p = _airborne(stamina: 50);
      StaminaSystem.tick(p, moved: false);
      expect(p.stamina, const Fix.of(50));
    });

    test('airborne and moving still drains', () {
      final p = _airborne(stamina: 50);
      StaminaSystem.tick(p, moved: true);
      expect(p.stamina, const Fix.of(50 - 0.5));
    });

    test('regen clamps at the maximum', () {
      final p = _player();
      StaminaSystem.tick(p, moved: false);
      expect(p.stamina, Tunables.staminaMax);
    });

    test('drain clamps at zero', () {
      final p = _player(stamina: 0.2);
      StaminaSystem.tick(p, moved: true);
      expect(p.stamina, Fix.zero);
    });

    test('stun does NOT block regeneration', () {
      final p = _player(stamina: 50)..stunTicksRemaining = 30;
      StaminaSystem.tick(p, moved: false);
      expect(p.stamina, const Fix.of(50 + 0.3));
    });
  });

  group('StaminaSystem.chargeShot', () {
    test('normal drains drainNormal', () {
      final p = _player(stamina: 50);
      StaminaSystem.chargeShot(p, ShotType.normal);
      expect(p.stamina, const Fix.of(45));
    });

    test('smash drains drainSmash', () {
      final p = _player(stamina: 50);
      StaminaSystem.chargeShot(p, ShotType.smash);
      expect(p.stamina, const Fix.of(35));
    });

    test('drop costs the same as a normal stroke', () {
      final p = _player(stamina: 50);
      StaminaSystem.chargeShot(p, ShotType.drop);
      expect(p.stamina, const Fix.of(45));
    });

    test('toss is free', () {
      final p = _player(stamina: 50);
      StaminaSystem.chargeShot(p, ShotType.toss);
      expect(p.stamina, const Fix.of(50));
    });

    test('clamps at zero when the cost exceeds remaining stamina', () {
      final p = _player(stamina: 3);
      StaminaSystem.chargeShot(p, ShotType.smash);
      expect(p.stamina, Fix.zero);
    });
  });

  group('StaminaSystem.chargeJump', () {
    test('drains drainJump', () {
      final p = _player(stamina: 50);
      StaminaSystem.chargeJump(p);
      expect(p.stamina, const Fix.of(42));
    });

    test('clamps at zero', () {
      final p = _player(stamina: 3);
      StaminaSystem.chargeJump(p);
      expect(p.stamina, Fix.zero);
    });
  });

  group('StaminaSystem.effortMultiplier', () {
    test('is 1.0 at full stamina', () {
      expect(StaminaSystem.effortMultiplier(_player()), Fix.one);
    });

    test('is exactly 1.0 at the threshold (boundary is unpenalised)', () {
      expect(StaminaSystem.effortMultiplier(_player(stamina: 30)), Fix.one);
    });

    test('is the minimum multiplier at zero stamina', () {
      expect(
        StaminaSystem.effortMultiplier(_player(stamina: 0)),
        Tunables.staminaMinMultiplier,
      );
    });

    test('linear midpoint: stamina 15 (half threshold) gives 0.75', () {
      // min + (1 - min) * (15/30) = 0.5 + 0.5 * 0.5 = 0.75.
      expect(
        StaminaSystem.effortMultiplier(_player(stamina: 15)),
        const Fix.of(0.75),
      );
    });

    test('is pure — does not mutate the player', () {
      final p = _player(stamina: 15);
      StaminaSystem.effortMultiplier(p);
      expect(p.stamina, const Fix.of(15));
    });
  });
}
