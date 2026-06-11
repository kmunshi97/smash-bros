import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/math/fix.dart';

void main() {
  group('Fix arithmetic', () {
    test('basic operators', () {
      const a = Fix.of(6);
      const b = Fix.of(1.5);
      expect((a + b).toDouble(), 7.5);
      expect((a - b).toDouble(), 4.5);
      expect((a * b).toDouble(), 9.0);
      expect((a / b).toDouble(), 4.0);
      expect((-a).toDouble(), -6.0);
    });

    test('comparisons', () {
      expect(const Fix.of(1) < const Fix.of(2), isTrue);
      expect(const Fix.of(2) <= const Fix.of(2), isTrue);
      expect(const Fix.of(3) > const Fix.of(2), isTrue);
      expect(const Fix.of(2) >= const Fix.of(3), isFalse);
    });

    test('abs, clamp, isNegative', () {
      expect(const Fix.of(-4).abs().toDouble(), 4.0);
      expect(const Fix.of(-4).isNegative, isTrue);
      expect(const Fix.of(5).clamp(Fix.zero, const Fix.of(3)).toDouble(), 3.0);
      expect(const Fix.of(-1).clamp(Fix.zero, const Fix.of(3)).toDouble(), 0.0);
      expect(const Fix.of(2).clamp(Fix.zero, const Fix.of(3)).toDouble(), 2.0);
    });

    test('min and max', () {
      expect(Fix.min(const Fix.of(1), const Fix.of(2)), const Fix.of(1));
      expect(Fix.max(const Fix.of(1), const Fix.of(2)), const Fix.of(2));
    });

    test('identities', () {
      const v = Fix.of(7.25);
      expect(v + Fix.zero, v);
      expect(v * Fix.one, v);
      expect(const Fix.fromInt(3).toDouble(), 3.0);
    });
  });

  group('FixMath', () {
    test('sin and cos at key angles', () {
      expect(FixMath.sin(Fix.zero).toDouble(), 0.0);
      expect(FixMath.cos(Fix.zero).toDouble(), 1.0);
      expect(
        FixMath.sin(FixMath.pi / const Fix.of(2)).toDouble(),
        closeTo(1.0, 1e-12),
      );
      expect(FixMath.cos(FixMath.pi).toDouble(), closeTo(-1.0, 1e-12));
    });

    test('sqrt', () {
      expect(FixMath.sqrt(const Fix.of(9)).toDouble(), 3.0);
      expect(FixMath.sqrt(Fix.zero).toDouble(), 0.0);
    });
  });
}
