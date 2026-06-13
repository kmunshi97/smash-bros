// Engine tests for the block-event pipeline (M2-030 foundation):
// BlockResult value semantics, Simulation.lastTickBlocks population, and the
// RenderState.capture mapping to BlockEvent.
//
// NOTE on perfect blocks: a perfectly-timed block swings 6–12 ticks BEFORE the
// shuttle is in reach, but ShotSystem.trySwing requires reach *now*, so a
// perfect block currently whiffs and is not recorded (a pre-existing M1 gap;
// see HapticsComponent.reactTo docs). These tests therefore exercise the
// reachable path: an imperfect block (shuttle in reach now → arrival 0 → too
// early → imperfect) which connects, records, and stuns the defender. The
// BlockResult.isPerfect mapping for perfect timing is covered as a unit.
import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/entities/player.dart';
import 'package:smash_bros/engine/input/input_action.dart';
import 'package:smash_bros/engine/math/fix.dart';
import 'package:smash_bros/engine/math/fix_vec2.dart';
import 'package:smash_bros/engine/render/render_state.dart';
import 'package:smash_bros/engine/rules/match_phase.dart';
import 'package:smash_bros/engine/sim/simulation.dart';
import 'package:smash_bros/engine/systems/shot_type.dart';
import 'package:smash_bros/engine/systems/stun_system.dart';

void main() {
  group('BlockResult', () {
    test('isPerfect reflects the timing verdict', () {
      const perfect = BlockResult(
        side: CourtSide.right,
        timing: BlockTiming.perfect,
      );
      const imperfect = BlockResult(
        side: CourtSide.right,
        timing: BlockTiming.imperfect,
      );
      expect(perfect.isPerfect, isTrue);
      expect(imperfect.isPerfect, isFalse);
      expect(perfect.side, CourtSide.right);
    });
  });

  group('Simulation.lastTickBlocks + capture → BlockEvent', () {
    /// Drives a serve to inPlay, then stages an incoming smash already inside
    /// the right defender's reach so the next right swing resolves as an
    /// (imperfect) block.
    Simulation stageImperfectBlock() {
      final sim = Simulation(seed: 7)..start();
      // Serve: left charges then releases → inPlay.
      sim.state.leftInputs.set(0, InputAction.toss);
      sim
        ..tick()
        ..tick();
      expect(sim.state.fsm.phase, MatchPhase.inPlay);

      // Stage: an incoming LEFT smash, shuttle sitting in the right defender's
      // reach box, defender placed and facing the net, lockout on the smasher
      // so the defender may swing.
      sim.state.rightPlayer
        ..x = const Fix.of(980)
        ..facing = Facing.left;
      sim.state.shuttle
        ..position = const FixVec2(Fix.of(980), Fix.of(500))
        ..velocity = const FixVec2(Fix.of(-2), Fix.of(4));
      sim.state.rally
        ..lastHitter = CourtSide.left
        ..hitLockout = CourtSide.left
        ..lastShotType = ShotType.smash;
      return sim;
    }

    test(
      'an imperfect block is recorded and maps to BlockEvent(perfect:false)',
      () {
        final sim = stageImperfectBlock();

        // Right defender swings at the in-reach incoming smash.
        sim.state.rightInputs.set(sim.state.frame, InputAction.normalShot);
        sim.tick();

        // (1) The block was recorded as imperfect on the right side.
        expect(sim.lastTickBlocks, hasLength(1));
        expect(sim.lastTickBlocks.single.side, CourtSide.right);
        expect(sim.lastTickBlocks.single.timing, BlockTiming.imperfect);
        expect(sim.lastTickBlocks.single.isPerfect, isFalse);

        // (2) The defender is stunned (imperfect-block consequence).
        expect(sim.state.rightPlayer.isStunned, isTrue);

        // (3) capture maps it to a BlockEvent(isPerfect: false) on the right.
        final snap = RenderState.capture(sim);
        final blocks = snap.events.whereType<BlockEvent>().toList();
        expect(blocks, hasLength(1));
        expect(blocks.single.side, CourtSide.right);
        expect(blocks.single.isPerfect, isFalse);
      },
    );

    test('lastTickBlocks clears on the next tick', () {
      final sim = stageImperfectBlock();
      sim.state.rightInputs.set(sim.state.frame, InputAction.normalShot);
      sim.tick();
      expect(sim.lastTickBlocks, isNotEmpty);

      // A plain tick with no swing clears the per-tick list.
      sim.state.rightInputs.set(sim.state.frame, InputAction.none);
      sim.tick();
      expect(sim.lastTickBlocks, isEmpty);
    });

    test('a non-block rally swing records no block', () {
      final sim = Simulation(seed: 7)..start();
      sim.state.leftInputs.set(0, InputAction.toss);
      sim
        ..tick()
        ..tick();
      // Stage a NORMAL incoming shot in reach (not a smash) → notApplicable.
      sim.state.rightPlayer
        ..x = const Fix.of(980)
        ..facing = Facing.left;
      sim.state.shuttle
        ..position = const FixVec2(Fix.of(980), Fix.of(500))
        ..velocity = const FixVec2(Fix.of(-2), Fix.of(4));
      sim.state.rally
        ..lastHitter = CourtSide.left
        ..hitLockout = CourtSide.left
        ..lastShotType = ShotType.normal;

      sim.state.rightInputs.set(sim.state.frame, InputAction.normalShot);
      sim.tick();

      expect(sim.lastTickBlocks, isEmpty);
      expect(
        RenderState.capture(sim).events.whereType<BlockEvent>(),
        isEmpty,
      );
    });
  });
}
