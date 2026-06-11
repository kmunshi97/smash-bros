import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/input/input_action.dart';

void main() {
  group('InputAction bit values', () {
    test('none is zero', () {
      expect(InputAction.none, 0);
    });

    test('each action is a distinct power of two', () {
      final individual = [
        InputAction.moveLeft,
        InputAction.moveRight,
        InputAction.jump,
        InputAction.normalShot,
        InputAction.smash,
        InputAction.dropShot,
        InputAction.toss,
      ];

      // All distinct.
      final seen = <int>{};
      for (final action in individual) {
        expect(seen.add(action), isTrue, reason: '$action appears twice');
      }

      // Each is a power of two (exactly one bit set).
      for (final action in individual) {
        expect(
          action > 0 && (action & (action - 1)) == 0,
          isTrue,
          reason: '$action is not a power of two',
        );
      }
    });

    test('allShots covers normalShot, smash, dropShot, toss', () {
      expect(
        InputAction.allShots,
        InputAction.normalShot |
            InputAction.smash |
            InputAction.dropShot |
            InputAction.toss,
      );
    });

    test('allMovement covers moveLeft and moveRight only', () {
      expect(
        InputAction.allMovement,
        InputAction.moveLeft | InputAction.moveRight,
      );
    });

    test('allShots does not include movement or jump bits', () {
      expect(InputAction.allShots & InputAction.moveLeft, 0);
      expect(InputAction.allShots & InputAction.moveRight, 0);
      expect(InputAction.allShots & InputAction.jump, 0);
    });
  });

  group('InputAction.has', () {
    test('returns true when the bit is set', () {
      const mask = InputAction.jump | InputAction.smash;
      expect(InputAction.has(mask, InputAction.jump), isTrue);
      expect(InputAction.has(mask, InputAction.smash), isTrue);
    });

    test('returns false when the bit is not set', () {
      const mask = InputAction.jump | InputAction.smash;
      expect(InputAction.has(mask, InputAction.moveLeft), isFalse);
      expect(InputAction.has(mask, InputAction.normalShot), isFalse);
    });

    test('has with none always returns false', () {
      expect(InputAction.has(InputAction.jump, InputAction.none), isFalse);
      expect(InputAction.has(InputAction.none, InputAction.jump), isFalse);
    });

    test('full bitmask has every individual action', () {
      const all =
          InputAction.moveLeft |
          InputAction.moveRight |
          InputAction.jump |
          InputAction.normalShot |
          InputAction.smash |
          InputAction.dropShot |
          InputAction.toss;
      for (final action in [
        InputAction.moveLeft,
        InputAction.moveRight,
        InputAction.jump,
        InputAction.normalShot,
        InputAction.smash,
        InputAction.dropShot,
        InputAction.toss,
      ]) {
        expect(InputAction.has(all, action), isTrue);
      }
    });
  });

  group('InputAction.countShotBits', () {
    test('no shots → 0', () {
      expect(
        InputAction.countShotBits(InputAction.jump | InputAction.moveLeft),
        0,
      );
    });

    test('single shot bits → 1 each', () {
      expect(InputAction.countShotBits(InputAction.normalShot), 1);
      expect(InputAction.countShotBits(InputAction.smash), 1);
      expect(InputAction.countShotBits(InputAction.dropShot), 1);
      expect(InputAction.countShotBits(InputAction.toss), 1);
    });

    test('two shot bits → 2', () {
      expect(
        InputAction.countShotBits(InputAction.smash | InputAction.normalShot),
        2,
      );
      expect(
        InputAction.countShotBits(InputAction.dropShot | InputAction.toss),
        2,
      );
    });

    test('all four shot bits → 4', () {
      expect(InputAction.countShotBits(InputAction.allShots), 4);
    });

    test('non-shot bits do not inflate the count', () {
      const mask =
          InputAction.allShots |
          InputAction.jump |
          InputAction.moveLeft |
          InputAction.moveRight;
      expect(InputAction.countShotBits(mask), 4);
    });
  });
}
