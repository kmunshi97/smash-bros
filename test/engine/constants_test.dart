import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/constants.dart';

/// Sanity checks on the gameplay constants so the test suite is never empty
/// and accidental edits to load-bearing relationships fail fast.
void main() {
  group('court geometry', () {
    test('net sits at the horizontal center of the court', () {
      expect(kNetX, kCourtWidth / 2);
    });

    test('net top is above the ground', () {
      expect(kNetTopY, lessThan(kGroundY));
    });

    test('jump apex clears the net top', () {
      // kPlayerJumpApexY is the feet y-coordinate at the jump peak.
      // In screen coordinates (+y downward), a smaller y means higher on screen.
      // The jump apex must be ABOVE the net top: apex y < net top y.
      expect(kPlayerJumpApexY, lessThan(kNetTopY));
    });
  });

  group('shot speeds', () {
    test('smash is the fastest shot and stays within the velocity clamp', () {
      expect(kSmashSpeed, greaterThan(kNormalShotSpeed));
      expect(kSmashSpeed, greaterThan(kDropShotSpeed));
      expect(kSmashSpeed, lessThanOrEqualTo(kShuttleMaxVelocity));
    });
  });

  group('timing windows', () {
    test('perfect block window is a valid, non-empty frame range', () {
      expect(kPerfectBlockWindowStart, lessThan(kPerfectBlockWindowEnd));
      expect(kPerfectBlockWindowStart, greaterThan(0));
    });
  });

  group('scoring', () {
    test('deuce begins one point before the target score', () {
      expect(kDeuceThreshold, kDefaultTargetScore - 1);
    });

    test('deuce cap allows at least one extended exchange', () {
      expect(kDeuceCap, greaterThan(kDefaultTargetScore));
    });
  });
}
