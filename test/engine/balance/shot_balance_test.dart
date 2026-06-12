import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/input/input_action.dart';
import 'package:smash_bros/engine/rules/match_phase.dart';
import 'package:smash_bros/engine/rules/point_reason.dart';
import 'package:smash_bros/engine/sim/simulation.dart';
import 'package:smash_bros/engine/systems/collision_system.dart';

import 'trajectory_harness.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Converts an angle from radians to degrees — used to build human-readable
/// assertion messages from the radian constants in constants.dart.
double _degOf(double radians) => radians * 180 / math.pi;

/// Ticks [sim] until [test] returns true or [maxTicks] elapse.
int _tickUntil(
  Simulation sim,
  bool Function() test, {
  int maxTicks = 5000,
}) {
  var ticks = 0;
  while (!test() && ticks < maxTicks) {
    sim.tick();
    ticks++;
  }
  return ticks;
}

// ---------------------------------------------------------------------------
// Constants used by assertions (named for readability in failure messages)
// ---------------------------------------------------------------------------

/// X coordinate of the serve-start shuttle
/// (kPlayer1StartX + kServeShuttleOffsetX = 160 + 50 = 210).
const double kServeStartX = kPlayer1StartX + kServeShuttleOffsetX;

/// Y coordinate of the serve-start shuttle
/// (kGroundY - kServeShuttleHeight = 600 - 110 = 490).
const double kServeStartY = kGroundY - kServeShuttleHeight;

/// Minimum clearance above the net top that a serve must achieve.
///
/// Serves must cross the net plane at y < (kNetTopY - kServeClearanceMargin).
/// 10 units keeps the shuttle clearly above the net-tape band
/// (kNetTapeHeight = 8), providing a visible margin.
const double kServeClearanceMargin = 10;

/// The guaranteed net-crossing y threshold for a valid serve.
const double kServeNetClearY = kNetTopY - kServeClearanceMargin;

/// Maximum flight time (ticks) for a serve.
///
/// Empirically (geometry-rebalance): at kTossSpeed=13, kTossAngle=43°,
/// kShuttleGravity=0.14, the serve from (210, 490) is airborne for 120 ticks.
/// The ceiling of 135 ticks (2.25 s) locks in the snappy-feel target.
const int kServeMaxFlightTicks = 135;

/// Maximum flight time (ticks) for a normal clear/drive shot.
///
/// Empirically (geometry-rebalance): at kNormalShotSpeed=12,
/// kShuttleGravity=0.14, the defensive shot from (300, 480) is airborne for
/// 119–132 ticks. The ceiling of 135 ticks (2.25 s) is the snappy-feel target.
const int kNormalMaxFlightTicks = 135;

/// Maximum flight time (ticks) for a drop shot.
///
/// Empirically (geometry-rebalance): at kDropShotSpeed=9, kDropShotAngle=65°,
/// kShuttleGravity=0.14, the drop from (450, 480) is airborne for 119 ticks.
/// The ceiling of 120 ticks (2.0 s) keeps the drop distinct from a clear.
const int kDropMaxFlightTicks = 120;

// ---------------------------------------------------------------------------
// New geometry contact-height constants (for readability in test descriptions)
// ---------------------------------------------------------------------------

/// Standard grounded drive contact y — hitbox top 450 (= 600 − 150), waist.
const double kGroundedDriveY = 480;

/// Grounded overhead contact y — hitbox top (450) minus racquet reach (50).
const double kGroundedOverheadY = 405;

