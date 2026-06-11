import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/math/fix.dart';
import 'package:smash_bros/engine/random/game_random.dart';

void main() {
  group('GameRandom determinism (ADR-8)', () {
    test('same seed produces an identical sequence', () {
      final a = GameRandom(42);
      final b = GameRandom(42);
      for (var i = 0; i < 1000; i++) {
        expect(a.nextUint32(), b.nextUint32(), reason: 'diverged at draw $i');
      }
    });

    test('different seeds produce different sequences', () {
      final a = GameRandom(1);
      final b = GameRandom(2);
      final aDraws = List<int>.generate(10, (_) => a.nextUint32());
      final bDraws = List<int>.generate(10, (_) => b.nextUint32());
      expect(aDraws, isNot(bDraws));
    });

    test('seed zero is valid and well-mixed', () {
      final r = GameRandom(0);
      final draws = List<int>.generate(10, (_) => r.nextUint32());
      expect(draws.toSet().length, 10, reason: 'draws should not repeat');
      expect(draws.every((d) => d == 0), isFalse);
    });

    test('state round-trip resumes the exact sequence', () {
      final original = GameRandom(7);
      // Burn some draws so the state is mid-sequence.
      for (var i = 0; i < 100; i++) {
        original.nextUint32();
      }
      final restored = GameRandom.fromState(original.state);
      for (var i = 0; i < 100; i++) {
        expect(original.nextUint32(), restored.nextUint32());
      }
    });

    test('state getter returns a defensive copy', () {
      final r = GameRandom(7);
      expect(() => r.state[0] = 99, throwsUnsupportedError);
    });

    test('fromState validates lane count and all-zero state', () {
      expect(() => GameRandom.fromState([1, 2, 3]), throwsArgumentError);
      expect(() => GameRandom.fromState([0, 0, 0, 0]), throwsArgumentError);
    });
  });

  group('GameRandom distributions', () {
    test('nextUint32 stays within 32 bits', () {
      final r = GameRandom(123);
      for (var i = 0; i < 10000; i++) {
        final v = r.nextUint32();
        expect(v, inInclusiveRange(0, 0xFFFFFFFF));
      }
    });

    test('nextInt respects bounds and hits all values', () {
      final r = GameRandom(99);
      final seen = <int>{};
      for (var i = 0; i < 1000; i++) {
        final v = r.nextInt(10);
        expect(v, inInclusiveRange(0, 9));
        seen.add(v);
      }
      expect(seen, hasLength(10));
    });

    test('nextInt rejects non-positive bounds', () {
      final r = GameRandom(1);
      expect(() => r.nextInt(0), throwsArgumentError);
      expect(() => r.nextInt(-5), throwsArgumentError);
    });

    test('nextBool produces both values', () {
      final r = GameRandom(5);
      final draws = List<bool>.generate(100, (_) => r.nextBool());
      expect(draws, contains(true));
      expect(draws, contains(false));
    });

    test('nextFixRange stays within the half-open range', () {
      final r = GameRandom(2024);
      const min = Fix.of(-3);
      const max = Fix.of(7);
      for (var i = 0; i < 10000; i++) {
        final v = r.nextFixRange(min, max);
        expect(v >= min, isTrue);
        expect(v < max, isTrue);
      }
    });
  });
}
