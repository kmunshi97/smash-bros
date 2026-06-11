import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/shuttle.dart';
import 'package:smash_bros/engine/math/fix.dart';
import 'package:smash_bros/engine/math/fix_vec2.dart';

const _drag = Fix.of(kShuttleDragCoefficient);
const _dropDrag = Fix.of(kShuttleDropShotDrag);

Shuttle _shuttle({FixVec2 velocity = FixVec2.zero}) =>
    Shuttle(position: FixVec2.zero, velocity: velocity);

void main() {
  group('Shuttle.integrate', () {
    test('gravity accelerates the shuttle downward (+y)', () {
      final s = _shuttle()..integrate(dragCoefficient: _drag);
      // Velocity is now downward, ~gravity (drag shaves a hair off it).
      expect(s.velocity.y.toDouble(), greaterThan(0));
      expect(s.velocity.y.toDouble(), closeTo(kShuttleGravity, 1e-3));
      // Moved downward.
      expect(s.position.y.toDouble(), greaterThan(0));
    });

    test('captures previousPosition before moving', () {
      final s = Shuttle(
        position: const FixVec2(Fix.of(10), Fix.of(20)),
        velocity: const FixVec2(Fix.of(1), Fix.of(0)),
      )..integrate(dragCoefficient: _drag);
      expect(s.previousPosition, const FixVec2(Fix.of(10), Fix.of(20)));
      expect(s.position.x.toDouble(), greaterThan(10));
    });

    test('drag reduces horizontal speed versus no drag', () {
      final withDrag = _shuttle(velocity: const FixVec2(Fix.of(10), Fix.zero));
      final noDrag = _shuttle(velocity: const FixVec2(Fix.of(10), Fix.zero));
      withDrag.integrate(dragCoefficient: _drag);
      noDrag.integrate(dragCoefficient: Fix.zero);
      // No-drag horizontal velocity is unchanged (gravity only touches y).
      expect(noDrag.velocity.x.toDouble(), 10);
      expect(
        withDrag.velocity.x.toDouble(),
        lessThan(noDrag.velocity.x.toDouble()),
      );
    });

    test('the drop-shot coefficient slows the shuttle more', () {
      final normal = _shuttle(velocity: const FixVec2(Fix.of(10), Fix.zero));
      final drop = _shuttle(velocity: const FixVec2(Fix.of(10), Fix.zero));
      normal.integrate(dragCoefficient: _drag);
      drop.integrate(dragCoefficient: _dropDrag);
      expect(
        drop.velocity.magnitude.toDouble(),
        lessThan(normal.velocity.magnitude.toDouble()),
      );
    });

    test('the zero-velocity case is safe (no NaN from normalisation)', () {
      final s = _shuttle()..integrate(dragCoefficient: _drag);
      expect(s.velocity.x.toDouble().isNaN, isFalse);
      expect(s.velocity.y.toDouble().isNaN, isFalse);
      expect(s.velocity.x.toDouble(), 0);
    });

    test('speed never exceeds kShuttleMaxVelocity even launched at 100', () {
      final s = _shuttle(velocity: const FixVec2(Fix.of(100), Fix.of(100)));
      for (var i = 0; i < 50; i++) {
        s.integrate(dragCoefficient: _drag);
        expect(
          s.velocity.magnitude.toDouble(),
          lessThanOrEqualTo(kShuttleMaxVelocity + 1e-9),
        );
      }
    });

    test('integration is deterministic over 1000 ticks', () {
      final a = _shuttle(velocity: const FixVec2(Fix.of(7), Fix.of(-3)));
      final b = _shuttle(velocity: const FixVec2(Fix.of(7), Fix.of(-3)));
      for (var i = 0; i < 1000; i++) {
        a.integrate(dragCoefficient: _drag);
        b.integrate(dragCoefficient: _drag);
      }
      expect(a.position, b.position);
      expect(a.velocity, b.velocity);
    });

    test('terminal speed converges instead of blowing up', () {
      final s = _shuttle();
      // Let a dropped shuttle reach terminal velocity.
      for (var i = 0; i < 9000; i++) {
        s.integrate(dragCoefficient: _drag);
      }
      final earlier = s.velocity.magnitude.toDouble();
      for (var i = 0; i < 1000; i++) {
        s.integrate(dragCoefficient: _drag);
      }
      final later = s.velocity.magnitude.toDouble();
      // Stable: bounded and barely changing (drag balances gravity).
      expect(later, lessThanOrEqualTo(kShuttleMaxVelocity + 1e-9));
      expect((later - earlier).abs(), lessThan(1e-3));
    });
  });

  group('Shuttle', () {
    test('launch sets velocity', () {
      final s = _shuttle()..launch(const FixVec2(Fix.of(5), Fix.of(-2)));
      expect(s.velocity, const FixVec2(Fix.of(5), Fix.of(-2)));
    });

    test('copy is independent of the original', () {
      final original = Shuttle(
        position: const FixVec2(Fix.of(1), Fix.of(2)),
        velocity: const FixVec2(Fix.of(3), Fix.of(4)),
      );
      final clone = original.copy()
        ..integrate(dragCoefficient: _drag)
        ..launch(const FixVec2(Fix.of(99), Fix.of(99)));
      expect(original.position, const FixVec2(Fix.of(1), Fix.of(2)));
      expect(original.velocity, const FixVec2(Fix.of(3), Fix.of(4)));
      expect(clone.velocity, const FixVec2(Fix.of(99), Fix.of(99)));
    });
  });
}
