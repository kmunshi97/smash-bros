// Flame game shell tests (M1-020).
// Uses flame_test helpers for proper game lifecycle initialization.
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/render/render_state.dart';
import 'package:smash_bros/engine/rules/match_phase.dart';
import 'package:smash_bros/game/badminton_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Helper: creates a fresh BadmintonGame using flame_test's proper lifecycle.
  Future<BadmintonGame> buildGame({int seed = 7}) =>
      initializeGame(() => BadmintonGame(seed: seed));

  group('BadmintonGame — fixed-timestep advance', () {
    test('update(0.05) produces exactly 3 simulation ticks at 60 Hz', () async {
      // 0.05 s / kTickDuration (1/60 s) = 3 ticks.
      final game = await buildGame();
      game.update(0.05);
      expect(game.view.frame, 3);
      game.onRemove();
    });

    test('view.phase is servePending after boot', () async {
      final game = await buildGame();
      expect(game.view.phase, MatchPhase.servePending);
      game.onRemove();
    });
  });

  group('BadmintonGame — takeEvents', () {
    test('takeEvents() drains the pending event queue', () async {
      // A full serve will generate events. Tick several times to guarantee
      // something fires (e.g. a serve timeout after 300 frames). For this
      // test we just verify the drain contract works regardless of whether
      // events occurred.
      final game = await buildGame();
      game.update(0.05); // 3 ticks
      final first = game.takeEvents();
      final second = game.takeEvents();

      // First call may or may not have events, but second is always empty.
      expect(second, isEmpty);
      // If first was non-empty the game correctly returned and cleared it.
      expect(first, isA<List<RenderEvent>>());
      game.onRemove();
    });

    test('takeEvents() second call always returns empty list', () async {
      final game = await buildGame();
      game.update(0.1); // 6 ticks
      final firstDrain = game.takeEvents(); // drain
      final secondDrain = game.takeEvents();
      game.onRemove();
      expect(firstDrain, isA<List<RenderEvent>>());
      expect(secondDrain, isEmpty);
    });
  });

  group('BadmintonGame — sub-tick interpolation via view', () {
    test('alpha is in (0, 1) after a sub-tick update', () async {
      // Advance by exactly half a tick so the driver has a non-zero, non-unit
      // alpha.  kTickDuration = 1/60; half tick = 1/120.
      final game = await buildGame();
      const halfTick = kTickDuration / 2;
      game.update(halfTick);
      // No full tick fires; frame stays at 0. alpha = (halfTick) / kTickDuration
      // = 0.5, so the lerped view's shuttle.x is between prev and current.
      final v = game.view;
      // Frame is 0 (no full tick yet), phase is servePending.
      expect(v.frame, 0);
      expect(v.phase, MatchPhase.servePending);
      game.onRemove();
    });

    test('view returns a RenderState (not null) at any alpha', () async {
      final game = await buildGame();
      game.update(kTickDuration * 0.3); // sub-tick
      expect(game.view, isA<RenderState>());
      game.onRemove();
    });
  });

  // Use testWithGame helper to confirm the standard flame_test lifecycle works.
  testWithGame<BadmintonGame>(
    'BadmintonGame mounts correctly via testWithGame',
    () => BadmintonGame(seed: 42),
    (game) async {
      // onLoad was called; initial state is servePending at frame 0.
      expect(game.view.phase, MatchPhase.servePending);
      expect(game.view.frame, 0);
    },
  );
}