/// Jump overhead contact y — feet at apex (460) minus height (150) minus
/// racquet reach (50) = 260; use 265 as a conservative realistic estimate.
const double kJumpOverheadY = 265;

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // The harness itself is exercised as a by-product of every test below —
  // a harness producing wrong results would break all balance assertions.

  group('Part B — Shot balance (geometry-rebalance)', () {
    // -----------------------------------------------------------------------
    // 1. SERVE
    // -----------------------------------------------------------------------
    group('1. Serve from left server position ($kServeStartX, $kServeStartY)', () {
      // The toss has a fixed angle (no PRNG spread), so there is a single
      // trajectory to test.
      //
      // Right-server trajectories are mirror-symmetric by construction:
      // ShotSystem._upwardArc flips the x-direction (dir = -1) for
      // CourtSide.right, producing a perfectly mirrored arc. Testing the
      // left server is therefore sufficient.
      //
      // Empirical (kTossSpeed=13, kTossAngle=43°, kShuttleGravity=0.14):
      //   serve from (210, 490): netCrossingY ≈ 307, landingX ≈ 925, 120 ticks.
      test(
        'clears the net by ≥$kServeClearanceMargin units, avoids short-serve, '
        'and lands in bounds (mirror-symmetric for right server)',
        () {
          final result = TrajectoryHarness.runUpwardArc(
            startX: kServeStartX,
            startY: kServeStartY,
            speed: kTossSpeed,
            angleDeg: _degOf(kTossAngle),
            dragCoefficient: kShuttleDragCoefficient,
          );

          expect(
            result.crossedNet,
            isTrue,
            reason:
                'Serve from ($kServeStartX, $kServeStartY) must cross the '
                'net plane; actual trajectory: $result',
          );
          expect(
            result.netCrossingY,
            lessThan(kServeNetClearY),
            reason:
                'Serve must clear the net top by at least $kServeClearanceMargin '
                'units (cross at y < $kServeNetClearY = kNetTopY($kNetTopY) − '
                '$kServeClearanceMargin); '
                'actual netCrossingY=${result.netCrossingY.toStringAsFixed(1)}. '
                'Trajectory: $result',
          );
          expect(
            result.landingX,
            greaterThanOrEqualTo(kShortServeLineRight),
            reason:
                'Serve must reach or pass the short-service line '
                '($kShortServeLineRight); '
                'actual landingX=${result.landingX.toStringAsFixed(1)}. '
                'Trajectory: $result',
          );
          expect(
            result.landingX,
            lessThanOrEqualTo(kCourtRightBound),
            reason:
                'Serve must land in bounds (x <= $kCourtRightBound); '
                'actual landingX=${result.landingX.toStringAsFixed(1)}. '
                'Trajectory: $result',
          );
        },
      );

      test(
        'flight time ≤ $kServeMaxFlightTicks ticks (snappy-feel target ≤ 2.25 s)',
        () {
          // Empirical: kTossSpeed=13 @43°, kShuttleGravity=0.14 → 120 ticks.
          final result = TrajectoryHarness.runUpwardArc(
            startX: kServeStartX,
            startY: kServeStartY,
            speed: kTossSpeed,
            angleDeg: _degOf(kTossAngle),
            dragCoefficient: kShuttleDragCoefficient,
          );

          expect(
            result.flightTicks,
            lessThanOrEqualTo(kServeMaxFlightTicks),
            reason:
                'Serve flight time must be ≤ $kServeMaxFlightTicks ticks '
                '(≤ ${kServeMaxFlightTicks / 60} s at 60 Hz); '
                'actual=${result.flightTicks} ticks. '
                'Raise kTossSpeed or kShuttleGravity if this fails. '
                'Trajectory: $result',
          );
        },
      );
    });

    // -----------------------------------------------------------------------
    // 2. NORMAL shot
    // -----------------------------------------------------------------------
    group('2. Normal shot from grounded drive contact (300, $kGroundedDriveY)', () {
      // The normal shot has a PRNG-drawn angle in [kNormalShotAngleMin,
      // kNormalShotAngleMax]. Verifying both extremes is sufficient because
      // the trajectory is monotone in angle over the tested range.
      //
      // Empirical (kNormalShotSpeed=12, kShuttleGravity=0.14):
      //   45°: netCrossingY ≈ 299, landingX ≈ 954, 119 ticks.
      //   55°: netCrossingY ≈ 249, landingX ≈ 886, 132 ticks.

      test(
        'both angle extremes: clears the net (crossing y < kNetTopY=$kNetTopY) '
        'and lands in the opponent half in bounds',
        () {
          for (final angleDeg in [
            _degOf(kNormalShotAngleMin),
            _degOf(kNormalShotAngleMax),
          ]) {
            final result = TrajectoryHarness.runUpwardArc(
              startX: 300,
              startY: kGroundedDriveY,
              speed: kNormalShotSpeed,
              angleDeg: angleDeg,
              dragCoefficient: kShuttleDragCoefficient,
            );

            expect(
              result.crossedNet,
              isTrue,
              reason:
                  'Normal shot at ${angleDeg.toStringAsFixed(1)}° must '
                  'cross the net; trajectory: $result',
            );
            expect(
              result.netCrossingY,
              lessThan(kNetTopY),
              reason:
                  'Normal shot at ${angleDeg.toStringAsFixed(1)}° must '
                  'clear the net top (netCrossingY < $kNetTopY); '
                  'actual=${result.netCrossingY.toStringAsFixed(1)}. '
                  'Trajectory: $result',
            );
            expect(
              result.landingX,
              greaterThan(kNetX),
              reason:
                  'Normal shot must land in the opponent half (x > $kNetX); '
                  'actual landingX=${result.landingX.toStringAsFixed(1)}. '
                  'Trajectory: $result',
            );
            expect(
              result.landingX,
              lessThanOrEqualTo(kCourtRightBound),
              reason:
                  'Normal shot must land in bounds (x <= $kCourtRightBound); '
                  'actual landingX=${result.landingX.toStringAsFixed(1)}. '
                  'Trajectory: $result',
            );
          }
        },
      );

      test(
        'both angle extremes: flight time ≤ $kNormalMaxFlightTicks ticks '
        '(snappy-feel target)',
        () {
          for (final angleDeg in [
            _degOf(kNormalShotAngleMin),
            _degOf(kNormalShotAngleMax),
          ]) {
            final result = TrajectoryHarness.runUpwardArc(
              startX: 300,
              startY: kGroundedDriveY,
              speed: kNormalShotSpeed,
              angleDeg: angleDeg,
              dragCoefficient: kShuttleDragCoefficient,
            );

            expect(
              result.flightTicks,
              lessThanOrEqualTo(kNormalMaxFlightTicks),
              reason:
                  'Normal shot at ${angleDeg.toStringAsFixed(1)}° flight time '
                  'must be ≤ $kNormalMaxFlightTicks ticks '
                  '(≤ ${kNormalMaxFlightTicks / 60} s at 60 Hz); '
                  'actual=${result.flightTicks} ticks. '
                  'Trajectory: $result',
            );
          }
        },
      );

      // -----------------------------------------------------------------------
      // Near-net normal shot — now a CLEAN PASS with the lower net
      // -----------------------------------------------------------------------
      //
      // CONSTRAINT ANALYSIS (geometry-rebalance):
      //
      // With kNetTopY = 470 (vs old 350), the near-net position (560, 480) is
      // only 80 units from the net (x = 640) and 10 units below the net top.
      // At kNormalShotSpeed = 12 and kShuttleGravity = 0.14, the shuttle
      // arcs over the much lower net with ease:
      //
      //   min angle (45°): netCrossingY ≈ 407 — above the net top (470) ✓
      //   max angle (55°): netCrossingY ≈ 377 — above the net top (470) ✓
      //
      // This is the OPPOSITE of the old behaviour (where the high net turned
      // this into a net fault). The near-net normal is now legal — clearing
      // a low shuttle near the net is a valid (if risky) play when the net
      // is at realistic badminton proportions.
      test(
        'from near-net position (560, $kGroundedDriveY) at both angle extremes: '
        'clears the lower net (clean pass, not a net fault)',
        () {
          for (final angleDeg in [
            _degOf(kNormalShotAngleMin),
            _degOf(kNormalShotAngleMax),
          ]) {
            final result = TrajectoryHarness.runUpwardArc(
              startX: 560,
              startY: kGroundedDriveY,
              speed: kNormalShotSpeed,
              angleDeg: angleDeg,
              dragCoefficient: kShuttleDragCoefficient,
            );

            expect(
              result.crossedNet,
              isTrue,
              reason:
                  'Near-net normal at ${angleDeg.toStringAsFixed(1)}° must '
                  'reach the net plane; trajectory: $result',
            );

            // With the lower net (470) from near-net height (480), the shuttle
            // now clears cleanly — crossing y is well above the net top.
            expect(
              result.netCrossingY,
              lessThan(kNetTopY),
              reason:
                  'Near-net normal at ${angleDeg.toStringAsFixed(1)}° must '
                  'clear the new net top ($kNetTopY) — the lower net makes '
                  'this a valid play now; '
                  'actual netCrossingY=${result.netCrossingY.toStringAsFixed(1)}. '
                  'Trajectory: $result',
            );
          }
        },
      );
    });

    // -----------------------------------------------------------------------
    // 3. DROP SHOT
    // -----------------------------------------------------------------------
    group('3. Drop shot from grounded drive contact (450, $kGroundedDriveY)', () {
      // Empirical (kDropShotSpeed=9, kDropShotAngle=65°, kShuttleGravity=0.14):
      //   from (450, 480): netCrossingY ≈ 304, landingX ≈ 786, 119 ticks.

      test(
        'crosses the net and lands SHORT (between net and short-serve line)',
        () {
          final result = TrajectoryHarness.runUpwardArc(
            startX: 450,
            startY: kGroundedDriveY,
            speed: kDropShotSpeed,
            angleDeg: _degOf(kDropShotAngle),
            dragCoefficient: kShuttleDropShotDrag,
          );

          expect(
            result.crossedNet,
            isTrue,
            reason: 'Drop shot must cross the net; trajectory: $result',
          );
          expect(
            result.netCrossingY,
            lessThan(kNetTopY),
            reason:
                'Drop shot must clear the net top '
                '(netCrossingY < $kNetTopY); '
                'actual=${result.netCrossingY.toStringAsFixed(1)}. '
                'Trajectory: $result',
          );
          expect(
            result.landingX,
            greaterThan(kNetX),
            reason:
                'Drop shot must land in the opponent half (x > $kNetX); '
                'actual landingX=${result.landingX.toStringAsFixed(1)}. '
                'Trajectory: $result',
          );
          expect(
            result.landingX,
            lessThanOrEqualTo(kShortServeLineRight),
            reason:
                'Drop shot must land SHORT — between the net and the '
                'opponent short-serve line ($kShortServeLineRight), so it is '
                'tactically distinct from a clear; '
                'actual landingX=${result.landingX.toStringAsFixed(1)}. '
                'Trajectory: $result',
          );
        },
      );

      test(
        'flight time ≤ $kDropMaxFlightTicks ticks (snappy-feel target)',
        () {
          final result = TrajectoryHarness.runUpwardArc(
            startX: 450,
            startY: kGroundedDriveY,
            speed: kDropShotSpeed,
            angleDeg: _degOf(kDropShotAngle),
            dragCoefficient: kShuttleDropShotDrag,
          );

          expect(
            result.flightTicks,
            lessThanOrEqualTo(kDropMaxFlightTicks),
            reason:
                'Drop shot flight time must be ≤ $kDropMaxFlightTicks ticks '
                '(≤ ${kDropMaxFlightTicks / 60} s at 60 Hz); '
                'actual=${result.flightTicks} ticks. '
                'Trajectory: $result',
          );
        },
      );
    });

    // -----------------------------------------------------------------------
    // 4. SMASH — overhead GROUNDED contact (y ≈ 405, clears net by design)
    // -----------------------------------------------------------------------
    group(
      '4. Smash OVERHEAD GROUNDED from (450, $kGroundedOverheadY) — '
      'legal by design with new geometry',
      () {
        // Design intent (geometry-rebalance): with kNetTopY = 470 and the
        // grounded reach-top = kGroundY − kPlayerHitboxHeight − kRacquetReach
        // = 600 − 150 − 50 = 400, a grounded overhead smash launches from
        // y ≈ 405, which is 65 units above the new net top (470). This is
        // intentionally legal — grounded overhead smashes should clear the
        // tape at the current angle range [10°, 15°].
        //
        // Empirical (kSmashSpeed=16, kShuttleGravity=0.14):
        //   10°: netCrossingY ≈ 451, landingX ≈ 948 ✓
        //   15°: netCrossingY ≈ 469, landingX ≈ 880 ✓ (just clears tape)
        //
        // The 15° max was chosen (vs old 13°) precisely because the grounded
        // overhead position is now above the net — wider angles are valid.
        // At 15.3° the crossing reaches 470.4 (clips the tape).

        test(
          'both angle extremes: clears the tape (crossing y < kNetTopY=$kNetTopY) '
          'and lands in the opponent half',
          () {
            for (final angleDeg in [
              _degOf(kSmashAngleMin),
              _degOf(kSmashAngleMax),
            ]) {
              final result = TrajectoryHarness.runDownwardArc(
                startX: 450,
                startY: kGroundedOverheadY,
                speed: kSmashSpeed,
                angleDeg: angleDeg,
                dragCoefficient: kShuttleDragCoefficient,
              );

              expect(
                result.crossedNet,
                isTrue,
                reason:
                    'Grounded overhead smash at ${angleDeg.toStringAsFixed(1)}° '
                    'from (450, $kGroundedOverheadY) must cross the net; '
                    'trajectory: $result',
              );
              expect(
                result.netCrossingY,
                lessThan(kNetTopY),
                reason:
                    'Grounded overhead smash at ${angleDeg.toStringAsFixed(1)}° '
                    'must clear the tape (netCrossingY < $kNetTopY). '
                    'This is LEGAL by design with the new geometry — contact '
                    'y ($kGroundedOverheadY) is above the net top ($kNetTopY); '
                    'actual=${result.netCrossingY.toStringAsFixed(1)}. '
                    'Trajectory: $result',
              );
              expect(
                result.landingX,
                greaterThan(kNetX),
                reason:
                    'Grounded overhead smash at ${angleDeg.toStringAsFixed(1)}° '
                    'must land past the net (x > $kNetX); '
                    'actual landingX=${result.landingX.toStringAsFixed(1)}. '
                    'Trajectory: $result',
              );
            }
          },
        );
      },
    );

    // -----------------------------------------------------------------------
    // 5. SMASH — jump overhead contact (y ≈ 265, bigger margin and range)
    // -----------------------------------------------------------------------
    group(
      '5. Smash JUMP overhead from (450, $kJumpOverheadY) — '
      'clears with bigger margin and lands further than grounded version',
      () {
        // Launch position: x=450, y=265 (feet at jump apex 460, hitbox height
        // 150 → hitbox top = 310, racquet reach 50 → contact y ≈ 260–310;
        // 265 is a conservative realistic estimate).
        //
        // The jump-smash bonus multiplies speed: kSmashSpeed * kJumpSmashBonus
        // = 16 * 1.15 = 18.4, within kShuttleMaxVelocity (20).
        //
        // Empirical (speed=16 grounded, speed=18.4 airborne):
        //   grounded (450,405) 10°: netCrossingY ≈ 451, landingX ≈ 948
        //   jump (450,265) 10°:     netCrossingY ≈ 311, landingX ≈ 1112 (further, bigger margin) ✓
        //   jump (450,265) 10° +bonus: netCrossingY ≈ 308, landingX ≈ 1172 ✓

        test(
          'both angle extremes: clears the net and lands further than the '
          'grounded version (jump smash has bigger margin and more range)',
          () {
            for (final angleDeg in [
              _degOf(kSmashAngleMin),
              _degOf(kSmashAngleMax),
            ]) {
              // Jump smash uses the jump-smash bonus speed.
              const jumpSpeed = kSmashSpeed * kJumpSmashBonus;
              final jumpResult = TrajectoryHarness.runDownwardArc(
                startX: 450,
                startY: kJumpOverheadY,
                speed: jumpSpeed,
                angleDeg: angleDeg,
                dragCoefficient: kShuttleDragCoefficient,
              );
              final groundedResult = TrajectoryHarness.runDownwardArc(
                startX: 450,
                startY: kGroundedOverheadY,
                speed: kSmashSpeed,
                angleDeg: angleDeg,
                dragCoefficient: kShuttleDragCoefficient,
              );

              expect(
                jumpResult.crossedNet,
                isTrue,
                reason:
                    'Jump smash at ${angleDeg.toStringAsFixed(1)}° must cross '
                    'the net; trajectory: $jumpResult',
              );
              expect(
                jumpResult.netCrossingY,
                lessThan(kNetTopY),
                reason:
                    'Jump smash at ${angleDeg.toStringAsFixed(1)}° must clear '
                    'the tape (netCrossingY < $kNetTopY); '
                    'actual=${jumpResult.netCrossingY.toStringAsFixed(1)}. '
                    'Trajectory: $jumpResult',
              );

              // Jump smash should cross higher (smaller netCrossingY) than
              // the grounded version — it launches from much higher up.
              expect(
                jumpResult.netCrossingY,
                lessThan(groundedResult.netCrossingY),
                reason:
                    'Jump smash at ${angleDeg.toStringAsFixed(1)}° must cross '
                    'the net higher (smaller netCrossingY) than the grounded '
                    'version (grounded=${groundedResult.netCrossingY.toStringAsFixed(1)}, '
                    'jump=${jumpResult.netCrossingY.toStringAsFixed(1)}). '
                    'Jump smash should give more margin. Trajectory: $jumpResult',
              );

              // Jump smash should land further (larger landingX) than grounded.
              expect(
                jumpResult.landingX,
                greaterThan(groundedResult.landingX),
                reason:
                    'Jump smash at ${angleDeg.toStringAsFixed(1)}° must land '
                    'further than the grounded version '
                    '(grounded=${groundedResult.landingX.toStringAsFixed(1)}, '
                    'jump=${jumpResult.landingX.toStringAsFixed(1)}). '
                    'Trajectory: $jumpResult',
              );

              expect(
                jumpResult.landingX,
                lessThanOrEqualTo(kCourtRightBound),
                reason:
                    'Jump smash at ${angleDeg.toStringAsFixed(1)}° must land '
                    'in bounds (x ≤ $kCourtRightBound); '
                    'actual=${jumpResult.landingX.toStringAsFixed(1)}. '
                    'Trajectory: $jumpResult',
              );
            }
          },
        );
      },
    );

    // -----------------------------------------------------------------------
    // 6. NEGATIVE: smash from LOW contact (y ≈ 560) — net fault
    // -----------------------------------------------------------------------
    group('6. Smash from LOW grounded contact (450, 560) — net fault', () {
      // Design intent: taking the shuttle low (y = 560, well below the net
      // top at 470) and smashing remains a mistake with the new geometry.
      // The shuttle launches at a downward angle from a position that is
      // 90 units below the net top — it cannot arc over the net cleanly and
      // either falls short of the net or clears the tape only below it.
      //
      // Empirical (kSmashSpeed=16, kShuttleGravity=0.14):
      //   10°: lands at x ≈ 619 (never reaches net plane at x = 640) → fault.
      //   15°: lands at x ≈ 600 → fault.
      //
      // The shuttle does NOT cross the net plane at all — it hits the ground
      // on the hitter's own side. This is a fault (ground hit before net).
      test(
        'at both angle extremes: shuttle does NOT reach the net — '
        'net fault (lands on own side)',
        () {
          for (final angleDeg in [
            _degOf(kSmashAngleMin),
            _degOf(kSmashAngleMax),
          ]) {
            final result = TrajectoryHarness.runDownwardArc(
              startX: 450,
              startY: 560,
              speed: kSmashSpeed,
              angleDeg: angleDeg,
              dragCoefficient: kShuttleDragCoefficient,
            );

            // The shuttle must NOT cross the net — or if it somehow does,
            // it must land on the hitter's own side (x ≤ kNetX).
            // Either outcome is a fault (taking the shuttle low and smashing).
            final isFault = !result.crossedNet || result.landingX <= kNetX;
            expect(
              isFault,
              isTrue,
              reason:
                  'Smash from low contact (450, 560) at '
                  '${angleDeg.toStringAsFixed(1)}° must be a fault '
                  "(shuttle must not cross the net, or must land on hitter's "
                  'side). Taking the shuttle low and smashing is a mistake. '
                  'actual crossedNet=${result.crossedNet}, '
                  'landingX=${result.landingX.toStringAsFixed(1)}. '
                  'Trajectory: $result',
            );
          }
        },
      );
    });

    // -----------------------------------------------------------------------
    // 7. Sanity invariants
    // -----------------------------------------------------------------------
    group('7. Sanity invariants', () {
      test('smash is the fastest shot and stays within the velocity clamp', () {
        expect(kSmashSpeed, greaterThan(kNormalShotSpeed));
        expect(kSmashSpeed, greaterThan(kDropShotSpeed));
        expect(kSmashSpeed, lessThanOrEqualTo(kShuttleMaxVelocity));
        expect(
          kSmashSpeed * kJumpSmashBonus,
          lessThanOrEqualTo(kShuttleMaxVelocity),
          reason:
              'Jump-smash speed (${kSmashSpeed * kJumpSmashBonus}) must not '
              'exceed kShuttleMaxVelocity ($kShuttleMaxVelocity).',
        );
      });

      test('gravity is at least 0.10 (anti-floatiness guard)', () {
        expect(
          kShuttleGravity,
          greaterThanOrEqualTo(0.10),
          reason:
              'kShuttleGravity ($kShuttleGravity) is below 0.10; anything '
              'below this threshold produces floaty 3-second shots. '
              'See M1-032a retune for measurement details.',
        );
      });

      test('jump-smash speed stays within the velocity clamp', () {
        const jumpSmashSpeed = kSmashSpeed * kJumpSmashBonus;
        expect(
          jumpSmashSpeed,
          lessThanOrEqualTo(kShuttleMaxVelocity),
          reason:
              'kSmashSpeed * kJumpSmashBonus ($jumpSmashSpeed) must not '
              'exceed kShuttleMaxVelocity ($kShuttleMaxVelocity).',
        );
      });
    });
  });

  // -------------------------------------------------------------------------
  // Part C — End-to-end serve integration test
  // -------------------------------------------------------------------------
  group('Part C — End-to-end serve integration (geometry-rebalance)', () {
    test(
      'left player tosses: shuttle crosses the net plane and lands in '
      'the right half (GroundHit.side == CourtSide.right)',
      () {
        // Build a real Simulation with seed=1 (arbitrary, deterministic).
        final sim = Simulation(seed: 1)..start();

        // Queue a toss on frame 0 for the left (server) player.
        sim.state.leftInputs.set(0, InputAction.toss);

        // Tick frame 0: the toss is resolved in the phase-pump step (step 2),
        // the serve is launched, and the FSM moves to inPlay.
        sim.tick();
        expect(
          sim.state.fsm.phase,
          MatchPhase.inPlay,
          reason: 'After toss, FSM must enter inPlay.',
        );

        // Verify the shuttle has rightward (+x) velocity.
        expect(
          sim.state.shuttle.velocity.x.toDouble(),
          greaterThan(0),
          reason: 'Left-server toss must impart rightward velocity.',
        );

        // Run up to 300 ticks with no further input. Track crossing and landing.
        var crossedNet = false;
        GroundHit? landing;

        _tickUntil(sim, () {
          final x = sim.state.shuttle.position.x.toDouble();
          if (!crossedNet && x > kNetX) crossedNet = true;

          for (final e in sim.lastTickCollisions) {
            if (e is GroundHit) landing = e;
          }
          return sim.state.fsm.phase == MatchPhase.pointScored;
        }, maxTicks: 300);

        expect(
          crossedNet,
          isTrue,
          reason: 'Serve must cross the net plane (shuttle x > $kNetX).',
        );

        expect(
          landing,
          isNotNull,
          reason: 'GroundHit must fire within 300 ticks of the toss.',
        );

        expect(
          landing!.side,
          CourtSide.right,
          reason:
              'Serve travels into the right half — GroundHit.side must be '
              'CourtSide.right. LandingX was: '
              '${landing!.landingX.toDouble().toStringAsFixed(1)}',
        );

        expect(
          sim.state.fsm.lastPointReason,
          anyOf(PointReason.groundedIn, PointReason.shortServeFault),
          reason:
              'The serve should end in a scored point. '
              'Reason: ${sim.state.fsm.lastPointReason}',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Documented trade-off note (geometry-rebalance)
  // -------------------------------------------------------------------------
  //
  // GEOMETRY-REBALANCE CHANGES (constants changed):
  //   kPlayerHitboxHeight:   80  → 150
  //   kPlayerHitboxWidth:    48  → 60
  //   kNetTopY:             350  → 470  (net = 130 u ≈ 87% of player height)
  //   kRacquetReach:         40  → 50
  //   kPlayerJumpApexY:     380  → 460  (jump height = 140 u)
  //   kServeShuttleOffsetX:  40  → 50
  //   kServeShuttleHeight:   80  → 110  (waist height of 150-u player)
  //   kSmashAngleMax:        13° → 15°  (grounded overhead now above net top)
  //
  // SHOT CONSTANTS UNCHANGED (re-verified empirically):
  //   kShuttleGravity = 0.14, kShuttleDragCoefficient = 0.001
  //   kShuttleDropShotDrag = 0.001 (no separate drop drag needed)
  //   kNormalShotSpeed = 12, kNormalShotAngleMin = 45°, kNormalShotAngleMax = 55°
  //   kSmashSpeed = 16, kSmashAngleMin = 10°
  //   kDropShotSpeed = 9, kDropShotAngle = 65°
  //   kTossSpeed = 13, kTossAngle = 43°
  //
  // EMPIRICAL RESULTS WITH NEW GEOMETRY:
  //   Serve (210, 490):  netCrossY ≈ 307, land ≈ 925, 120 ticks ≤ 135 ✓
  //   Normal 45° (300, 480): netCrossY ≈ 299, land ≈ 954, 119 ticks ≤ 135 ✓
  //   Normal 55° (300, 480): netCrossY ≈ 249, land ≈ 886, 132 ticks ≤ 135 ✓
  //   Drop 65° (450, 480):   netCrossY ≈ 304, land ≈ 786, 119 ticks ≤ 120 ✓
  //   Smash grounded overhead (450,405) 10°: netCrossY ≈ 451 < 470 ✓
  //   Smash grounded overhead (450,405) 15°: netCrossY ≈ 469 < 470 ✓ (legal)
  //   Smash jump (450,265) 10° +bonus:       netCrossY ≈ 308, land ≈ 1172 ✓
  //   Smash jump (450,265) 15° +bonus:       netCrossY ≈ 326, land ≈ 1094 ✓
  //   Smash low (450,560): never reaches net (lands at x ≈ 619) → fault ✓
  //
  // NEAR-NET NORMAL BEHAVIOUR CHANGE:
  //   Old (net top 350): from (560,520) at 45-55° → net fault (y > 358).
  //   New (net top 470): from (560,480) at 45-55° → clean pass (y ≈ 377-407).
  //   The lower net makes clearing from near-net legal — correct badminton
  //   physics: the player is 10 units above the net top, not 170 units below.
}
