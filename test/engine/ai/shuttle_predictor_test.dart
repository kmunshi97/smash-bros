// Engine-layer tests for ShuttlePredictor: the ghost lookahead must agree
// bit-for-bit with the real integration, and must never touch any PRNG.
import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/ai/shuttle_predictor.dart';
import 'package:smash_bros/engine/entities/shuttle.dart';
import 'package:smash_bros/engine/entities/tunables.dart';
import 'package:smash_bros/engine/math/fix.dart';
import 'package:smash_bros/engine/math/fix_vec2.dart';

void main() {
  group('ShuttlePredictor.predictDescentX', () {
    test('matches the real integration bit-for-bit at the target height', () {
      // A leftward smash-like trajectory from the right side of the court.
      final shuttle = Shuttle(
        position: const FixVec2(Fix.of(900), Fix.of(300)),
        velocity: const FixVec2(Fix.of(-8), Fix.of(2)),
      );
      const targetY = Fix.of(480);

      final predicted = ShuttlePredictor.predictDescentX(
        shuttle,
        dragCoefficient: Tunables.shuttleDragCoefficient,
        targetY: targetY,
      );

      // Re-run the same integration by hand and stop at the same condition.
      final ghost = shuttle.copy();
      Fix? manual;
      for (var i = 0; i < 240; i++) {
        ghost.integrate(dragCoefficient: Tunables.shuttleDragCoefficient);
        if (ghost.velocity.y > Fix.zero && ghost.position.y >= targetY) {
          manual = ghost.position.x;
          break;
        }
      }

      expect(manual, isNotNull, reason: 'trajectory must descend past 480');
      expect(
        predicted,
        equals(manual),
        reason: 'predictor must replicate Shuttle.integrate exactly',
      );
    });

    test('does not mutate the real shuttle', () {
      final shuttle = Shuttle(
        position: const FixVec2(Fix.of(640), Fix.of(200)),
        velocity: const FixVec2(Fix.of(5), Fix.of(-3)),
      );
      final positionBefore = shuttle.position;
      final velocityBefore = shuttle.velocity;

      ShuttlePredictor.predictDescentX(
        shuttle,
        dragCoefficient: Tunables.shuttleDragCoefficient,
        targetY: Tunables.groundY,
      );

      expect(shuttle.position, equals(positionBefore));
      expect(shuttle.velocity, equals(velocityBefore));
    });

    test('terminates at the ground plane even above the target height', () {
      // Nearly horizontal, fast and low: it can hit the ground before it
      // ever descends to a targetY *above* the ground... use a target below
      // ground level so only the ground clause can fire.
      final shuttle = Shuttle(
        position: const FixVec2(Fix.of(400), Fix.of(590)),
        velocity: const FixVec2(Fix.of(6), Fix.of(1)),
      );

      final predicted = ShuttlePredictor.predictDescentX(
        shuttle,
        dragCoefficient: Tunables.shuttleDragCoefficient,
        targetY: const Fix.of(10000),
      );

      expect(
        predicted,
        isNotNull,
        reason: 'ground crossing must terminate the lookahead',
      );
    });

    test('returns null when the horizon is too short', () {
      // A steep upward launch cannot descend to 480 within 3 ticks.
      final shuttle = Shuttle(
        position: const FixVec2(Fix.of(640), Fix.of(500)),
        velocity: const FixVec2(Fix.of(1), Fix.of(-12)),
      );

      final predicted = ShuttlePredictor.predictDescentX(
        shuttle,
        dragCoefficient: Tunables.shuttleDragCoefficient,
        targetY: const Fix.of(480),
        maxTicks: 3,
      );

      expect(predicted, isNull);
    });
  });
}
