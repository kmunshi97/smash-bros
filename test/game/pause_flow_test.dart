// Tests the pause flow (M2-016): openPauseMenu freezes the engine and shows
// the overlay; closePauseMenu resumes; and the PauseMenu widget wires its
// buttons. Uses the flame_test harness + a widget pump.
import 'package:flame_test/flame_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/game/badminton_game.dart';
import 'package:smash_bros/game/ui/pause_menu.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<BadmintonGame> buildGame() =>
      initializeGame(() => BadmintonGame(seed: 7));

  group('BadmintonGame pause flow', () {
    test(
      'openPauseMenu pauses the engine and marks paused; close resumes',
      () async {
        // initializeGame returns a mounted, running game.
        final game = await buildGame();
        expect(game.isPausedByMenu, isFalse);

        game.openPauseMenu();
        expect(game.isPausedByMenu, isTrue);
        expect(game.paused, isTrue);
        expect(game.overlays.isActive(BadmintonGame.pauseOverlayId), isTrue);

        game.closePauseMenu();
        expect(game.isPausedByMenu, isFalse);
        expect(game.paused, isFalse);
        expect(game.overlays.isActive(BadmintonGame.pauseOverlayId), isFalse);
      },
    );

    test('openPauseMenu is idempotent', () async {
      final game = await buildGame();
      game
        ..openPauseMenu()
        ..openPauseMenu();
      expect(game.isPausedByMenu, isTrue);
      game
        ..closePauseMenu()
        // A redundant close is a no-op.
        ..closePauseMenu();
      expect(game.isPausedByMenu, isFalse);
    });
  });

  group('PauseMenu widget', () {
    testWidgets('shows PAUSED and fires Resume / Restart callbacks', (
      tester,
    ) async {
      var resumed = 0;
      var restarted = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: PauseMenu(
            onResume: () => resumed++,
            onRestart: () => restarted++,
          ),
        ),
      );
      expect(find.text('PAUSED'), findsOneWidget);

      await tester.tap(find.text('RESUME'));
      await tester.tap(find.text('RESTART'));
      expect(resumed, 1);
      expect(restarted, 1);
    });
  });
}
