// Tests for the parallax backdrop maths (M2-002) and that it mounts in the
// court. offsetFor is pure; the mount check uses the flame_test harness.
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/game/badminton_game.dart';
import 'package:smash_bros/game/components/parallax_backdrop_component.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ParallaxBackdropComponent.offsetFor', () {
    final base = Vector2(-50, -30);

    test('at rest (zero shake, t=0) sits at the base position', () {
      final p = ParallaxBackdropComponent.offsetFor(base, Vector2.zero(), 0);
      expect(p.x, closeTo(base.x, 1e-9));
      expect(p.y, closeTo(base.y, 1e-9));
    });

    test('tracks a fraction of the camera shake (parallax < 1)', () {
      final shake = Vector2(10, 6);
      final p = ParallaxBackdropComponent.offsetFor(base, shake, 0);
      // Moves in the shake direction but by less than the full shake (so it
      // reads as farther away than the world-fixed floor).
      final dx = p.x - base.x;
      expect(dx, greaterThan(0));
      expect(dx, lessThan(shake.x));
    });

    test('drifts over time even with no shake (idle sway)', () {
      final atQuarter = ParallaxBackdropComponent.offsetFor(
        base,
        Vector2.zero(),
        1.5,
      );
      expect(
        (atQuarter - base).length,
        greaterThan(0),
        reason: 'idle sway should move the backdrop off its base over time',
      );
    });
  });

  group('mounting', () {
    Future<BadmintonGame> buildGame() =>
        initializeGame(() => BadmintonGame(seed: 7));

    test('the court mounts exactly one parallax backdrop', () async {
      final game = await buildGame();
      final backdrops = game.world
          .descendants()
          .whereType<ParallaxBackdropComponent>()
          .toList();
      expect(backdrops, hasLength(1));
    });
  });
}
