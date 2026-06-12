// BadmintonGame input-wiring tests (M1-025).
// Tests: movement wiring, serve toss, keyboard mapping.
import 'package:flame_test/flame_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/render/render_state.dart';
import 'package:smash_bros/engine/rules/match_phase.dart';
import 'package:smash_bros/game/badminton_game.dart';
import 'package:smash_bros/game/input/local_control_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<BadmintonGame> buildGame({int seed = 7}) =>
      initializeGame(() => BadmintonGame(seed: seed));

  // ---------------------------------------------------------------------------
  // Movement wiring
  // ---------------------------------------------------------------------------

  group('BadmintonGame input wiring — movement', () {
    test(
      'moveRight=true causes left player x to increase after ticks',
      () async {
        final game = await buildGame();
        final xBefore = game.view.leftPlayer.x;

        game.controls.moveRight = true;
        // Advance enough updates to fire several simulation ticks.
        // kTickDuration * 5 guarantees at least 5 ticks.
        game.update(kTickDuration * 5);

        final xAfter = game.view.leftPlayer.x;
        expect(
          xAfter,
          greaterThan(xBefore),
          reason:
              'holding moveRight must advance left player position rightward',
        );
        game.onRemove();
      },
    );

    test(
      'moveLeft=true causes left player x to decrease after ticks',
      () async {
        final game = await buildGame();
        // Give player some room to move left from starting position.
        final xBefore = game.view.leftPlayer.x;

        game.controls.moveLeft = true;
        game.update(kTickDuration * 5);

        final xAfter = game.view.leftPlayer.x;
        expect(
          xAfter,
          lessThan(xBefore),
          reason: 'holding moveLeft must move left player leftward',
        );
        game.onRemove();
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Serve toss wiring
  // ---------------------------------------------------------------------------

  group('BadmintonGame input wiring — serve toss', () {
    test('hold-to-charge toss during servePending with left server '
        '→ phase leaves servePending or SwingEvent fires', () async {
      final game = await buildGame();

      // Verify initial conditions.
      expect(game.view.phase, MatchPhase.servePending);
      expect(game.view.server, CourtSide.left);

      // M1-034: toss is level-triggered. Hold for one tick to build charge,
      // then release (tossHeld = false) and tick again to launch.
      game.controls.tossHeld = true;
      game.update(kTickDuration); // tick 1: charge accumulates
      game.controls.tossHeld = false;
      game.update(kTickDuration); // tick 2: release → serve launches

      // After a successful toss the phase moves to inPlay (or possibly
      // pointScored if the shuttle immediately lands out, but not servePending).
      final events = game.takeEvents();
      final phaseAfter = game.view.phase;

      final tossConnected =
          phaseAfter != MatchPhase.servePending ||
          events.whereType<SwingEvent>().isNotEmpty;

      expect(
        tossConnected,
        isTrue,
        reason:
            'hold-toss during servePending (left server) must either '
            'leave servePending or produce a SwingEvent',
      );
      game.onRemove();
    });
  });

  // ---------------------------------------------------------------------------
  // Keyboard mapping (via handleKeyChange — pure testable method)
  // ---------------------------------------------------------------------------

  group('BadmintonGame keyboard — handleKeyChange mapping', () {
    test('arrowLeft sets moveLeft; KeyUp clears it', () async {
      final game = await buildGame();

      game.handleKeyChange(LogicalKeyboardKey.arrowLeft, isDown: true);
      expect(game.controls.moveLeft, isTrue);

      game.handleKeyChange(LogicalKeyboardKey.arrowLeft, isDown: false);
      expect(game.controls.moveLeft, isFalse);
      game.onRemove();
    });

    test('keyA sets moveLeft; KeyUp clears it', () async {
      final game = await buildGame();

      game.handleKeyChange(LogicalKeyboardKey.keyA, isDown: true);
      expect(game.controls.moveLeft, isTrue);

      game.handleKeyChange(LogicalKeyboardKey.keyA, isDown: false);
      expect(game.controls.moveLeft, isFalse);
      game.onRemove();
    });

    test('arrowRight sets moveRight; KeyUp clears it', () async {
      final game = await buildGame();

      game.handleKeyChange(LogicalKeyboardKey.arrowRight, isDown: true);
      expect(game.controls.moveRight, isTrue);

      game.handleKeyChange(LogicalKeyboardKey.arrowRight, isDown: false);
      expect(game.controls.moveRight, isFalse);
      game.onRemove();
    });

    test('keyD sets moveRight; KeyUp clears it', () async {
      final game = await buildGame();

      game.handleKeyChange(LogicalKeyboardKey.keyD, isDown: true);
      expect(game.controls.moveRight, isTrue);

      game.handleKeyChange(LogicalKeyboardKey.keyD, isDown: false);
      expect(game.controls.moveRight, isFalse);
      game.onRemove();
    });

    test('Space (isDown) schedules jump; drain produces jump bit', () async {
      final game = await buildGame();

      game.handleKeyChange(LogicalKeyboardKey.space, isDown: true);
      final mask = game.controls.drainTick();
      expect(
        (mask & 0x4) != 0, // InputAction.jump = 1<<2
        isTrue,
        reason: 'Space down must schedule a jump one-shot',
      );
      game.onRemove();
    });

    test('J (isDown) starts the jump-smash combo (M1-036)', () async {
      final game = await buildGame();
      // The player starts grounded, so J = jump now + smash at the apex —
      // identical semantics to the touch JUMP&SMASH button.
      game.handleKeyChange(LogicalKeyboardKey.keyJ, isDown: true);
      final mask = game.controls.drainTick();
      expect((mask & 0x04) != 0, isTrue); // InputAction.jump = 1<<2
      expect((mask & 0x10) != 0, isFalse); // smash NOT immediate when grounded

      // Smash fires exactly kJumpSmashApexDelayTicks drains later.
      for (var i = 1; i < kJumpSmashApexDelayTicks; i++) {
        expect((game.controls.drainTick() & 0x10) != 0, isFalse);
      }
      expect(
        (game.controls.drainTick() & 0x10) != 0,
        isTrue, // InputAction.smash = 1<<4 at the apex drain
      );
      game.onRemove();
    });

    test('K (isDown) schedules drop', () async {
      final game = await buildGame();
      game.handleKeyChange(LogicalKeyboardKey.keyK, isDown: true);
      final mask = game.controls.drainTick();
      expect((mask & 0x20) != 0, isTrue); // InputAction.dropShot = 1<<5
      game.onRemove();
    });

    test('L (isDown) schedules normal shot', () async {
      final game = await buildGame();
      game.handleKeyChange(LogicalKeyboardKey.keyL, isDown: true);
      final mask = game.controls.drainTick();
      expect((mask & 0x08) != 0, isTrue); // InputAction.normalShot = 1<<3
      game.onRemove();
    });

    test('T (isDown) schedules toss', () async {
      final game = await buildGame();
      game.handleKeyChange(LogicalKeyboardKey.keyT, isDown: true);
      final mask = game.controls.drainTick();
      expect((mask & 0x40) != 0, isTrue); // InputAction.toss = 1<<6
      game.onRemove();
    });

    test('unrecognised key returns false', () async {
      final game = await buildGame();
      final consumed = game.handleKeyChange(
        LogicalKeyboardKey.keyZ,
        isDown: true,
      );
      expect(consumed, isFalse);
      game.onRemove();
    });

    test('recognised keys return true', () async {
      final game = await buildGame();
      for (final key in [
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.keyA,
        LogicalKeyboardKey.keyD,
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.keyJ,
        LogicalKeyboardKey.keyK,
        LogicalKeyboardKey.keyL,
        LogicalKeyboardKey.keyT,
      ]) {
        expect(
          game.handleKeyChange(key, isDown: true),
          isTrue,
          reason: '$key should be consumed',
        );
      }
      game.onRemove();
    });
  });
}
