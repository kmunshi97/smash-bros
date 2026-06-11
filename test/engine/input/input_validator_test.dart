import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/input/input_action.dart';
import 'package:smash_bros/engine/input/input_validator.dart';

// Convenience alias for shorter test bodies.
int _san({
  required int bitmask,
  bool isStunned = false,
  InputContext context = InputContext.rally,
  bool isServer = false,
}) => InputValidator.sanitize(
  bitmask: bitmask,
  isStunned: isStunned,
  context: context,
  isServer: isServer,
);

void main() {
  // ---------------------------------------------------------------------------
  // Rule 1 — stun
  // ---------------------------------------------------------------------------
  group('Rule 1: stun drops everything', () {
    test('stunned player with all bits set → none', () {
      const all =
          InputAction.moveLeft |
          InputAction.moveRight |
          InputAction.jump |
          InputAction.normalShot |
          InputAction.smash |
          InputAction.dropShot |
          InputAction.toss;
      expect(_san(bitmask: all, isStunned: true), InputAction.none);
    });

    test('stun beats contradictory movement (order check)', () {
      const mask = InputAction.moveLeft | InputAction.moveRight;
      expect(_san(bitmask: mask, isStunned: true), InputAction.none);
    });

    test('not stunned — bitmask passes through rule 1 unchanged', () {
      // Rule 1 is a no-op when not stunned; rest of the bitmask still flows.
      expect(_san(bitmask: InputAction.jump), InputAction.jump);
    });
  });

  // ---------------------------------------------------------------------------
  // Rule 2 — contradictory movement
  // ---------------------------------------------------------------------------
  group('Rule 2: contradictory movement cancels out', () {
    test('moveLeft + moveRight → both cleared', () {
      const mask = InputAction.moveLeft | InputAction.moveRight;
      final result = _san(bitmask: mask);
      expect(InputAction.has(result, InputAction.moveLeft), isFalse);
      expect(InputAction.has(result, InputAction.moveRight), isFalse);
    });

    test('only moveLeft set → kept', () {
      expect(
        InputAction.has(
          _san(bitmask: InputAction.moveLeft),
          InputAction.moveLeft,
        ),
        isTrue,
      );
    });

    test('only moveRight set → kept', () {
      expect(
        InputAction.has(
          _san(bitmask: InputAction.moveRight),
          InputAction.moveRight,
        ),
        isTrue,
      );
    });

    test('contradictory movement clears only movement bits, keeps others', () {
      const mask =
          InputAction.moveLeft | InputAction.moveRight | InputAction.jump;
      final result = _san(bitmask: mask);
      expect(InputAction.has(result, InputAction.jump), isTrue);
      expect(InputAction.has(result, InputAction.moveLeft), isFalse);
      expect(InputAction.has(result, InputAction.moveRight), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Rule 3 — toss legality
  // ---------------------------------------------------------------------------
  group('Rule 3: toss legality', () {
    test('toss during serving as server → kept', () {
      final result = _san(
        bitmask: InputAction.toss,
        context: InputContext.serving,
        isServer: true,
      );
      expect(InputAction.has(result, InputAction.toss), isTrue);
    });

    test('toss during serving as non-server → cleared', () {
      final result = _san(
        bitmask: InputAction.toss,
        context: InputContext.serving,
      );
      expect(InputAction.has(result, InputAction.toss), isFalse);
    });

    test('toss during rally as server → cleared', () {
      final result = _san(
        bitmask: InputAction.toss,
        isServer: true,
      );
      expect(InputAction.has(result, InputAction.toss), isFalse);
    });

    test('toss during rally as non-server → cleared', () {
      final result = _san(bitmask: InputAction.toss);
      expect(InputAction.has(result, InputAction.toss), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Rule 4 — serving isolation
  // ---------------------------------------------------------------------------
  group('Rule 4: serving context clears rally shots', () {
    test('normalShot during serving → cleared', () {
      final result = _san(
        bitmask: InputAction.normalShot,
        context: InputContext.serving,
        isServer: true,
      );
      expect(InputAction.has(result, InputAction.normalShot), isFalse);
    });

    test('smash during serving → cleared', () {
      final result = _san(
        bitmask: InputAction.smash,
        context: InputContext.serving,
        isServer: true,
      );
      expect(InputAction.has(result, InputAction.smash), isFalse);
    });

    test('dropShot during serving → cleared', () {
      final result = _san(
        bitmask: InputAction.dropShot,
        context: InputContext.serving,
        isServer: true,
      );
      expect(InputAction.has(result, InputAction.dropShot), isFalse);
    });

    test('jump and movement are not cleared by serving context', () {
      const mask = InputAction.jump | InputAction.moveRight;
      final result = _san(bitmask: mask, context: InputContext.serving);
      expect(InputAction.has(result, InputAction.jump), isTrue);
      expect(InputAction.has(result, InputAction.moveRight), isTrue);
    });

    test('serving context: toss + all rally shots → only toss survives '
        '(for the server)', () {
      const mask =
          InputAction.toss |
          InputAction.normalShot |
          InputAction.smash |
          InputAction.dropShot;
      final result = _san(
        bitmask: mask,
        context: InputContext.serving,
        isServer: true,
      );
      expect(InputAction.has(result, InputAction.toss), isTrue);
      expect(InputAction.has(result, InputAction.normalShot), isFalse);
      expect(InputAction.has(result, InputAction.smash), isFalse);
      expect(InputAction.has(result, InputAction.dropShot), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Rule 5 — shot priority
  // ---------------------------------------------------------------------------
  group('Rule 5: shot priority smash > dropShot > normalShot', () {
    test('smash + dropShot → smash wins', () {
      const mask = InputAction.smash | InputAction.dropShot;
      final result = _san(bitmask: mask);
      expect(InputAction.has(result, InputAction.smash), isTrue);
      expect(InputAction.has(result, InputAction.dropShot), isFalse);
      expect(InputAction.has(result, InputAction.normalShot), isFalse);
    });

    test('smash + normalShot → smash wins', () {
      const mask = InputAction.smash | InputAction.normalShot;
      final result = _san(bitmask: mask);
      expect(InputAction.has(result, InputAction.smash), isTrue);
      expect(InputAction.has(result, InputAction.normalShot), isFalse);
    });

    test('dropShot + normalShot → dropShot wins', () {
      const mask = InputAction.dropShot | InputAction.normalShot;
      final result = _san(bitmask: mask);
      expect(InputAction.has(result, InputAction.dropShot), isTrue);
      expect(InputAction.has(result, InputAction.normalShot), isFalse);
    });

    test('smash + dropShot + normalShot → smash wins', () {
      const mask =
          InputAction.smash | InputAction.dropShot | InputAction.normalShot;
      final result = _san(bitmask: mask);
      expect(InputAction.has(result, InputAction.smash), isTrue);
      expect(InputAction.has(result, InputAction.dropShot), isFalse);
      expect(InputAction.has(result, InputAction.normalShot), isFalse);
    });

    test('single shot bit is unchanged (no de-duplication needed)', () {
      expect(
        InputAction.has(
          _san(bitmask: InputAction.normalShot),
          InputAction.normalShot,
        ),
        isTrue,
      );
      expect(
        InputAction.has(_san(bitmask: InputAction.smash), InputAction.smash),
        isTrue,
      );
      expect(
        InputAction.has(
          _san(bitmask: InputAction.dropShot),
          InputAction.dropShot,
        ),
        isTrue,
      );
    });

    test('non-shot bits are preserved alongside the winning shot', () {
      const mask =
          InputAction.jump | InputAction.smash | InputAction.normalShot;
      final result = _san(bitmask: mask);
      expect(InputAction.has(result, InputAction.jump), isTrue);
      expect(InputAction.has(result, InputAction.smash), isTrue);
      expect(InputAction.has(result, InputAction.normalShot), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Clean pass-through
  // ---------------------------------------------------------------------------
  group('clean rally input: no changes applied', () {
    test('jump + moveRight in rally → unchanged', () {
      const mask = InputAction.jump | InputAction.moveRight;
      expect(_san(bitmask: mask), mask);
    });

    test('single smash in rally → unchanged', () {
      expect(_san(bitmask: InputAction.smash), InputAction.smash);
    });

    test('none → none', () {
      expect(_san(bitmask: InputAction.none), InputAction.none);
    });
  });

  // ---------------------------------------------------------------------------
  // Purity / determinism
  // ---------------------------------------------------------------------------
  group('sanitize is pure and deterministic', () {
    test('same inputs always produce the same output', () {
      const mask =
          InputAction.smash | InputAction.normalShot | InputAction.jump;
      final a = _san(bitmask: mask);
      final b = _san(bitmask: mask);
      expect(a, b);
    });
  });
}
