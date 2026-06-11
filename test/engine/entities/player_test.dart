import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/entities/player.dart';
import 'package:smash_bros/engine/math/fix.dart';

void main() {
  const court = Court();

  Player leftPlayer() =>
      Player(x: const Fix.of(kPlayer1StartX), courtSide: CourtSide.left);
  Player rightPlayer() =>
      Player(x: const Fix.of(kPlayer2StartX), courtSide: CourtSide.right);

  group('Player jump arc', () {
    test('feet at ground level when grounded', () {
      final p = leftPlayer();
      expect(p.isGrounded, isTrue);
      expect(p.y.toDouble(), kGroundY);
    });

    test('y returns to ground at tick 0 and after the full duration', () {
      final p = leftPlayer()..startJump();
      // Tick 0 of the arc: offset is zero.
      expect(p.y.toDouble(), closeTo(kGroundY, 1e-9));
      for (var i = 0; i < kPlayerJumpDuration; i++) {
        p.tickJump();
      }
      expect(p.isGrounded, isTrue);
      expect(p.y.toDouble(), kGroundY);
    });

    test('apex ~= kPlayerJumpApexY at the arc midpoint', () {
      final p = leftPlayer()..startJump();
      for (var i = 0; i < kPlayerJumpDuration ~/ 2; i++) {
        p.tickJump();
      }
      expect(p.y.toDouble(), closeTo(kPlayerJumpApexY, 1e-6));
    });

    test('cannot double-jump', () {
      final p = leftPlayer();
      expect(p.startJump(), isTrue);
      p.tickJump();
      // Already airborne.
      expect(p.startJump(), isFalse);
    });
  });

  group('Player stun gating', () {
    test('a stunned player cannot start a jump', () {
      final p = leftPlayer()..stunTicksRemaining = kStunDurationFrames;
      expect(p.isStunned, isTrue);
      expect(p.startJump(), isFalse);
      expect(p.isGrounded, isTrue);
    });

    test('a stunned player cannot move', () {
      final p = leftPlayer()..stunTicksRemaining = kStunDurationFrames;
      final before = p.x;
      p.moveBy(const Fix.of(50), court);
      expect(p.x, before);
    });
  });

  group('Player movement', () {
    test('facing follows the movement direction', () {
      final p = leftPlayer()..moveBy(const Fix.of(5), court);
      expect(p.facing, Facing.right);
      p.moveBy(const Fix.of(-5), court);
      expect(p.facing, Facing.left);
      // Zero movement leaves facing unchanged.
      p.moveBy(Fix.zero, court);
      expect(p.facing, Facing.left);
    });

    test('left player clamps at the outer bound and at the net', () {
      const half = kPlayerHitboxWidth / 2;
      final p = leftPlayer()..moveBy(const Fix.of(-10000), court);
      expect(p.x.toDouble(), kCourtLeftBound + half);

      p.moveBy(const Fix.of(10000), court);
      expect(p.x.toDouble(), kNetX - half);
    });

    test('right player clamps at the net and at the outer bound', () {
      const half = kPlayerHitboxWidth / 2;
      final p = rightPlayer()..moveBy(const Fix.of(-10000), court);
      expect(p.x.toDouble(), kNetX + half);

      p.moveBy(const Fix.of(10000), court);
      expect(p.x.toDouble(), kCourtRightBound - half);
    });
  });

  group('Player hitbox', () {
    test('anchors at the feet and extends upward', () {
      final p = leftPlayer();
      expect(p.hitboxBottom.toDouble(), kGroundY);
      expect(p.hitboxTop.toDouble(), kGroundY - kPlayerHitboxHeight);
      expect(p.hitboxLeft.toDouble(), kPlayer1StartX - kPlayerHitboxWidth / 2);
      expect(p.hitboxRight.toDouble(), kPlayer1StartX + kPlayerHitboxWidth / 2);
      // Top is above the bottom (smaller y = higher).
      expect(p.hitboxTop.toDouble(), lessThan(p.hitboxBottom.toDouble()));
    });
  });

  group('Player.copy', () {
    test('is independent of the original', () {
      final original = leftPlayer()..startJump();
      final clone = original.copy()
        ..moveBy(const Fix.of(100), court)
        ..tickJump();
      expect(original.jumpTick, 0);
      expect(original.facing, Facing.right);
      expect(clone.jumpTick, 1);
      expect(original.x.toDouble(), kPlayer1StartX);
    });
  });
}
