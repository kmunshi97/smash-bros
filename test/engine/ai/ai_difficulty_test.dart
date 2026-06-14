// Engine-layer tests for the AiDifficulty enum: deterministic rolling and
// the tier → controller factory. Pure Dart — no Flutter/Flame imports.
import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/ai/ai.dart';
import 'package:smash_bros/engine/entities/court.dart';

void main() {
  group('AiDifficulty.roll', () {
    test('is deterministic: same seed always yields the same tier', () {
      for (var seed = 0; seed < 50; seed++) {
        expect(
          AiDifficulty.roll(seed),
          equals(AiDifficulty.roll(seed)),
          reason: 'roll($seed) must be reproducible',
        );
      }
    });

    test('covers all tiers across seeds', () {
      final seen = <AiDifficulty>{};
      for (
        var seed = 0;
        seed < 200 && seen.length < AiDifficulty.values.length;
        seed++
      ) {
        seen.add(AiDifficulty.roll(seed));
      }
      expect(
        seen,
        containsAll(AiDifficulty.values),
        reason: 'All tiers must be reachable from the roll',
      );
    });
  });

  group('AiDifficulty.build', () {
    test('builds the matching controller type for each tier', () {
      final easy = AiDifficulty.easy.build(side: CourtSide.right, seed: 1);
      final intermediate = AiDifficulty.intermediate.build(
        side: CourtSide.right,
        seed: 1,
      );
      final hard = AiDifficulty.hard.build(side: CourtSide.right, seed: 1);
      final challenging = AiDifficulty.challenging.build(
        side: CourtSide.right,
        seed: 1,
      );

      expect(easy, isA<BasicAI>());
      expect(intermediate, isA<IntermediateAI>());
      // IntermediateAI and ChallengingAI both extend HardAI, so check exact
      // types rather than the base.
      expect(hard, isA<HardAI>());
      expect(hard, isNot(isA<IntermediateAI>()));
      expect(hard, isNot(isA<ChallengingAI>()));
      expect(challenging, isA<ChallengingAI>());
    });

    test('built controllers report their own tier and side', () {
      for (final tier in AiDifficulty.values) {
        final ai = tier.build(side: CourtSide.left, seed: 7);
        expect(ai.side, CourtSide.left);
        expect(
          (ai as RuleBasedAi).difficulty,
          equals(tier),
          reason: '${ai.runtimeType} must report $tier',
        );
      }
    });
  });
}
