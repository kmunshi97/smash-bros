// LocalControlState unit tests (M1-025, updated M1-034).
// Tests the level-vs-edge semantics documented in the class header.
import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/input/input_action.dart';
import 'package:smash_bros/game/input/local_control_state.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Helper
  // ---------------------------------------------------------------------------

  /// Returns true if [bitmask] has every bit in [expected] set.
  bool hasAll(int bitmask, int expected) => (bitmask & expected) == expected;

  // ---------------------------------------------------------------------------
  // Level-triggered (hold) semantics
  // ---------------------------------------------------------------------------

  group('LocalControlState — level-triggered holds', () {
    test('moveLeft set → every drain includes moveLeft bit', () {
      final c = LocalControlState()..moveLeft = true;
      for (var i = 0; i < 3; i++) {
        expect(
          InputAction.has(c.drainTick(), InputAction.moveLeft),
          isTrue,
          reason: 'drain $i: moveLeft bit must be set while hold is active',
        );
      }
    });

    test('moveRight set → every drain includes moveRight bit', () {
      final c = LocalControlState()..moveRight = true;
      for (var i = 0; i < 3; i++) {
        expect(
          InputAction.has(c.drainTick(), InputAction.moveRight),
          isTrue,
        );
      }
    });

    test('hold cleared → subsequent drains no longer include the bit', () {
      final c = LocalControlState()
        ..moveLeft = true
        ..drainTick() // drain while held
        ..moveLeft = false; // release
      final after = c.drainTick();
      expect(InputAction.has(after, InputAction.moveLeft), isFalse);
    });

    test('moveLeft held for 3 drains → bit present in all 3 drains', () {
      final c = LocalControlState()..moveLeft = true;
      final results = List.generate(3, (_) => c.drainTick());
      expect(
        results.every((b) => InputAction.has(b, InputAction.moveLeft)),
        isTrue,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Edge-triggered (one-shot) semantics
  // ---------------------------------------------------------------------------

  group('LocalControlState — edge-triggered one-shots', () {
    test('pressJump once → jump bit exactly once across 3 drains', () {
      final c = LocalControlState()..pressJump();
      final first = c.drainTick();
      final second = c.drainTick();
      final third = c.drainTick();

      expect(InputAction.has(first, InputAction.jump), isTrue);
      expect(InputAction.has(second, InputAction.jump), isFalse);
      expect(InputAction.has(third, InputAction.jump), isFalse);
    });

    test('press-release-press pattern yields jump bit exactly twice', () {
      final c = LocalControlState()..pressJump();
      final first = c.drainTick(); // consume
      final second = c.drainTick(); // no re-fire
      c.pressJump(); // second press
      final third = c.drainTick(); // re-fire
      final fourth = c.drainTick(); // gone again

      expect(InputAction.has(first, InputAction.jump), isTrue);
      expect(InputAction.has(second, InputAction.jump), isFalse);
      expect(InputAction.has(third, InputAction.jump), isTrue);
      expect(InputAction.has(fourth, InputAction.jump), isFalse);
    });

    test('pressSmash fires once and is cleared', () {
      final c = LocalControlState()..pressSmash();
      expect(InputAction.has(c.drainTick(), InputAction.smash), isTrue);
      expect(InputAction.has(c.drainTick(), InputAction.smash), isFalse);
    });

    test('pressDrop fires once and is cleared', () {
      final c = LocalControlState()..pressDrop();
      expect(InputAction.has(c.drainTick(), InputAction.dropShot), isTrue);
      expect(InputAction.has(c.drainTick(), InputAction.dropShot), isFalse);
    });

    test('pressNormal fires once and is cleared', () {
      final c = LocalControlState()..pressNormal();
      expect(InputAction.has(c.drainTick(), InputAction.normalShot), isTrue);
      expect(InputAction.has(c.drainTick(), InputAction.normalShot), isFalse);
    });

    // toss is now LEVEL-triggered (M1-034 hold-to-charge serve).
    // It lives in the level-hold group but is tested here to keep all
    // one-shot tests together and preserve the test's original intent.
    test('tossHeld is level-triggered: held over 3 drains → 3 toss bits', () {
      final c = LocalControlState()..tossHeld = true;
      for (var i = 0; i < 3; i++) {
        expect(
          InputAction.has(c.drainTick(), InputAction.toss),
          isTrue,
          reason: 'drain $i: toss bit must be set while tossHeld is true',
        );
      }
      c.tossHeld = false;
      expect(
        InputAction.has(c.drainTick(), InputAction.toss),
        isFalse,
        reason: 'toss bit must clear once tossHeld is set to false',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Combined bitmask correctness
  // ---------------------------------------------------------------------------

  group('LocalControlState — combined bits', () {
    test('hold + multiple one-shots OR into a single mask correctly', () {
      final c = LocalControlState()
        ..moveRight = true
        ..pressJump()
        ..pressSmash();

      final mask = c.drainTick();

      expect(hasAll(mask, InputAction.moveRight), isTrue);
      expect(hasAll(mask, InputAction.jump), isTrue);
      expect(hasAll(mask, InputAction.smash), isTrue);
      // moveLeft not set
      expect(InputAction.has(mask, InputAction.moveLeft), isFalse);
    });

    test('all one-shots cleared after first drain; hold bits survive', () {
      // toss is now level-triggered (M1-034) — set tossHeld and then clear it.
      final c = LocalControlState()
        ..moveLeft = true
        ..tossHeld =
            true // level-held
        ..pressJump()
        ..pressSmash()
        ..pressDrop()
        ..pressNormal()
        ..drainTick() // consume one-shots and emit toss (still held)
        ..tossHeld = false; // release toss hold

      final second = c.drainTick();
      // Only moveLeft remains (tossHeld was cleared before this drain).
      expect(InputAction.has(second, InputAction.moveLeft), isTrue);
      expect(InputAction.has(second, InputAction.jump), isFalse);
      expect(InputAction.has(second, InputAction.smash), isFalse);
      expect(InputAction.has(second, InputAction.dropShot), isFalse);
      expect(InputAction.has(second, InputAction.normalShot), isFalse);
      expect(InputAction.has(second, InputAction.toss), isFalse);
    });

    test('zero input produces InputAction.none', () {
      final c = LocalControlState();
      expect(c.drainTick(), InputAction.none);
    });
  });
}
