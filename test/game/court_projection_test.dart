// Unit tests for CourtProjection (M2 POC): the engine→screen affine map that
// places the flat sim onto the perspective court. Pure — no Flame harness.
import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/game/court_projection.dart';

void main() {
  group('CourtProjection.apply', () {
    test('is the affine map offset + scale*engine', () {
      final p = CourtProjection(
        offsetX: 100,
        offsetY: -30,
        scaleX: 0.8,
        scaleY: 0.75,
      );
      final s = p.apply(200, 400);
      expect(s.x, closeTo(100 + 0.8 * 200, 1e-9));
      expect(s.y, closeTo(-30 + 0.75 * 400, 1e-9));
    });

    test('defaults map the engine court bounds inside the screen court band', () {
      final p = CourtProjection.defaults();
      final left = p.apply(kCourtLeftBound, kGroundY);
      final right = p.apply(kCourtRightBound, kGroundY);

      // Both baselines land inside the 1280-wide screen, left of right, and the
      // court is horizontally centred (midpoint near screen centre 640).
      expect(left.x, greaterThan(0));
      expect(right.x, lessThan(kCourtWidth));
      expect(left.x, lessThan(right.x));
      expect((left.x + right.x) / 2, closeTo(kCourtWidth / 2, 40));
    });

    test('defaults put the ground line on the mid-court "centre line"', () {
      final p = CourtProjection.defaults();
      final ground = p.apply(kNetX, kGroundY);
      // Players stand here: comfortably above the screen bottom (not the near
      // edge) and below the middle — i.e. mid-court, not "half court".
      expect(ground.y, greaterThan(kCourtHeight * 0.5));
      expect(ground.y, lessThan(kCourtHeight * 0.75));
    });

    test('the net top projects above the ground line (net stands up)', () {
      final p = CourtProjection.defaults();
      final netTop = p.apply(kNetX, kNetTopY);
      final ground = p.apply(kNetX, kGroundY);
      expect(netTop.y, lessThan(ground.y)); // smaller y = higher on screen
    });

    test('mutating params changes the mapping (live calibration)', () {
      final p = CourtProjection.defaults()..offsetX = 0;
      expect(p.apply(0, 0).x, 0);
      p.scaleX = 1;
      expect(p.apply(100, 0).x, 100);
    });
  });
}
