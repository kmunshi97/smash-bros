// Flame component tests (M1-022..024).
// Uses flame_test helpers for proper game lifecycle initialization, matching
// the pattern established in test/game/badminton_game_test.dart.
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/rules/match_phase.dart';
import 'package:smash_bros/game/badminton_game.dart';
import 'package:smash_bros/game/components/components.dart';

void main() {
  // Helper: creates a fresh BadmintonGame using flame_test's proper lifecycle.
  Future<BadmintonGame> buildGame({int seed = 7}) =>
      initializeGame(() => BadmintonGame(seed: seed));

  // ---------------------------------------------------------------------------
  // World registration (game.onLoad adds components)
  // ---------------------------------------------------------------------------

  group('BadmintonGame.onLoad — world components', () {
    test('world contains a CourtComponent after onLoad', () async {
      final game = await buildGame();
      expect(
        game.world.children.whereType<CourtComponent>(),
        isNotEmpty,
        reason: 'CourtComponent must be added to the world in onLoad',
      );
      game.onRemove();
    });

    test('world contains exactly 2 PlayerComponents after onLoad', () async {
      final game = await buildGame();
      final players = game.world.children.whereType<PlayerComponent>().toList();
      expect(players.length, 2, reason: 'One PlayerComponent per side');
      game.onRemove();
    });

    test('world contains left and right PlayerComponents', () async {
      final game = await buildGame();
      final players = game.world.children.whereType<PlayerComponent>().toList();
      final sides = players.map((p) => p.side).toSet();
      expect(sides, containsAll([CourtSide.left, CourtSide.right]));
      game.onRemove();
    });

    test('world contains a ShuttleComponent after onLoad', () async {
      final game = await buildGame();
      expect(
        game.world.children.whereType<ShuttleComponent>(),
        isNotEmpty,
        reason: 'ShuttleComponent must be added to the world in onLoad',
      );
      game.onRemove();
    });
  });

  // ---------------------------------------------------------------------------
  // Part A — view cache: identical object returned within a frame
  // ---------------------------------------------------------------------------

  group('BadmintonGame.view — per-frame cache', () {
    test('two successive view reads return the identical object', () async {
      final game = await buildGame();
      game.update(0.05); // advance a few ticks
      final v1 = game.view;
      final v2 = game.view;
      expect(
        identical(v1, v2),
        isTrue,
        reason:
            'view must return the cached RenderState; re-lerping on every '
            'call would waste CPU and produce different objects',
      );
      game.onRemove();
    });
  });

  // ---------------------------------------------------------------------------
  // PlayerComponent — position matches view after update
  // ---------------------------------------------------------------------------

  group('PlayerComponent — position tracking', () {
    test('left player position matches view after update', () async {
      final game = await buildGame();
      game.update(0.05); // fire some ticks so the view is non-trivial

      final leftPlayer = game.world.children
          .whereType<PlayerComponent>()
          .firstWhere((p) => p.side == CourtSide.left);

      final lv = game.view.leftPlayer;
      // Anchor: top-left of the 48×80 hitbox.
      expect(
        leftPlayer.position.x,
        closeTo(lv.x - kPlayerHitboxWidth / 2, 0.001),
        reason: 'left player x should be centred at view.leftPlayer.x',
      );
      expect(
        leftPlayer.position.y,
        closeTo(lv.feetY - kPlayerHitboxHeight, 0.001),
        reason:
            'left player y should be anchored at feet (feetY - hitboxHeight)',
      );
      game.onRemove();
    });

    test('right player position matches view after update', () async {
      final game = await buildGame();
      game.update(0.05);

      final rightPlayer = game.world.children
          .whereType<PlayerComponent>()
          .firstWhere((p) => p.side == CourtSide.right);

      final rv = game.view.rightPlayer;
      expect(
        rightPlayer.position.x,
        closeTo(rv.x - kPlayerHitboxWidth / 2, 0.001),
      );
      expect(
        rightPlayer.position.y,
        closeTo(rv.feetY - kPlayerHitboxHeight, 0.001),
      );
      game.onRemove();
    });

    test('PlayerComponent hitbox is 48×80 with feet anchoring', () async {
      final game = await buildGame();
      game.update(0); // no-op tick, just check initial state

      final leftPlayer = game.world.children
          .whereType<PlayerComponent>()
          .firstWhere((p) => p.side == CourtSide.left);

      final lv = game.view.leftPlayer;
      // Width: position.x to position.x + kPlayerHitboxWidth spans 48 units.
      const hitboxWidth = kPlayerHitboxWidth;
      const hitboxHeight = kPlayerHitboxHeight;
      expect(hitboxWidth, 48, reason: 'hitbox width must be 48 game units');
      expect(hitboxHeight, 80, reason: 'hitbox height must be 80 game units');

      // Verify feet anchoring: position.y + hitboxHeight == feetY.
      final feetYFromComponent = leftPlayer.position.y + kPlayerHitboxHeight;
      expect(
        feetYFromComponent,
        closeTo(lv.feetY, 0.001),
        reason: 'bottom of hitbox rect must equal feetY',
      );
      game.onRemove();
    });
  });

  // ---------------------------------------------------------------------------
  // ShuttleComponent — position + trail behaviour
  // ---------------------------------------------------------------------------

  group('ShuttleComponent — position tracking', () {
    test('shuttle position matches view.shuttle after update', () async {
      final game = await buildGame();
      game.update(0.05);

      final shuttle = game.world.children.whereType<ShuttleComponent>().first;

      final sv = game.view.shuttle;
      expect(shuttle.position.x, closeTo(sv.x, 0.001));
      expect(shuttle.position.y, closeTo(sv.y, 0.001));
      game.onRemove();
    });
  });

  group('ShuttleComponent — trail behaviour', () {
    test('trail stays empty during servePending phase', () async {
      // At match start, phase is servePending; the shuttle is parked.
      // Running several updates must NOT grow the trail.
      final game = await buildGame();
      expect(game.view.phase, MatchPhase.servePending);

      final shuttle = game.world.children.whereType<ShuttleComponent>().first;

      // Run many updates — none should cause the trail to grow because the
      // phase remains servePending throughout.
      for (var i = 0; i < 30; i++) {
        game.update(kTickDuration); // one simulation tick each time
      }

      expect(game.view.phase, MatchPhase.servePending);
      expect(
        shuttle.trail,
        isEmpty,
        reason:
            'trail must remain empty while phase != inPlay; a parked shuttle '
            'must not accumulate stale trail positions',
      );
      game.onRemove();
    });

    test('trail never exceeds capacity of 24', () async {
      // Drive many frames and assert the buffer is bounded even if somehow
      // the phase enters inPlay (defensive capacity check).
      final game = await buildGame();
      final shuttle = game.world.children.whereType<ShuttleComponent>().first;

      // Run 60 updates (1 second) — more than enough to fill any ring buffer.
      for (var i = 0; i < 60; i++) {
        game.update(kTickDuration);
      }

      expect(
        shuttle.trail.length,
        lessThanOrEqualTo(24),
        reason: 'trail ring buffer must never exceed capacity 24',
      );
      game.onRemove();
    });
  });

  // ---------------------------------------------------------------------------
  // testWithGame — standard lifecycle sanity check
  // ---------------------------------------------------------------------------

  testWithGame<BadmintonGame>(
    'BadmintonGame with components mounts correctly',
    () => BadmintonGame(seed: 42),
    (game) async {
      // All four expected component types present.
      expect(
        game.world.children.whereType<CourtComponent>().length,
        1,
      );
      expect(
        game.world.children.whereType<PlayerComponent>().length,
        2,
      );
      expect(
        game.world.children.whereType<ShuttleComponent>().length,
        1,
      );
    },
  );
}
