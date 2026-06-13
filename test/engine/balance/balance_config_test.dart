// Engine-layer tests for BalanceConfig (M1-032): defaults match the k*
// constants, JSON round-trips, partial JSON degrades to defaults, and the
// checked-in asset file parses back to defaults (no drift). Pure Dart.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/balance/balance.dart';
import 'package:smash_bros/engine/constants.dart';

void main() {
  group('BalanceConfig.defaults', () {
    test('every field equals its k* constant', () {
      const c = BalanceConfig.defaults();
      expect(c.shuttleGravity, kShuttleGravity);
      expect(c.shuttleDragCoefficient, kShuttleDragCoefficient);
      expect(c.shuttleDropShotDrag, kShuttleDropShotDrag);
      expect(c.shuttleMaxVelocity, kShuttleMaxVelocity);
      expect(c.netCordDamping, kNetCordDamping);
      expect(c.normalShotSpeed, kNormalShotSpeed);
      expect(c.smashSpeed, kSmashSpeed);
      expect(c.dropShotSpeed, kDropShotSpeed);
      expect(c.jumpSmashBonus, kJumpSmashBonus);
      expect(c.tossSpeedMin, kTossSpeedMin);
      expect(c.tossSpeedMax, kTossSpeedMax);
      expect(c.playerSpeed, kPlayerSpeed);
      expect(c.staminaDrainNormal, kStaminaDrainNormal);
      expect(c.staminaDrainSmash, kStaminaDrainSmash);
      expect(c.staminaDrainJump, kStaminaDrainJump);
      expect(c.staminaDrainMove, kStaminaDrainMove);
      expect(c.staminaRegen, kStaminaRegen);
    });
  });

  group('JSON round-trip', () {
    test('toJson → fromJson is the identity', () {
      const original = BalanceConfig.defaults();
      final restored = BalanceConfig.fromJson(original.toJson());
      expect(restored, equals(original));
    });

    test('a tuned config round-trips exactly', () {
      final tuned = const BalanceConfig.defaults().copyWith(
        shuttleGravity: 0.22,
        smashSpeed: 19,
        playerSpeed: 8.5,
      );
      final restored = BalanceConfig.fromJson(tuned.toJson());
      expect(restored, equals(tuned));
      expect(restored.shuttleGravity, 0.22);
      expect(restored.smashSpeed, 19);
      expect(restored.playerSpeed, 8.5);
    });

    test('missing/invalid keys fall back to defaults', () {
      const d = BalanceConfig.defaults();
      final partial = BalanceConfig.fromJson(const <String, dynamic>{
        'shuttleGravity': 0.3,
        'smashSpeed': 'not a number',
        // everything else absent
      });
      expect(partial.shuttleGravity, 0.3);
      expect(partial.smashSpeed, d.smashSpeed); // invalid → default
      expect(partial.playerSpeed, d.playerSpeed); // absent → default
    });

    test('integer JSON values are read as doubles', () {
      final config = BalanceConfig.fromJson(const <String, dynamic>{
        'smashSpeed': 16, // int, not 16.0
      });
      expect(config.smashSpeed, 16.0);
    });
  });

  group('copyWith', () {
    test('changes only the named field', () {
      const d = BalanceConfig.defaults();
      final c = d.copyWith(shuttleGravity: 0.25);
      expect(c.shuttleGravity, 0.25);
      expect(c.smashSpeed, d.smashSpeed);
      expect(c.playerSpeed, d.playerSpeed);
    });
  });

  group('equality', () {
    test('equal configs are == with equal hashCodes', () {
      const a = BalanceConfig.defaults();
      const b = BalanceConfig.defaults();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('a single differing field breaks equality', () {
      const a = BalanceConfig.defaults();
      final b = a.copyWith(shuttleGravity: a.shuttleGravity + 0.01);
      expect(a, isNot(equals(b)));
    });
  });

  group('checked-in asset', () {
    test('assets/data/balance.json parses back to defaults (no drift)', () {
      // Reads the file directly from disk (VM test) rather than via rootBundle,
      // so the test stays pure-Dart and needs no Flutter binding. If a future
      // edit changes the asset away from the shipped defaults, this fails —
      // the asset must always mirror BalanceConfig.defaults().
      final file = File('assets/data/balance.json');
      expect(file.existsSync(), isTrue, reason: 'balance asset must exist');

      final decoded = jsonDecode(file.readAsStringSync());
      expect(decoded, isA<Map<String, dynamic>>());

      final fromAsset = BalanceConfig.fromJson(decoded as Map<String, dynamic>);
      expect(
        fromAsset,
        equals(const BalanceConfig.defaults()),
        reason: 'the shipped balance.json must equal BalanceConfig.defaults()',
      );
    });
  });
}
