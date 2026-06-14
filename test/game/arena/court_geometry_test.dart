// Unit tests for the procedural court's perspective geometry (M2 court rework).
import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/game/arena/court_geometry.dart';

void main() {
  // Matches CourtProjection.defaults().
  const geo = CourtGeometry(
    offsetX: 117,
    offsetY: 50,
    scaleX: 0.817,
    scaleY: 0.77,
  );

  group('play line (depth 0) matches the affine projection', () {
    test('point(x, 0) is offset + scale*x with the ground y', () {
      const groundScreenY = 50 + 0.77 * kGroundY; // 512
      final left = geo.point(kCourtLeftBound, 0);
      final right = geo.point(kCourtRightBound, 0);
      expect(left.dx, closeTo(117 + 0.817 * kCourtLeftBound, 1e-6));
      expect(right.dx, closeTo(117 + 0.817 * kCourtRightBound, 1e-6));
      expect(left.dy, closeTo(groundScreenY, 1e-6));
      expect(right.dy, closeTo(groundScreenY, 1e-6));
    });

    test('centre is the net line', () {
      expect(geo.centerX, closeTo(117 + 0.817 * kNetX, 1e-6));
    });
  });

  group('perspective depth', () {
    test('near (+1) sits below far (-1)', () {
      expect(geo.point(kNetX, 1).dy, greaterThan(geo.point(kNetX, -1).dy));
    });

    test('near is wider than far about the centre', () {
      final nearSpread = (geo.point(kCourtLeftBound, 1).dx - geo.centerX).abs();
      final farSpread = (geo.point(kCourtLeftBound, -1).dx - geo.centerX).abs();
      expect(nearSpread, greaterThan(farSpread));
    });

    test('the centre line does not move with depth (net stays at centre)', () {
      expect(geo.point(kNetX, -1).dx, closeTo(geo.centerX, 1e-6));
      expect(geo.point(kNetX, 1).dx, closeTo(geo.centerX, 1e-6));
    });
  });

  group('court markings derive from the engine constants', () {
    test('line xs are the baselines, short-service lines and net', () {
      expect(
        CourtGeometry.lineXs,
        containsAll(<double>[
          kCourtLeftBound,
          kShortServeLineLeft,
          kNetX,
          kShortServeLineRight,
          kCourtRightBound,
        ]),
      );
    });

    test('floor quad has four corners', () {
      expect(geo.floorQuad(), hasLength(4));
    });
  });

  group('net', () {
    test('net height is the projected ground-to-tape distance', () {
      expect(geo.netHeightPx, closeTo(0.77 * (kGroundY - kNetTopY), 1e-6));
      expect(geo.netHeightPx, greaterThan(0));
    });

    test('cord tops sit above their bases', () {
      final (farBase, nearBase) = geo.netBase();
      final (farTop, nearTop) = geo.netCordTops();
      expect(farTop.dy, lessThan(farBase.dy));
      expect(nearTop.dy, lessThan(nearBase.dy));
    });
  });
}
