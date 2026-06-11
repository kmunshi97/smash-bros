import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/entities/player.dart';
import 'package:smash_bros/engine/input/input_action.dart';
import 'package:smash_bros/engine/math/fix.dart';
import 'package:smash_bros/engine/math/fix_vec2.dart';
import 'package:smash_bros/engine/rules/match_phase.dart';
import 'package:smash_bros/engine/sim/game_state.dart';
import 'package:smash_bros/engine/systems/shot_type.dart';

void main() {
  group('GameState construction', () {
    test('places players at their start x facing each other', () {
      final state = GameState(seed: 1);
      expect(state.frame, 0);
      expect(state.leftPlayer.x, const Fix.of(kPlayer1StartX));
      expect(state.leftPlayer.courtSide, CourtSide.left);
      expect(state.leftPlayer.facing, Facing.right);
      expect(state.rightPlayer.x, const Fix.of(kPlayer2StartX));
      expect(state.rightPlayer.courtSide, CourtSide.right);
      expect(state.rightPlayer.facing, Facing.left);
      expect(state.fsm.phase, MatchPhase.preMatch);
    });

    test('threads firstServer and targetScore into the FSM', () {
      final state = GameState(
        seed: 1,
        firstServer: CourtSide.right,
        targetScore: 21,
      );
      expect(state.fsm.server, CourtSide.right);
      expect(state.fsm.scoreboard.targetScore, 21);
    });
  });

  group('playerOn / inputsOn mapping', () {
    test('maps each side to its own player and buffer', () {
      final state = GameState(seed: 1);
      expect(state.playerOn(CourtSide.left), same(state.leftPlayer));
      expect(state.playerOn(CourtSide.right), same(state.rightPlayer));
      expect(state.inputsOn(CourtSide.left), same(state.leftInputs));
      expect(state.inputsOn(CourtSide.right), same(state.rightInputs));
    });
  });

  group('copy()', () {
    test('is deep and independent across every mutable member', () {
      final original = GameState(seed: 99)
        ..frame = 5
        ..leftInputs.set(0, InputAction.jump)
        ..rightInputs.set(0, InputAction.smash);
      // Touch the rng so the snapshot must capture its advanced state.
      original.random.nextUint32();

      // Mutate every member of the clone.
      original.copy()
        ..frame = 500
        ..leftPlayer.x = const Fix.of(999)
        ..rightPlayer.stamina = const Fix.of(1)
        ..shuttle.position = const FixVec2(Fix.of(123), Fix.of(456))
        ..rally.lastHitter = CourtSide.left
        ..rally.lastShotType = ShotType.smash
        ..fsm.startMatch(0)
        ..leftInputs.set(1, InputAction.moveRight)
        ..rightInputs.set(1, InputAction.moveLeft)
        ..random.nextUint32();

      // The original is untouched by any of those mutations.
      expect(original.frame, 5);
      expect(original.leftPlayer.x, const Fix.of(kPlayer1StartX));
      expect(original.rightPlayer.stamina, isNot(const Fix.of(1)));
      expect(original.shuttle.position, FixVec2.zero);
      expect(original.rally.lastHitter, isNull);
      expect(original.rally.lastShotType, isNull);
      expect(original.fsm.phase, MatchPhase.preMatch);
      expect(original.leftInputs.get(1), InputAction.none);
      expect(original.rightInputs.get(1), InputAction.none);
    });

    test('snapshots the rng so the copy reproduces the same sequence', () {
      final original = GameState(seed: 7);
      original.random.nextUint32();
      final clone = original.copy();
      expect(clone.random.nextUint32(), original.random.nextUint32());
    });
  });

  group('debugSignature', () {
    test('is identical for two freshly-seeded equal states', () {
      final a = GameState(seed: 1234);
      final b = GameState(seed: 1234);
      expect(a.debugSignature, b.debugSignature);
    });

    test('differs after any state change (moving a player)', () {
      final a = GameState(seed: 1234);
      final b = GameState(seed: 1234);
      b.leftPlayer.x = b.leftPlayer.x + Fix.one;
      expect(a.debugSignature, isNot(b.debugSignature));
    });

    test('differs for different seeds (rng lanes diverge)', () {
      final a = GameState(seed: 1);
      final b = GameState(seed: 2);
      expect(a.debugSignature, isNot(b.debugSignature));
    });

    test('a copy reports the same signature as its origin', () {
      final original = GameState(seed: 55)..frame = 3;
      expect(original.copy().debugSignature, original.debugSignature);
    });
  });
}
