import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/math/fix.dart';
import 'package:smash_bros/engine/math/fix_vec2.dart';

void main() {
  group('FixVec2', () {
    test('addition, subtraction, negation', () {
      const a = FixVec2(Fix.of(1), Fix.of(2));
      const b = FixVec2(Fix.of(3), Fix.of(-1));
      expect(a + b, const FixVec2(Fix.of(4), Fix.of(1)));
      expect(a - b, const FixVec2(Fix.of(-2), Fix.of(3)));
      expect(-a, const FixVec2(Fix.of(-1), Fix.of(-2)));
    });

    test('scale and dot', () {
      const a = FixVec2(Fix.of(2), Fix.of(-3));
      expect(a.scale(const Fix.of(2)), const FixVec2(Fix.of(4), Fix.of(-6)));
      expect(a.dot(const FixVec2(Fix.of(4), Fix.of(1))).toDouble(), 5.0);
    });

    test('magnitude of a 3-4-5 triangle', () {
      const v = FixVec2(Fix.of(3), Fix.of(4));
      expect(v.magnitudeSquared.toDouble(), 25.0);
      expect(v.magnitude.toDouble(), 5.0);
    });

    test('clampMagnitude leaves short vectors untouched', () {
      const v = FixVec2(Fix.of(3), Fix.of(4));
      expect(identical(v.clampMagnitude(const Fix.of(10)), v), isTrue);
      expect(identical(v.clampMagnitude(const Fix.of(5)), v), isTrue);
    });

    test('clampMagnitude shortens long vectors preserving direction', () {
      const v = FixVec2(Fix.of(6), Fix.of(8));
      final clamped = v.clampMagnitude(const Fix.of(5));
      expect(clamped.magnitude.toDouble(), closeTo(5.0, 1e-12));
      expect(clamped.x.toDouble(), closeTo(3.0, 1e-12));
      expect(clamped.y.toDouble(), closeTo(4.0, 1e-12));
    });

    test('fromAngle points along +x at angle zero', () {
      final v = FixVec2.fromAngle(Fix.zero);
      expect(v.x.toDouble(), 1.0);
      expect(v.y.toDouble(), 0.0);
    });

    test('value equality and hashing', () {
      const a = FixVec2(Fix.of(1), Fix.of(2));
      const b = FixVec2(Fix.of(1), Fix.of(2));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(FixVec2.zero.x, Fix.zero);
      expect(FixVec2.zero.y, Fix.zero);
    });
  });
}
