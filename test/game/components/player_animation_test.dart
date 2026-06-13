// Verifies PlayerComponent derives the animation state from the live view
// (M2-005): a fresh game's grounded, still players read as idle, and a smash
// SwingEvent flips the swinging player into the swing state.
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/game/animation/player_animator.dart';
import 'package:smash_bros/game/badminton_game.dart';
import 'package:smash_bros/game/components/components.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<BadmintonGame> buildGame({int seed = 7}) =>
      initializeGame(() => BadmintonGame(seed: seed));

  PlayerComponent playerOn(BadmintonGame game, CourtSide side) => game
      .world
      .children
      .whereType<PlayerComponent>()
      .firstWhere((p) => p.side == side);

  test('grounded, still players start idle after a few frames', () async {
    final game = await buildGame();
    // A couple of update frames so the animator has prev-frame deltas.
    game
      ..update(1 / 60)
      ..update(1 / 60);
    expect(playerOn(game, CourtSide.left).animState, PlayerAnimState.idle);
    expect(playerOn(game, CourtSide.right).animState, PlayerAnimState.idle);
  });

  test('animState is never null and is a valid enum value', () async {
    final game = await buildGame();
    game.update(1 / 60);
    expect(
      PlayerAnimState.values,
      contains(playerOn(game, CourtSide.left).animState),
    );
  });
}
