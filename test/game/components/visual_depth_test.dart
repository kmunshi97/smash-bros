// Visual depth, swing animation, and arc button tests (M1-035v).
//
// Covers Part A (frameEvents), Part C (swing animation), Part D (button arc).
// Render smoke extension lives in render_smoke_test.dart.
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/render/render_state.dart';
import 'package:smash_bros/game/badminton_game.dart';
import 'package:smash_bros/game/components/components.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<BadmintonGame> buildGame({int seed = 7}) =>
      initializeGame(() => BadmintonGame(seed: seed));

  // ---------------------------------------------------------------------------
  // Part A — frameEvents
  // ---------------------------------------------------------------------------

  group('BadmintonGame.frameEvents', () {
    test('frameEvents is empty before any ticks', () async {
      final game = await buildGame();
      // No update called yet — frameEvents should be empty.
      expect(game.frameEvents, isEmpty);
      game.onRemove();
    });

    test(
      'frameEvents is stable within a frame (identical object on two reads)',
      () async {
        final game = await buildGame();
        game.update(kTickDuration);
        final a = game.frameEvents;
        final b = game.frameEvents;
        expect(
          identical(a, b),
          isTrue,
          reason: 'frameEvents must return the same list object within a frame',
        );
        game.onRemove();
      },
    );

    test('takeEvents returns the same list as frameEvents', () async {
      final game = await buildGame();
      game.update(kTickDuration);
      // takeEvents and frameEvents must be the same object (both return _frameEvents).
      expect(
        identical(game.takeEvents(), game.frameEvents),
        isTrue,
        reason: 'takeEvents must be an alias for frameEvents (same list)',
      );
      game.onRemove();
    });

    test(
      'a tick that produces a SwingEvent exposes it in frameEvents',
      () async {
        final game = await buildGame();

        // Launch a serve to get a SwingEvent.
        // M1-034 pattern: hold toss → release.
        game.controls.tossHeld = true;
        game.update(kTickDuration); // tick: charge accumulates
        game.controls.tossHeld = false;
        game.update(kTickDuration); // tick: release → serve → SwingEvent

        final events = game.frameEvents;
        final hasSwing = events.whereType<SwingEvent>().isNotEmpty;
        // A toss always produces a SwingEvent on the tick it connects.
        // (If no swing this tick, advance more ticks until one arrives.)
        // We loop up to 10 more ticks to make the test robust to timing.
        if (!hasSwing) {
          for (var i = 0; i < 10 && !hasSwing; i++) {
            game.update(kTickDuration);
            if (game.frameEvents.whereType<SwingEvent>().isNotEmpty) break;
          }
        }

        // Verify current frameEvents has a SwingEvent.
        expect(
          game.frameEvents.whereType<SwingEvent>(),
          isNotEmpty,
          reason:
              'frameEvents must contain a SwingEvent on the frame when a toss '
              'connects',
        );
        game.onRemove();
      },
    );

    test(
      'SwingEvent is gone from frameEvents the next update when no new events',
      () async {
        final game = await buildGame();

        // Drive until we get a SwingEvent.
        game.controls.tossHeld = true;
        game.update(kTickDuration);
        game.controls.tossHeld = false;
        game.update(kTickDuration);

        // Find the first frame with a swing event.
        var foundSwing = game.frameEvents.whereType<SwingEvent>().isNotEmpty;
        var attempts = 0;
        while (!foundSwing && attempts < 20) {
          game.update(kTickDuration);
          foundSwing = game.frameEvents.whereType<SwingEvent>().isNotEmpty;
          attempts++;
        }
        expect(foundSwing, isTrue, reason: 'precondition: need a SwingEvent');

        // Now advance one more tick with no new swing action.
        // The driver may or may not fire a tick (depends on leftover accumulator).
        // We run a short update that is unlikely to fire a simulation tick but
        // will rebuild frameEvents. Use a sub-tick dt (e.g., 1/120 s).
        game.update(1 / 120);

        // After a frame with no new swing events the list should be empty
        // (or at most contain non-swing events — no SwingEvent should persist).
        expect(
          game.frameEvents.whereType<SwingEvent>(),
          isEmpty,
          reason:
              'SwingEvent must not persist into the next render frame when no '
              'new tick produced one',
        );
        game.onRemove();
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Part C — swing animation on PlayerComponent
  // ---------------------------------------------------------------------------

  group('PlayerComponent — swing animation', () {
    test('left player isSwinging is false at match start', () async {
      final game = await buildGame();
      final leftPlayer = game.world.children
          .whereType<PlayerComponent>()
          .firstWhere((p) => p.side == CourtSide.left);
      expect(leftPlayer.isSwinging, isFalse);
      game.onRemove();
    });

    test(
      'left PlayerComponent enters swinging state after a SwingEvent for left',
      () async {
        final game = await buildGame();
        final leftPlayer = game.world.children
            .whereType<PlayerComponent>()
            .firstWhere((p) => p.side == CourtSide.left);

        // Drive a serve to produce a SwingEvent for left.
        game.controls.tossHeld = true;
        game.update(kTickDuration);
        game.controls.tossHeld = false;
        game.update(kTickDuration);

        // Search for the frame when the SwingEvent arrives and the player
        // component enters swinging state.
        var swinging = leftPlayer.isSwinging;
        for (var i = 0; i < 15 && !swinging; i++) {
          game.update(kTickDuration);
          swinging = leftPlayer.isSwinging;
        }

        expect(
          swinging,
          isTrue,
          reason:
              'left PlayerComponent must enter isSwinging=true within a frame '
              'of the left SwingEvent',
        );
        game.onRemove();
      },
    );

    test(
      'swing animation ends after ~kSwingAnimationFrames render frames',
      () async {
        final game = await buildGame();
        final leftPlayer = game.world.children
            .whereType<PlayerComponent>()
            .firstWhere((p) => p.side == CourtSide.left);

        // Drive until the player starts swinging.
        game.controls.tossHeld = true;
        game.update(kTickDuration);
        game.controls.tossHeld = false;
        game.update(kTickDuration);

        var swinging = leftPlayer.isSwinging;
        for (var i = 0; i < 15 && !swinging; i++) {
          game.update(kTickDuration);
          swinging = leftPlayer.isSwinging;
        }
        expect(
          swinging,
          isTrue,
          reason: 'precondition: player must be swinging',
        );

        // Now pump enough render frames to complete the animation.
        // kSwingAnimationFrames = 12; add a few frames of margin.
        for (var i = 0; i < kSwingAnimationFrames + 3; i++) {
          game.update(kTickDuration);
        }

        expect(
          leftPlayer.isSwinging,
          isFalse,
          reason:
              'swing animation must end after ~$kSwingAnimationFrames render '
              'frames',
        );
        game.onRemove();
      },
    );

    test('right PlayerComponent does NOT swing on a left SwingEvent', () async {
      final game = await buildGame();
      final rightPlayer = game.world.children
          .whereType<PlayerComponent>()
          .firstWhere((p) => p.side == CourtSide.right);

      // Drive a left-side serve.
      game.controls.tossHeld = true;
      game.update(kTickDuration);
      game.controls.tossHeld = false;
      game.update(kTickDuration);

      for (var i = 0; i < 15; i++) {
        game.update(kTickDuration);
      }

      // Right player must NOT be swinging when only the left player served.
      expect(
        rightPlayer.isSwinging,
        isFalse,
        reason:
            'right PlayerComponent must not enter swinging state from a left '
            'SwingEvent',
      );
      game.onRemove();
    });
  });

  // ---------------------------------------------------------------------------
  // Part D — action button tray layout (M1-036)
  // ---------------------------------------------------------------------------

  group('ActionButtonsComponent — tray layout', () {
    test(
      'boot while serving: exactly one button (TOSS) after onLoad',
      () async {
        final game = await buildGame();
        final abc = game.camera.viewport.children
            .whereType<ActionButtonsComponent>()
            .first;
        // Boot state is servePending with the left (local) player serving, so
        // only the TOSS button is mounted (M1-036 serve-state visibility).
        expect(
          abc.children.length,
          1,
          reason:
              'ActionButtonsComponent must show only the TOSS button while the '
              'local player is serving',
        );
        game.onRemove();
      },
    );

    test(
      'rally: primary (JUMP&SMASH) button is innermost — closest to corner',
      () async {
        final game = await buildGame();

        // Advance past servePending by tossing, then pump updates so the
        // rally buttons mount (component sees the new view one frame late;
        // queued additions mount on the following lifecycle pass).
        game.controls.tossHeld = true;
        game.update(kTickDuration);
        game.controls.tossHeld = false;
        for (var i = 0; i < 3; i++) {
          game.update(kTickDuration);
        }

        final abc = game.camera.viewport.children
            .whereType<ActionButtonsComponent>()
            .first;
        expect(abc.children.length, 3, reason: 'rally state mounts 3 buttons');

        // Corner anchor in VIRTUAL coordinates (viewport children render in
        // the 1280×720 virtual space, not device coordinates).
        const cornerX = kCourtWidth;
        const cornerY = kCourtHeight;

        // Compute distance of each button's centre from the corner.
        double distFromCorner(PositionComponent btn) {
          // btn.position is the top-left of the button; size is diameter*2.
          final cx = btn.position.x + btn.size.x / 2;
          final cy = btn.position.y + btn.size.y / 2;
          final dx = cornerX - cx;
          final dy = cornerY - cy;
          return math.sqrt(dx * dx + dy * dy);
        }

        final buttons = abc.children.toList().cast<PositionComponent>()
          ..sort((a, b) => distFromCorner(a).compareTo(distFromCorner(b)));

        // The innermost (closest to corner) button must be the primary.
        // Its size is 2 * _kPrimaryRadius = 96; arc buttons are 80 or 72.
        // The primary has the largest size AND smallest corner distance.
        final innermost = buttons.first;
        expect(
          innermost.size.x,
          greaterThan(buttons.last.size.x - 1),
          reason:
              'primary button (size 96) must be innermost (closest to corner); '
              'its diameter should equal or exceed arc button diameters',
        );

        game.onRemove();
      },
    );

    test(
      'safe-area shift respected: buttons move with nonzero safe area',
      () async {
        final game = await buildGame();
        game.update(0);

        final abc = game.camera.viewport.children
            .whereType<ActionButtonsComponent>()
            .first;

        // Record positions with zero safe area.
        final buttons0 = abc.children
            .toList()
            .cast<PositionComponent>()
            .map((b) => b.position.clone())
            .toList();

        // Apply a right+bottom safe-area inset.
        abc.safeArea = const EdgeInsets.fromLTRB(0, 0, 40, 30);
        game.update(kTickDuration);

        final buttons1 = abc.children
            .toList()
            .cast<PositionComponent>()
            .map((b) => b.position.clone())
            .toList();

        // Every button should have shifted left/up by the safe-area amounts.
        for (var i = 0; i < buttons0.length; i++) {
          expect(
            buttons1[i].x,
            lessThan(buttons0[i].x),
            reason: 'button $i x must decrease with right safe-area inset',
          );
          expect(
            buttons1[i].y,
            lessThan(buttons0[i].y),
            reason: 'button $i y must decrease with bottom safe-area inset',
          );
        }

        game.onRemove();
      },
    );
  });
}
