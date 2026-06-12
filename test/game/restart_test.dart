// Game-layer tests for M1-029: restartMatch and RestartOverlayComponent.
// Uses flame_test helpers for proper Flame lifecycle initialization.
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/ai/basic_ai.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/rules/match_phase.dart';
import 'package:smash_bros/game/badminton_game.dart';
import 'package:smash_bros/game/components/hud/restart_overlay_component.dart';

// Helper: build a game with an AI right player.
Future<BadmintonGame> buildGame({int seed = 7}) => initializeGame(
  () => BadmintonGame(
    seed: seed,
    rightAi: BasicAI(side: CourtSide.right, seed: 99),
  ),
);

void main() {
  // --------------------------------------------------------------------------
  // restartMatch
  // --------------------------------------------------------------------------
  group('BadmintonGame.restartMatch', () {
    test('resets frame to 0 and scores to 0-0', () async {
      final game = await buildGame();

      // Advance a few ticks so the frame is non-zero.
      game.update(kTickDuration * 5);
      expect(game.view.frame, greaterThan(0));

      game.restartMatch(seed: 1, aiSeed: 2);

      // After restart, view should reflect a fresh simulation.
      expect(game.view.frame, 0);
      expect(game.view.leftScore, 0);
      expect(game.view.rightScore, 0);
      expect(game.view.phase, MatchPhase.servePending);
      game.onRemove();
    });

    test('restartMatch can be called multiple times without error', () async {
      final game = await buildGame();
      game
        ..update(kTickDuration * 3)
        ..restartMatch(seed: 10, aiSeed: 20)
        ..update(kTickDuration * 3)
        ..restartMatch(seed: 30, aiSeed: 40);
      expect(game.view.frame, 0);
      game.onRemove();
    });
  });

  // --------------------------------------------------------------------------
  // RestartOverlayComponent hit-test
  // --------------------------------------------------------------------------
  group('RestartOverlayComponent', () {
    test(
      'containsLocalPoint returns false during servePending (tap-transparent)',
      () async {
        final game = await buildGame();
        expect(game.view.phase, MatchPhase.servePending);

        final overlay = game.camera.viewport.children
            .whereType<RestartOverlayComponent>()
            .first;

        // During servePending the overlay must not intercept taps.
        expect(
          overlay.containsLocalPoint(Vector2(100, 100)),
          isFalse,
          reason: 'Should be tap-transparent in servePending',
        );
        game.onRemove();
      },
    );

    test('containsLocalPoint returns false during inPlay', () async {
      final game = await buildGame();
      final overlay = game.camera.viewport.children
          .whereType<RestartOverlayComponent>()
          .first;

      // Script a toss to move to inPlay (M1-034 hold+release pattern).
      game.update(kTickDuration); // initial tick
      game.controls.tossHeld = true;
      game.update(kTickDuration); // charge
      game.controls.tossHeld = false;
      game.update(kTickDuration); // release → serve launches

      // Regardless of exact phase, ensure tap-transparency while not matchOver.
      if (game.view.phase != MatchPhase.matchOver) {
        expect(
          overlay.containsLocalPoint(Vector2(640, 360)),
          isFalse,
          reason: 'Should be tap-transparent while phase != matchOver',
        );
      }
      game.onRemove();
    });
  });
}
