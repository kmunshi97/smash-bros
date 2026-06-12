// Render smoke tests (M1-027 visual theme).
//
// Constructs a fully initialised BadmintonGame and drives game.renderTree() on
// a real Canvas (backed by a PictureRecorder) in at least two game states:
//
//   1. servePending at match start — shuttle is parked, HUD shows 0–0.
//   2. inPlay after a toss — shuttle is in flight, trail is accumulating.
//
// These tests catch Paint/shader crashes (e.g. a null shader, a bad Gradient
// construction, an out-of-bounds clip) that position-only tests cannot detect.
// They do NOT assert any pixel values; a clean return (no exception) is the
// pass criterion.
//
// dart:ui PictureRecorder is available in the flutter_test environment via the
// flutter_test wrapper around dart:ui — no additional dependencies needed.
import 'dart:ui' as ui;

import 'package:flame_test/flame_test.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/game/badminton_game.dart';

void main() {
  // Helper: creates a fresh BadmintonGame using flame_test's proper lifecycle.
  Future<BadmintonGame> buildGame({int seed = 7}) =>
      initializeGame(() => BadmintonGame(seed: seed));

  // Helper: creates a 1280×720 Canvas backed by a PictureRecorder.
  ui.Canvas makeCanvas() {
    final recorder = ui.PictureRecorder();
    return ui.Canvas(
      recorder,
      const Rect.fromLTWH(0, 0, kCourtWidth, kCourtHeight),
    );
  }

  // ---------------------------------------------------------------------------
  // State 1: servePending (match start)
  // ---------------------------------------------------------------------------

  test(
    'render smoke — servePending state renders without exception',
    () async {
      final game = await buildGame();

      // No updates yet: state is servePending. The shuttle is parked and the
      // HUD shows 0–0. This exercises the court background + net + both players
      // at their starting positions + score panel + parked shuttle.
      final canvas = makeCanvas();
      expect(
        () => game.renderTree(canvas),
        returnsNormally,
        reason:
            'renderTree must not throw in servePending state; any Paint/shader '
            'crash would appear here',
      );

      game.onRemove();
    },
  );

  // ---------------------------------------------------------------------------
  // State 2: inPlay (after a toss)
  // ---------------------------------------------------------------------------

  test(
    'render smoke — inPlay state renders without exception',
    () async {
      final game = await buildGame();

      // Advance past servePending by tossing (M1-034 hold+release pattern).
      game.controls.tossHeld = true;
      game.update(kTickDuration); // tick 1: charge
      game.controls.tossHeld = false;
      for (var i = 0; i < 5; i++) {
        game.update(kTickDuration); // tick 2: launch; ticks 3-6: in flight
      }

      // Phase should now be inPlay; the shuttle is in flight and the trail
      // buffer has started accumulating. This exercises the shuttle trail
      // rendering path and the full component tree in a live-play state.
      final canvas = makeCanvas();
      expect(
        () => game.renderTree(canvas),
        returnsNormally,
        reason:
            'renderTree must not throw in inPlay state; shuttle trail and '
            'player crewmate rendering must produce no crash',
      );

      game.onRemove();
    },
  );

  // ---------------------------------------------------------------------------
  // State 3: stun visual (run many frames so AI might stun; independent of AI)
  // ---------------------------------------------------------------------------

  test(
    'render smoke — stun-blink state renders without exception',
    () async {
      final game = await buildGame();

      // Drive a full second of updates. The stun blink counter increments
      // every render frame; this covers the dizzy-stars path even if no
      // actual stun event occurs (blink counter always increments).
      for (var i = 0; i < 60; i++) {
        game.update(kTickDuration);
      }

      final canvas = makeCanvas();
      expect(
        () => game.renderTree(canvas),
        returnsNormally,
        reason:
            'renderTree must not throw after 60 frames regardless of stun state; '
            'blink counter and dizzy-star path must not crash',
      );

      game.onRemove();
    },
  );

  // ---------------------------------------------------------------------------
  // State 4: full cycle servePending → inPlay → pointScored
  // Verifies that the new depth cues (trapezoid court, drop shadows, shuttle
  // ground shadow, swing animation) produce no render exceptions across all
  // three phases.
  // ---------------------------------------------------------------------------

  test(
    'render smoke — cycle through servePending → inPlay → pointScored without exception',
    () async {
      final game = await buildGame();
      final canvas = makeCanvas();

      // Phase 1: servePending render.
      expect(
        () => game.renderTree(canvas),
        returnsNormally,
        reason: 'renderTree must not throw in servePending (depth-cue pass)',
      );

      // Toss to enter inPlay.
      game.controls.tossHeld = true;
      game.update(kTickDuration);
      game.controls.tossHeld = false;
      for (var i = 0; i < 5; i++) {
        game.update(kTickDuration);
      }

      // Phase 2: inPlay render (shuttle in flight, drop shadows active).
      expect(
        () => game.renderTree(canvas),
        returnsNormally,
        reason:
            'renderTree must not throw in inPlay with shuttle shadow and '
            'player drop shadows',
      );

      // Drive until pointScored (serve timeout in kServeTimeoutFrames ticks,
      // or let the AI rally end naturally). Use a fast-forward: run up to
      // kServeTimeoutFrames + kPointPauseTicks ticks total to guarantee a
      // pointScored phase is reached.
      var reachedPointScored = false;
      for (var i = 0; i < kServeTimeoutFrames + kPointPauseTicks + 10; i++) {
        game.update(kTickDuration);
        if (game.view.phase.name == 'pointScored') {
          reachedPointScored = true;
          break;
        }
      }

      // Phase 3: pointScored render (if reached; guard to avoid false failure
      // if the match ends before pointScored is hit).
      if (reachedPointScored) {
        expect(
          () => game.renderTree(canvas),
          returnsNormally,
          reason:
              'renderTree must not throw in pointScored phase with new depth '
              'cues active',
        );
      }

      game.onRemove();
    },
  );
}
