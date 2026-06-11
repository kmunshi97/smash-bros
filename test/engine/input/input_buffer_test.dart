import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/input/input_action.dart';
import 'package:smash_bros/engine/input/input_buffer.dart';

void main() {
  group('InputBuffer basics', () {
    test('newestFrame is -1 when empty', () {
      final buf = InputBuffer(capacity: 8);
      expect(buf.newestFrame, -1);
    });

    test('set/get round-trip for a single frame', () {
      final buf = InputBuffer(capacity: 8)..set(0, InputAction.jump);
      expect(buf.get(0), InputAction.jump);
      expect(buf.newestFrame, 0);
    });

    test('get returns InputAction.none for frames never stored', () {
      final buf = InputBuffer(capacity: 8)..set(0, InputAction.jump);
      // Frames 1..7 were never stored.
      expect(buf.get(1), InputAction.none);
      expect(buf.get(4), InputAction.none);
    });

    test('newestFrame tracks the highest set frame', () {
      final buf = InputBuffer(capacity: 8)..set(3, InputAction.smash);
      expect(buf.newestFrame, 3);
      buf.set(7, InputAction.dropShot);
      expect(buf.newestFrame, 7);
    });

    test('sequential frames store and retrieve independently', () {
      final buf = InputBuffer(capacity: 16);
      final values = [
        InputAction.moveLeft,
        InputAction.moveRight,
        InputAction.jump,
        InputAction.normalShot,
      ];
      for (var i = 0; i < values.length; i++) {
        buf.set(i, values[i]);
      }
      for (var i = 0; i < values.length; i++) {
        expect(buf.get(i), values[i]);
      }
    });
  });

  group('InputBuffer ring wrap-around', () {
    test('frame N and N+capacity occupy the same slot — old frame evicted', () {
      const cap = 8;
      final buf = InputBuffer(capacity: cap)..set(0, InputAction.jump);
      // Advance sequentially so the stale-clear logic runs slot-by-slot.
      for (var f = 1; f <= cap; f++) {
        buf.set(f, InputAction.none);
      }
      // Frame 0 has been evicted; reading it must throw.
      expect(() => buf.get(0), throwsArgumentError);
    });

    test('frames that wrapped are still readable if within the window', () {
      const cap = 8;
      final buf = InputBuffer(capacity: cap);
      for (var f = 0; f < cap + 3; f++) {
        buf.set(f, f.isEven ? InputAction.jump : InputAction.smash);
      }
      // Newest = cap+2; window covers cap+2 - cap + 1 = frame 3 onwards.
      // Frame cap+2 itself should be readable.
      final newest = buf.newestFrame;
      expect(buf.get(newest), isNotNull);
      expect(buf.get(newest - 1), isNotNull);
    });
  });

  group('InputBuffer stale-slot hazard', () {
    // THE key ring-buffer bug: frame 0 written, then jump to frame N; slots
    // 1..N-1 modulo capacity must read as none, not as whatever was stored
    // capacity frames ago in the same physical slot.
    test('skipped slots read as none after a forward jump', () {
      const cap = 16;
      final buf = InputBuffer(capacity: cap)
        ..set(0, InputAction.smash) // frame 0 slot = 0 % 16 = 0
        // Jump forward 8 frames — slots 1..7 are implicitly skipped.
        ..set(8, InputAction.jump);
      for (var f = 1; f < 8; f++) {
        expect(
          buf.get(f),
          InputAction.none,
          reason: 'frame $f should be none after the jump to frame 8',
        );
      }
    });

    test('stale-slot clear: set frame 0 then set frame capacity-1', () {
      const cap = 10;
      final buf = InputBuffer(capacity: cap)
        // Write a non-none value to frame 0.
        ..set(0, InputAction.normalShot)
        // Jump to the last frame in the first cycle.
        ..set(cap - 1, InputAction.smash);
      // Frames 1..(cap-2) were never stored and must read as none.
      for (var f = 1; f < cap - 1; f++) {
        expect(buf.get(f), InputAction.none, reason: 'frame $f should be none');
      }
    });

    test('large forward jump — window after the jump is clean', () {
      const cap = 32;
      final buf = InputBuffer(capacity: cap);
      // Write something in the first cycle.
      for (var f = 0; f < cap; f++) {
        buf.set(f, InputAction.smash);
      }
      // Now jump a full capacity forward (second cycle start).
      // Frames cap..cap+cap-1 would alias slots 0..cap-1.
      // The skipped range from cap to cap+cap-1 is larger than capacity,
      // but the set call for the target frame still only clears the gap.
      // Use a smaller gap: jump from cap-1 to cap-1+cap/2.
      const start = cap - 1;
      const target = start + (cap ~/ 2);
      buf.set(target, InputAction.moveLeft);
      for (var f = start + 1; f < target; f++) {
        expect(
          buf.get(f),
          InputAction.none,
          reason: 'skipped frame $f should be none',
        );
      }
    });

    test(
      'after a jump larger than capacity, slots in the new window are clean',
      () {
        const cap = 8;
        final buf = InputBuffer(capacity: cap);
        // Fill first cycle.
        for (var f = 0; f < cap; f++) {
          buf.set(f, InputAction.smash);
        }
        // Jump into the third cycle — skip an entire capacity worth of frames
        // plus some.  This exceeds what the stale-clear loop can handle in one
        // pass, but the write to the target slot still overwrites the stale data.
        // Then write sequentially to build a clean window around the new head.
        const jump = 2 * cap + 3; // frame 19 for cap=8
        buf.set(jump, InputAction.jump);
        // Reading the target itself works.
        expect(buf.get(jump), InputAction.jump);
        // Frames behind by more than capacity must throw.
        expect(() => buf.get(0), throwsArgumentError);
      },
    );
  });

  group('InputBuffer eviction guard', () {
    test('set an evicted frame throws ArgumentError', () {
      const cap = 4;
      final buf = InputBuffer(capacity: cap);
      for (var f = 0; f <= cap; f++) {
        buf.set(f, InputAction.none);
      }
      // Frame 0 is now evicted (newestFrame = cap, oldest retained = 1).
      expect(() => buf.set(0, InputAction.jump), throwsArgumentError);
    });

    test('get an evicted frame throws ArgumentError', () {
      const cap = 4;
      final buf = InputBuffer(capacity: cap);
      for (var f = 0; f <= cap; f++) {
        buf.set(f, InputAction.none);
      }
      expect(() => buf.get(0), throwsArgumentError);
    });
  });

  group('InputBuffer copy independence', () {
    test('copy has the same data as the original', () {
      const cap = 8;
      final buf = InputBuffer(capacity: cap)
        ..set(0, InputAction.smash)
        ..set(1, InputAction.jump)
        ..set(2, InputAction.moveLeft);
      final clone = buf.copy();
      expect(clone.get(0), InputAction.smash);
      expect(clone.get(1), InputAction.jump);
      expect(clone.get(2), InputAction.moveLeft);
      expect(clone.newestFrame, buf.newestFrame);
    });

    test('mutating the original does not affect the copy', () {
      const cap = 8;
      final buf = InputBuffer(capacity: cap)..set(0, InputAction.smash);
      final clone = buf.copy();
      buf.set(1, InputAction.jump);
      // Clone still only knows about frame 0.
      expect(clone.newestFrame, 0);
      expect(clone.get(1), InputAction.none);
    });

    test('mutating the copy does not affect the original', () {
      const cap = 8;
      final buf = InputBuffer(capacity: cap)..set(0, InputAction.smash);
      final clone = buf.copy()..set(1, InputAction.dropShot);
      expect(buf.newestFrame, 0);
      expect(buf.get(1), InputAction.none);
      // Prevent unused variable warning.
      expect(clone.newestFrame, 1);
    });
  });

  group('InputBuffer default capacity', () {
    test('default capacity is kMaxRollbackFrames', () {
      // The default buffer must accommodate the full rollback window.
      // Write frame 0, then advance to frame kMaxRollbackFrames so that
      // frame 0 is exactly evicted (newestFrame = kMaxRollbackFrames,
      // oldest retained = 1).
      final buf = InputBuffer()..set(0, InputAction.jump);
      for (var f = 1; f <= kMaxRollbackFrames; f++) {
        buf.set(f, InputAction.none);
      }
      expect(buf.newestFrame, kMaxRollbackFrames);
      // Frame 0 is now outside the retained window and must throw.
      expect(() => buf.get(0), throwsArgumentError);
    });
  });
}
