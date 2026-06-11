import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/entities/shuttle.dart';
import 'package:smash_bros/engine/entities/tunables.dart';
import 'package:smash_bros/engine/math/fix.dart';
import 'package:smash_bros/engine/math/fix_vec2.dart';
import 'package:smash_bros/engine/systems/rally_state.dart';
import 'package:smash_bros/engine/systems/shot_type.dart';

const _court = Court();

// Court constants (from constants.dart): netX = 640. A shuttle at x < 640 is on
// the left side, x > 640 on the right.

Shuttle _shuttleAtX(double x) =>
    Shuttle(position: FixVec2(Fix.of(x), const Fix.of(300)));

void main() {
  group('RallyState defaults', () {
    test('starts untouched with the normal drag coefficient', () {
      final rally = RallyState();
      expect(rally.lastHitter, isNull);
      expect(rally.hitLockout, isNull);
      expect(rally.lastShotType, isNull);
      expect(rally.activeDragCoefficient, Tunables.shuttleDragCoefficient);
    });
  });

  group('RallyState.observe', () {
    test(
      'does NOT clear the lockout while the shuttle is on the hitter side',
      () {
        // Shuttle still on the left half (x < 640).
        final rally = RallyState(hitLockout: CourtSide.left)
          ..observe(_shuttleAtX(300), _court);
        expect(rally.hitLockout, CourtSide.left);
      },
    );

    test('clears the lockout once the shuttle is on the other side', () {
      // Shuttle has crossed to the right half (x > 640).
      final rally = RallyState(hitLockout: CourtSide.left)
        ..observe(_shuttleAtX(900), _court);
      expect(rally.hitLockout, isNull);
    });

    test('is a no-op when there is no lockout', () {
      final rally = RallyState()..observe(_shuttleAtX(900), _court);
      expect(rally.hitLockout, isNull);
    });

    test(
      'right-side lockout clears when the shuttle reaches the left half',
      () {
        final rally = RallyState(hitLockout: CourtSide.right)
          ..observe(_shuttleAtX(200), _court);
        expect(rally.hitLockout, isNull);
      },
    );
  });

  group('RallyState drag coefficient', () {
    test('switching drop then normal returns to the default', () {
      final rally = RallyState()
        ..activeDragCoefficient = Tunables.shuttleDropShotDrag;
      expect(rally.activeDragCoefficient, Tunables.shuttleDropShotDrag);
      rally.activeDragCoefficient = Tunables.shuttleDragCoefficient;
      expect(rally.activeDragCoefficient, Tunables.shuttleDragCoefficient);
    });
  });

  group('RallyState.reset', () {
    test('returns every field to its start-of-point value', () {
      final rally = RallyState(
        lastHitter: CourtSide.right,
        hitLockout: CourtSide.right,
        lastShotType: ShotType.smash,
        activeDragCoefficient: Tunables.shuttleDropShotDrag,
      )..reset();
      expect(rally.lastHitter, isNull);
      expect(rally.hitLockout, isNull);
      expect(rally.lastShotType, isNull);
      expect(rally.activeDragCoefficient, Tunables.shuttleDragCoefficient);
    });
  });

  group('RallyState.copy', () {
    test('produces an independent snapshot', () {
      final original = RallyState(
        lastHitter: CourtSide.left,
        hitLockout: CourtSide.left,
        lastShotType: ShotType.drop,
        activeDragCoefficient: Tunables.shuttleDropShotDrag,
      );
      final snapshot = original.copy();

      // Mutating the original must not touch the snapshot.
      original
        ..lastHitter = CourtSide.right
        ..hitLockout = null
        ..lastShotType = ShotType.smash
        ..activeDragCoefficient = Tunables.shuttleDragCoefficient;

      expect(snapshot.lastHitter, CourtSide.left);
      expect(snapshot.hitLockout, CourtSide.left);
      expect(snapshot.lastShotType, ShotType.drop);
      expect(snapshot.activeDragCoefficient, Tunables.shuttleDropShotDrag);
    });
  });
}
