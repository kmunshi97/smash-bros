import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/math/fix.dart';

void main() {
  group('Court', () {
    const court = Court();

    test('exposes the tuned dimensions', () {
      expect(court.netX.toDouble(), kNetX);
      expect(court.netTopY.toDouble(), kNetTopY);
      expect(court.groundY.toDouble(), kGroundY);
      expect(court.leftBound.toDouble(), kCourtLeftBound);
      expect(court.rightBound.toDouble(), kCourtRightBound);
      expect(court.shortServeLineLeft.toDouble(), kShortServeLineLeft);
      expect(court.shortServeLineRight.toDouble(), kShortServeLineRight);
    });

    test('shortServeLineFor selects the matching half', () {
      expect(
        court.shortServeLineFor(CourtSide.left),
        court.shortServeLineLeft,
      );
      expect(
        court.shortServeLineFor(CourtSide.right),
        court.shortServeLineRight,
      );
    });

    group('sideOfX', () {
      test('classifies points either side of the net', () {
        expect(court.sideOfX(const Fix.of(100)), CourtSide.left);
        expect(court.sideOfX(const Fix.of(1200)), CourtSide.right);
      });

      test('treats x exactly on the net as the left side by convention', () {
        expect(court.sideOfX(court.netX), CourtSide.left);
      });
    });

    group('clampToSide', () {
      const half = Fix.of(kPlayerHitboxWidth / 2);

      test('keeps the left player off the net and inside the outer bound', () {
        // Trying to walk through the net.
        final atNet = court.clampToSide(
          const Fix.of(2000),
          CourtSide.left,
          half,
        );
        expect(atNet.toDouble(), kNetX - kPlayerHitboxWidth / 2);
        // Right edge of the hitbox sits exactly on the net, not past it.
        expect(atNet.toDouble() + kPlayerHitboxWidth / 2, kNetX);

        // Trying to walk off the left edge.
        final atWall = court.clampToSide(
          const Fix.of(-500),
          CourtSide.left,
          half,
        );
        expect(atWall.toDouble(), kCourtLeftBound + kPlayerHitboxWidth / 2);
        expect(atWall.toDouble() - kPlayerHitboxWidth / 2, kCourtLeftBound);
      });

      test('keeps the right player off the net and inside the outer '
          'bound', () {
        final atNet = court.clampToSide(
          const Fix.of(-2000),
          CourtSide.right,
          half,
        );
        expect(atNet.toDouble(), kNetX + kPlayerHitboxWidth / 2);
        expect(atNet.toDouble() - kPlayerHitboxWidth / 2, kNetX);

        final atWall = court.clampToSide(
          const Fix.of(5000),
          CourtSide.right,
          half,
        );
        expect(atWall.toDouble(), kCourtRightBound - kPlayerHitboxWidth / 2);
        expect(atWall.toDouble() + kPlayerHitboxWidth / 2, kCourtRightBound);
      });

      test('leaves an in-bounds centre untouched', () {
        final x = court.clampToSide(const Fix.of(300), CourtSide.left, half);
        expect(x.toDouble(), 300);
      });
    });
  });
}
