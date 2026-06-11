import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/entities/shuttle.dart';
import 'package:smash_bros/engine/math/fix.dart';
import 'package:smash_bros/engine/math/fix_vec2.dart';
import 'package:smash_bros/engine/systems/collision_system.dart';

const _court = Court();

// Court constants (from constants.dart), restated for hand-computed expectations:
//   netX = 640, netTopY = 350, tapeHeight = 8, tapeBottom = 358,
//   groundY = 600, leftBound = 40, rightBound = 1240.

/// Builds a shuttle whose sweep this tick is [from] -> [to], with [velocity]
/// (defaulting to the sweep delta so responses see a sensible velocity).
Shuttle _swept(FixVec2 from, FixVec2 to, {FixVec2? velocity}) => Shuttle(
  position: to,
  previousPosition: from,
  velocity: velocity ?? (to - from),
);

FixVec2 _v(double x, double y) => FixVec2(Fix.of(x), Fix.of(y));

void main() {
  group('CollisionSystem net plane', () {
    test('fast smash tunnels through the net body in one tick → NetBodyHit', () {
      // Sweep from left of the net to right of it, ~20 units/tick, crossing
      // the net plane well below the tape band. Neither endpoint touches netX.
      // From (630, 500) to (650, 500): crosses x=640 at t=0.5, y=500 (>358).
      final s = _swept(_v(630, 500), _v(650, 500), velocity: _v(20, 0));
      final events = CollisionSystem.resolve(s, _court);

      expect(events, hasLength(1));
      expect(events.single, isA<NetBodyHit>());
      final hit = events.single as NetBodyHit;
      expect(hit.crossing.x.toDouble(), 640);
      expect(hit.crossing.y.toDouble(), 500);
    });

    test('crossing above the net top → no event, shuttle untouched', () {
      // Crosses x=640 at y=300 (< netTopY 350): clean passage.
      final from = _v(630, 300);
      final to = _v(650, 300);
      final s = _swept(from, to, velocity: _v(20, 0));
      final events = CollisionSystem.resolve(s, _court);

      expect(events, isEmpty);
      expect(s.position, to);
      expect(s.velocity, _v(20, 0));
    });

    test('crossing within the tape band → NetCordHit, velocity halved', () {
      // Crosses x=640 at y=355 (within [350, 358]).
      final to = _v(650, 355);
      final s = _swept(_v(630, 355), to, velocity: _v(20, 4));
      final events = CollisionSystem.resolve(s, _court);

      expect(events, hasLength(1));
      expect(events.single, isA<NetCordHit>());
      final hit = events.single as NetCordHit;
      expect(hit.crossing.x.toDouble(), 640);
      expect(hit.crossing.y.toDouble(), 355);
      // Velocity damped by 0.5; position continues to the integrated point.
      expect(s.velocity, _v(10, 2));
      expect(s.position, to);
    });

    test('tape boundary at netTopY is a cord hit (inclusive lower edge)', () {
      final s = _swept(_v(630, 350), _v(650, 350), velocity: _v(20, 0));
      final events = CollisionSystem.resolve(s, _court);
      expect(events.single, isA<NetCordHit>());
    });

    test('tape boundary at netTopY+tapeHeight is a cord hit (inclusive)', () {
      final s = _swept(_v(630, 358), _v(650, 358), velocity: _v(20, 0));
      final events = CollisionSystem.resolve(s, _court);
      expect(events.single, isA<NetCordHit>());
    });
  });

  group('CollisionSystem ground', () {
    test('diagonal sweep: landingX is correctly interpolated', () {
      // From (100, 580) to (140, 620). groundY = 600.
      //   t = (600 - 580) / (620 - 580) = 20/40 = 0.5
      //   landingX = 100 + 0.5 * (140 - 100) = 120
      final s = _swept(_v(100, 580), _v(140, 620), velocity: _v(40, 40));
      final events = CollisionSystem.resolve(s, _court);

      expect(events, hasLength(1));
      final hit = events.single as GroundHit;
      expect(hit.landingX.toDouble(), 120);
      expect(hit.side, CourtSide.left);
      expect(hit.isInBounds, isTrue);
      // Position clamped to ground; velocity zeroed.
      expect(s.position, _v(120, 600));
      expect(s.velocity, FixVec2.zero);
    });

    test('vertical drop (d.x == 0) → GroundHit with landingX == drop x', () {
      final s = _swept(_v(300, 590), _v(300, 610), velocity: _v(0, 20));
      final events = CollisionSystem.resolve(s, _court);

      expect(events, hasLength(1));
      final hit = events.single as GroundHit;
      expect(hit.landingX.toDouble(), 300);
      expect(s.position, _v(300, 600));
      expect(s.velocity, FixVec2.zero);
    });

    test('a sweep entirely above the ground produces no ground event', () {
      final s = _swept(_v(100, 500), _v(140, 540), velocity: _v(40, 40));
      final events = CollisionSystem.resolve(s, _court);
      expect(events, isEmpty);
    });
  });

  group('CollisionSystem line calls (on the line = IN)', () {
    test('landing exactly on leftBound is in bounds', () {
      // Drop straight onto x = 40.
      final s = _swept(_v(40, 590), _v(40, 610), velocity: _v(0, 20));
      final hit = CollisionSystem.resolve(s, _court).single as GroundHit;
      expect(hit.landingX.toDouble(), 40);
      expect(hit.isInBounds, isTrue);
    });

    test('landing exactly on rightBound is in bounds', () {
      final s = _swept(_v(1240, 590), _v(1240, 610), velocity: _v(0, 20));
      final hit = CollisionSystem.resolve(s, _court).single as GroundHit;
      expect(hit.landingX.toDouble(), 1240);
      expect(hit.isInBounds, isTrue);
    });

    test('landing just outside leftBound is out', () {
      final s = _swept(_v(39, 590), _v(39, 610), velocity: _v(0, 20));
      final hit = CollisionSystem.resolve(s, _court).single as GroundHit;
      expect(hit.isInBounds, isFalse);
    });

    test('landing just outside rightBound is out', () {
      final s = _swept(_v(1241, 590), _v(1241, 610), velocity: _v(0, 20));
      final hit = CollisionSystem.resolve(s, _court).single as GroundHit;
      expect(hit.isInBounds, isFalse);
    });
  });

  group('CollisionSystem combined sweeps', () {
    test('tape graze then ground in the same tick → both events in t-order', () {
      // Crosses net at x=640: choose geometry so the net crossing (within the
      // tape band) happens before the ground crossing.
      // From (600, 354) to (680, 604). d = (80, 250).
      //   netT = (640 - 600) / 80 = 0.5, crossing y = 354 + 0.5*250 = 479.
      // That y is below the tape, so widen: use a shallow descent.
      // From (600, 350) to (680, 610). d = (80, 260).
      //   netT = (640-600)/80 = 0.5 → y = 350 + 0.5*260 = 480 (net-body, no good)
      // Need the net crossing y in [350,358] AND a later ground crossing.
      // Put the net crossing early in the sweep:
      // From (635, 354) to (760, 620). d = (125, 266).
      //   netT = (640-635)/125 = 0.04 → y = 354 + 0.04*266 = 364.64 (>358, body)
      // Make the descent gentle near the net, so crossing y stays in band:
      // From (635, 351) to (660, 620). d = (25, 269).
      //   netT = (640-635)/25 = 0.2 → y = 351 + 0.2*269 = 404.8 (>358, body)
      // The tape band is thin; to graze it the sweep must cross x=640 while
      // y is in [350,358]. Use a fast horizontal-ish crossing then a long
      // drop afterwards:
      // From (636, 352) to (644, 612). d = (8, 260).
      //   netT = (640-636)/8 = 0.5 → y = 352 + 0.5*260 = 482 (body again).
      // The issue: at netT the y is mid-sweep. To keep y small at the crossing
      // we must cross x near the START of the sweep. Start just left of net:
      // From (639, 352) to (655, 612). d = (16, 260).
      //   netT = (640-639)/16 = 0.0625 → y = 352 + 0.0625*260 = 368.25 (body).
      // Net top is at 350; to keep crossing y <= 358 with a 260-unit drop, the
      // crossing must be at t <= (358-352)/260 ≈ 0.023. Start essentially on
      // the plane:
      // From (639.7, 352) to (655, 612). d = (15.3, 260).
      //   netT = (640-639.7)/15.3 = 0.0196 → y = 352 + 0.0196*260 = 357.1 (cord!)
      //   ground: groundY=600, t=(600-352)/260 = 0.9538, landingX = 639.7 +
      //     0.9538*15.3 = 654.3.
      final s = _swept(_v(639.7, 352), _v(655, 612), velocity: _v(15.3, 260));
      final events = CollisionSystem.resolve(s, _court);

      expect(events, hasLength(2));
      expect(events[0], isA<NetCordHit>());
      expect(events[1], isA<GroundHit>());
      // Net-cord crossing y is within the tape band.
      final cord = events[0] as NetCordHit;
      expect(cord.crossing.y.toDouble(), inInclusiveRange(350, 358));
      // Ground response wins the final position (clamped to ground).
      expect(s.position.y.toDouble(), 600);
      expect(s.velocity, FixVec2.zero);
    });

    test('net body hit consumes the sweep: only NetBodyHit reported', () {
      // A sweep that crosses the net body AND would reach the ground reports
      // only the NetBodyHit, parked at the net on the hitter's (left) side.
      // From (600, 580) to (700, 620). d = (100, 40).
      //   netT = (640-600)/100 = 0.4 → crossing y = 580 + 0.4*40 = 596 (>358).
      //   This sweep would also cross ground (p1.y=620 >= 600).
      final s = _swept(_v(600, 580), _v(700, 620), velocity: _v(100, 40));
      final events = CollisionSystem.resolve(s, _court);

      expect(events, hasLength(1));
      expect(events.single, isA<NetBodyHit>());
      // Parked at the net plane, nudged back onto the left (hitter) side.
      expect(s.position.x.toDouble(), lessThan(640));
      expect(s.position.x.toDouble(), closeTo(639.5, 1e-9));
      expect(s.velocity.x.toDouble(), 0);
      // Downward velocity kept (was +40 > 0).
      expect(s.velocity.y.toDouble(), 40);
    });

    test('net body hit from the right parks on the right side', () {
      // Net crossing at t = 0.6, y = 524 — squarely on the net body, well
      // above the ground (no ground crossing on this sweep).
      final s = _swept(_v(700, 500), _v(600, 540), velocity: _v(-100, 40));
      final events = CollisionSystem.resolve(s, _court);
      expect(events.single, isA<NetBodyHit>());
      expect(s.position.x.toDouble(), greaterThan(640));
      expect(s.position.x.toDouble(), closeTo(640.5, 1e-9));
      expect(s.velocity.x.toDouble(), 0);
    });

    test('net body hit with upward velocity zeroes y (max with 0)', () {
      // Upward (negative y) velocity becomes 0, so gravity re-accumulates.
      final s = _swept(_v(600, 500), _v(700, 500), velocity: _v(100, -10));
      CollisionSystem.resolve(s, _court);
      expect(s.velocity.y.toDouble(), 0);
    });
  });

  group('CollisionSystem edge cases', () {
    test('start exactly on the net plane (P0.x == netX) — no crossing, no '
        'divide-by-zero', () {
      // Starts on the plane moving away to the right; no sign change.
      final s = _swept(_v(640, 400), _v(660, 400), velocity: _v(20, 0));
      final events = CollisionSystem.resolve(s, _court);
      expect(events, isEmpty);
      expect(s.position.x.toDouble().isNaN, isFalse);
      expect(s.position, _v(660, 400));
    });

    test('purely vertical sweep at the net x does not crash (d.x == 0)', () {
      final s = _swept(_v(640, 400), _v(640, 450), velocity: _v(0, 50));
      final events = CollisionSystem.resolve(s, _court);
      expect(events, isEmpty);
      expect(s.position.x.toDouble().isNaN, isFalse);
    });

    test('ground hit BEFORE the net plane wins the sweep (steep smash)', () {
      // Starts left of the net at (600, 590), ends past the net below ground
      // at (650, 615). Ground crossing: t = (600-590)/25 = 0.4 -> x = 620
      // (in front of the net). Net crossing: t = 0.8 at y = 610, which is
      // BELOW ground level — the shuttle landed before ever reaching the
      // net, so this must be a GroundHit, not a NetBodyHit.
      final s = _swept(_v(600, 590), _v(650, 615), velocity: _v(50, 25));
      final events = CollisionSystem.resolve(s, _court);
      expect(events, hasLength(1));
      final hit = events.single;
      expect(hit, isA<GroundHit>());
      expect((hit as GroundHit).landingX.toDouble(), closeTo(620, 1e-9));
      expect(hit.side, CourtSide.left);
      expect(s.position, FixVec2(hit.landingX, _court.groundY));
      expect(s.velocity, FixVec2.zero);
    });

    test('determinism: two identical shuttles resolved twice match', () {
      final a = _swept(_v(639.7, 352), _v(655, 612), velocity: _v(15.3, 260));
      final b = _swept(_v(639.7, 352), _v(655, 612), velocity: _v(15.3, 260));
      final ea = CollisionSystem.resolve(a, _court);
      final eb = CollisionSystem.resolve(b, _court);
      expect(ea, eb);
      expect(a.position, b.position);
      expect(a.velocity, b.velocity);
    });
  });
}
