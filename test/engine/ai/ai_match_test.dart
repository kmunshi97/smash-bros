// AI-vs-AI integration test (M1-029 playability proof).
// Runs a full match between two BasicAIs and validates:
//   1. Match completes (no stalemate).
//   2. Winner's score satisfies the scoreboard win condition.
//   3. At least 10 non-serve swings across the match (real rallies occurred).
//   4. End-to-end determinism: same seeds → identical final GameState.debugSignature.
import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/ai/basic_ai.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/rules/match_phase.dart';
import 'package:smash_bros/engine/sim/simulation.dart';
import 'package:smash_bros/engine/systems/shot_system.dart';

/// Drives a full AI-vs-AI match to completion.
///
/// Returns a record of:
/// * `finalSig` — the `GameState.debugSignature` after `MatchPhase.matchOver`.
/// * `nonServeSwings` — count of non-toss swings across the match.
/// * `leftScore` / `rightScore` — final scores.
({
  String finalSig,
  int nonServeSwings,
  int leftScore,
  int rightScore,
  int totalTicks,
})
_runMatch(int matchSeed, int leftAiSeed, int rightAiSeed) {
  const maxTicks = 200000;

  final sim = Simulation(
    seed: matchSeed,
  )..start();
  final leftAi = BasicAI(side: CourtSide.left, seed: leftAiSeed);
  final rightAi = BasicAI(side: CourtSide.right, seed: rightAiSeed);

  var nonServeSwings = 0;
  var totalTicks = 0;

  while (sim.state.fsm.phase != MatchPhase.matchOver && totalTicks < maxTicks) {
    final f = sim.state.frame;
    sim.state.leftInputs.set(f, leftAi.decide(sim.state));
    sim.state.rightInputs.set(f, rightAi.decide(sim.state));
    sim.tick();
    totalTicks++;

    // Count non-serve connected swings this tick.
    for (final sw in sim.lastTickSwings) {
      if (sw.shotType != ShotType.toss) {
        nonServeSwings++;
      }
    }
  }

  if (sim.state.fsm.phase != MatchPhase.matchOver) {
    fail(
      'Match did not complete within $maxTicks ticks — stalemate detected. '
      'Score: ${sim.state.fsm.scoreboard.leftScore}-'
      '${sim.state.fsm.scoreboard.rightScore}. '
      'Consider tuning BasicAI constants (_kServeTossDelay, _kMovementDeadZone).',
    );
  }

  return (
    finalSig: sim.state.debugSignature,
    nonServeSwings: nonServeSwings,
    leftScore: sim.state.fsm.scoreboard.leftScore,
    rightScore: sim.state.fsm.scoreboard.rightScore,
    totalTicks: totalTicks,
  );
}

void main() {
  const matchSeed = 0xC0FFEE;
  const leftSeed = 0xABCD;
  const rightSeed = 0x1234;

  test('AI-vs-AI: match completes, winner satisfies scoreboard, '
      'at least 10 non-serve swings (real rallies)', () {
    final result = _runMatch(matchSeed, leftSeed, rightSeed);

    // (1) Match completed (if it didn't, _runMatch fails loudly above).
    // (2) Exactly one player reached the win condition.
    final leftWon = result.leftScore > result.rightScore;
    final winnerScore = leftWon ? result.leftScore : result.rightScore;
    final loserScore = leftWon ? result.rightScore : result.leftScore;

    expect(
      winnerScore,
      greaterThanOrEqualTo(11),
      reason: 'Winner must reach the target score',
    );
    expect(
      winnerScore - loserScore,
      greaterThanOrEqualTo(2),
      reason: 'Winner must lead by ≥2 (standard rules or deuce win)',
    );

    // (3) Real rallies: at least 10 non-serve swings.
    expect(
      result.nonServeSwings,
      greaterThanOrEqualTo(10),
      reason:
          'Expect ≥10 rally swings; got ${result.nonServeSwings} — '
          'AI may be stuck only serving',
    );

    // Print match stats for the orchestrator.
    // ignore: avoid_print
    print(
      'AI-vs-AI stats: '
      '${result.leftScore}-${result.rightScore} '
      'in ${result.totalTicks} ticks, '
      '${result.nonServeSwings} rally swings',
    );
  });

  test('AI-vs-AI: end-to-end determinism — '
      'same seeds produce identical final signature', () {
    final r1 = _runMatch(matchSeed, leftSeed, rightSeed);
    final r2 = _runMatch(matchSeed, leftSeed, rightSeed);

    expect(
      r1.finalSig,
      equals(r2.finalSig),
      reason: 'Same seeds must produce bit-identical final GameState',
    );
    expect(r1.leftScore, equals(r2.leftScore));
    expect(r1.rightScore, equals(r2.rightScore));
    expect(r1.totalTicks, equals(r2.totalTicks));
  });
}
