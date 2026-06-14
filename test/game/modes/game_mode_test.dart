// Tests the GameMode configs (M2-019..021) and a Point Rush integration run
// that actually ends by the clock.
import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/ai/ai.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/rules/match_phase.dart';
import 'package:smash_bros/engine/sim/simulation.dart';
import 'package:smash_bros/game/modes/modes.dart';

void main() {
  group('ClassicMode', () {
    test('is untimed and ends by score', () {
      const m = ClassicMode();
      expect(m.timeLimitTicks, isNull);
      expect(m.isTimed, isFalse);
      expect(m.targetScore, kDefaultTargetScore);
      expect(m.displayName, 'Classic');
      expect(m.id, 'classic_$kDefaultTargetScore');
    });

    test('supports alternate target scores', () {
      expect(const ClassicMode(targetScore: 5).targetScore, 5);
      expect(const ClassicMode(targetScore: 21).id, 'classic_21');
    });
  });

  group('PointRushMode', () {
    test('is timed with an unreachable score target', () {
      const m = PointRushMode();
      expect(m.isTimed, isTrue);
      expect(m.timeLimitTicks, 90 * kTickRate);
      expect(m.targetScore, greaterThan(1000));
      expect(m.displayName, 'Point Rush');
      expect(m.description, contains('90'));
    });

    test('duration is configurable', () {
      expect(const PointRushMode(durationSeconds: 60).timeLimitTicks, 60 * 60);
    });
  });

  group('Point Rush integration', () {
    test('a timed match ends by the clock with the leader winning', () {
      // A short 8-second match so the test is quick.
      const seconds = 8;
      final sim = Simulation(
        seed: 0xC0FFEE,
        timeLimitTicks: seconds * kTickRate,
        targetScore: const PointRushMode().targetScore, // unreachable
      )..start();
      final leftAi = BasicAI(side: CourtSide.left, seed: 1);
      final rightAi = BasicAI(side: CourtSide.right, seed: 2);

      var ticks = 0;
      const maxTicks = 200000;
      while (sim.state.fsm.phase != MatchPhase.matchOver && ticks < maxTicks) {
        final f = sim.state.frame;
        sim.state.leftInputs.set(f, leftAi.decide(sim.state));
        sim.state.rightInputs.set(f, rightAi.decide(sim.state));
        sim.tick();
        ticks++;
      }

      expect(
        sim.state.fsm.phase,
        MatchPhase.matchOver,
        reason: 'Point Rush must end by the clock',
      );
      // It ended at/after the limit (the clock drove it, not a target score).
      expect(
        sim.state.fsm.matchClockTicks,
        greaterThanOrEqualTo(seconds * kTickRate),
      );
      // The winner is the side ahead (or it was a golden-point decider).
      final l = sim.state.fsm.scoreboard.leftScore;
      final r = sim.state.fsm.scoreboard.rightScore;
      expect(l == r, isFalse, reason: 'match must not end tied');
    });
  });
}
