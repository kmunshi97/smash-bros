// Engine-layer tests for the HardAI and ChallengingAI tiers (M2-022/M2-023
// pulled forward): match completion, determinism, the jump-iff-smash
// invariant, and the skill ordering easy < hard/challenging.
import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/ai/ai.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/input/input_action.dart';
import 'package:smash_bros/engine/math/fix.dart';
import 'package:smash_bros/engine/math/fix_vec2.dart';
import 'package:smash_bros/engine/rules/match_phase.dart';
import 'package:smash_bros/engine/sim/simulation.dart';

/// Drives a full AI-vs-AI match to completion and returns the result.
({String finalSig, int leftScore, int rightScore}) _runMatch({
  required int matchSeed,
  required AIController leftAi,
  required AIController rightAi,
  int targetScore = 5,
}) {
  const maxTicks = 200000;
  final sim = Simulation(seed: matchSeed, targetScore: targetScore)..start();

  var ticks = 0;
  while (sim.state.fsm.phase != MatchPhase.matchOver && ticks < maxTicks) {
    final f = sim.state.frame;
    sim.state.leftInputs.set(f, leftAi.decide(sim.state));
    sim.state.rightInputs.set(f, rightAi.decide(sim.state));
    sim.tick();
    ticks++;
  }

  if (sim.state.fsm.phase != MatchPhase.matchOver) {
    fail(
      'Match did not complete within $maxTicks ticks '
      '(${leftAi.runtimeType} vs ${rightAi.runtimeType}, seed $matchSeed). '
      'Score: ${sim.state.fsm.scoreboard.leftScore}-'
      '${sim.state.fsm.scoreboard.rightScore}.',
    );
  }

  return (
    finalSig: sim.state.debugSignature,
    leftScore: sim.state.fsm.scoreboard.leftScore,
    rightScore: sim.state.fsm.scoreboard.rightScore,
  );
}

void main() {
  group('HardAI / ChallengingAI — match completion and determinism', () {
    for (final tier in [AiDifficulty.hard, AiDifficulty.challenging]) {
      test('$tier vs $tier completes and is deterministic', () {
        ({String finalSig, int leftScore, int rightScore}) run() => _runMatch(
          matchSeed: 0xBADC0DE,
          leftAi: tier.build(side: CourtSide.left, seed: 31),
          rightAi: tier.build(side: CourtSide.right, seed: 32),
        );

        final r1 = run();
        final r2 = run();

        // One side won by the scoreboard rules.
        final winner = r1.leftScore > r1.rightScore
            ? r1.leftScore
            : r1.rightScore;
        expect(winner, greaterThanOrEqualTo(5));

        // Same seeds → bit-identical final state.
        expect(r1.finalSig, equals(r2.finalSig));
        expect(r1.leftScore, equals(r2.leftScore));
        expect(r1.rightScore, equals(r2.rightScore));
      });
    }
  });

  group('HardAI / ChallengingAI — jump-smash pairing (M1-036)', () {
    for (final tier in [AiDifficulty.hard, AiDifficulty.challenging]) {
      test('$tier emits jump if and only if it emits smash', () {
        final sim = Simulation(seed: 77, targetScore: 5)..start();
        final leftAi = tier.build(side: CourtSide.left, seed: 1);
        final rightAi = tier.build(side: CourtSide.right, seed: 2);

        var smashesSeen = 0;
        for (
          var i = 0;
          i < 5000 && sim.state.fsm.phase != MatchPhase.matchOver;
          i++
        ) {
          final f = sim.state.frame;
          final leftBit = leftAi.decide(sim.state);
          final rightBit = rightAi.decide(sim.state);
          sim.state.leftInputs.set(f, leftBit);
          sim.state.rightInputs.set(f, rightBit);
          sim.tick();

          for (final bits in [leftBit, rightBit]) {
            final hasJump = InputAction.has(bits, InputAction.jump);
            final hasSmash = InputAction.has(bits, InputAction.smash);
            if (hasSmash) smashesSeen++;
            expect(
              hasJump,
              hasSmash,
              reason:
                  '$tier must emit jump exactly when it emits smash; '
                  'got bits=$bits at frame $f',
            );
          }
        }

        expect(
          smashesSeen,
          greaterThan(0),
          reason: 'expected at least one smash over the sampled frames',
        );
      });
    }
  });

  group('HardAI — positioning fallbacks', () {
    test('returns none in matchOver and other non-play phases', () {
      // Drive a match to completion, then ask the AI to decide once more in
      // the matchOver phase — it must emit nothing (exercises the non-play
      // switch arm).
      final sim = Simulation(seed: 5, targetScore: 5)..start();
      final leftAi = AiDifficulty.easy.build(side: CourtSide.left, seed: 1);
      final rightAi = AiDifficulty.hard.build(side: CourtSide.right, seed: 2);

      var ticks = 0;
      while (sim.state.fsm.phase != MatchPhase.matchOver && ticks < 200000) {
        final f = sim.state.frame;
        sim.state.leftInputs.set(f, leftAi.decide(sim.state));
        sim.state.rightInputs.set(f, rightAi.decide(sim.state));
        sim.tick();
        ticks++;
      }
      expect(sim.state.fsm.phase, MatchPhase.matchOver);
      expect(rightAi.decide(sim.state), InputAction.none);
      expect(leftAi.decide(sim.state), InputAction.none);
    });

    test('predictedInterceptX falls back to the shuttle x when the '
        'lookahead finds no descent', () {
      // A shuttle launched steeply upward will not descend to the intercept
      // height within the predictor horizon → the AI tracks its current x.
      final sim = Simulation(seed: 9)..start();
      final hard = HardAI(side: CourtSide.right, seed: 3);

      // Park the shuttle high on the right side, rising fast.
      sim.state.shuttle
        ..position = const FixVec2(Fix.of(900), Fix.of(500))
        ..velocity = const FixVec2(Fix.of(0), Fix.of(-15));

      final target = hard.predictedInterceptX(sim.state);
      // The clamp keeps it on the right half; the fallback used the shuttle's
      // own x (900), which is already inside the right half.
      expect(target, closeTo(900, 1));
    });
  });

  group('Skill ordering — harder tiers beat the easy tier', () {
    /// Plays [n] seeded matches of [tier] (right side) vs easy (left side)
    /// and returns how many the harder tier won.
    int winsVsEasy(AiDifficulty tier, int n) {
      var wins = 0;
      for (var i = 0; i < n; i++) {
        final result = _runMatch(
          matchSeed: 1000 + i * 17,
          leftAi: AiDifficulty.easy.build(side: CourtSide.left, seed: 50 + i),
          rightAi: tier.build(side: CourtSide.right, seed: 70 + i),
        );
        if (result.rightScore > result.leftScore) wins++;
      }
      return wins;
    }

    test('hard wins the majority of 5 matches against easy', () {
      final wins = winsVsEasy(AiDifficulty.hard, 5);
      expect(
        wins,
        greaterThanOrEqualTo(3),
        reason:
            'HardAI should beat BasicAI in most matches '
            '(won $wins/5) — prediction + faster reaction must show',
      );
    });

    test('challenging wins the majority of 5 matches against easy', () {
      final wins = winsVsEasy(AiDifficulty.challenging, 5);
      expect(
        wins,
        greaterThanOrEqualTo(3),
        reason:
            'ChallengingAI should beat BasicAI in most matches '
            '(won $wins/5)',
      );
    });
  });
}
