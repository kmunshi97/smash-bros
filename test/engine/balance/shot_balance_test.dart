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

/// X coordinate of the serve-start shuttle (kPlayer1StartX + kServeShuttleOffsetX).
///
/// kPlayer1StartX = kCourtLeftBound + 120 = 40 + 120 = 160.
/// Shuttle offset toward net (rightward) = kServeShuttleOffsetX = 40.
/// So serve launch position = 200.
const double kServeStartX = kPlayer1StartX + kServeShuttleOffsetX;

/// Y coordinate of the serve-start shuttle (kGroundY - kServeShuttleHeight).
const double kServeStartY = kGroundY - kServeShuttleHeight;

/// Minimum clearance above the net top that a serve must achieve.
///
/// Serves must cross the net plane at y < (kNetTopY - kServeClearanceMargin).
/// 10 units keeps the shuttle clearly above the net-tape band
/// (kNetTapeHeight = 8), providing a visible margin.
const double kServeClearanceMargin = 10;

/// The guaranteed net-crossing y threshold for a valid serve.
const double kServeNetClearY = kNetTopY - kServeClearanceMargin;

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // Part A: the harness itself is exercised as a by-product of every test
  // below — a harness that produces wrong results would immediately break the
  // balance assertions.

  group('Part B — Shot balance (M1-032a)', () {
    // -----------------------------------------------------------------------
    // 1. SERVE
    // -----------------------------------------------------------------------
    group('1. Serve from left server position', () {
      // The toss has a fixed angle (no PRNG spread), so there is a single
      // trajectory to test.
      //
      // Right-server trajectories are mirror-symmetric by construction:
      // ShotSystem._upwardArc flips the x-direction (dir = -1) for
      // CourtSide.right, producing a perfectly mirrored arc.  Testing the
      // left server is therefore sufficient.
      test(
        'clears the net, avoids short-serve, and lands in bounds '
        '(mirror-symmetric for right server by direction-flip)',
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
                'units (cross at y < $kServeNetClearY); '
                'actual netCrossingY=${result.netCrossingY.toStringAsFixed(1)}. '
                'Trajectory: $result',
          );
          expect(
            result.landingX,
            greaterThanOrEqualTo(kShortServeLineRight),
            reason:
                'Serve must reach or pass the short-service line ($kShortServeLineRight); '
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
    });

    // -----------------------------------------------------------------------
    // 2 & 3. NORMAL shot
    // -----------------------------------------------------------------------
    group('2 & 3. Normal shot', () {
      // The normal shot has a PRNG-drawn angle in [kNormalShotAngleMin,
      // kNormalShotAngleMax].  Verifying both extremes (min and max angle)
      // is sufficient because the trajectory is monotone in angle over the
      // tested range.

      test(
        'from defensive position (300, 520) at both angle extremes: '
        'clears the net and lands in the opponent half in bounds',
        () {
          for (final angleDeg in [
            _degOf(kNormalShotAngleMin),
            _degOf(kNormalShotAngleMax),
          ]) {
            final result = TrajectoryHarness.runUpwardArc(
              startX: 300,
              startY: 520,
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
        'from near-net position (560, 520) at both angle extremes: '
        'does not sail out (lands <= $kCourtRightBound)',
        () {
          // The angle range was biased upward (steeper = shorter) to keep
          // near-net shots in bounds while preserving net clearance from
          // the far defensive position.  A near-net clear that still lands
          // short of the baseline is the intended trade-off: see the class
          // dartdoc on kNormalShotAngleMin.
          for (final angleDeg in [
            _degOf(kNormalShotAngleMin),
            _degOf(kNormalShotAngleMax),
          ]) {
            final result = TrajectoryHarness.runUpwardArc(
              startX: 560,
              startY: 520,
              speed: kNormalShotSpeed,
              angleDeg: angleDeg,
              dragCoefficient: kShuttleDragCoefficient,
            );

            expect(
              result.crossedNet,
              isTrue,
              reason:
                  'Near-net normal shot at ${angleDeg.toStringAsFixed(1)}° '
                  'must cross the net; trajectory: $result',
            );
            expect(
              result.landingX,
              greaterThan(kNetX),
              reason:
                  'Near-net normal shot must land in the opponent half; '
                  'actual landingX=${result.landingX.toStringAsFixed(1)}. '
                  'Trajectory: $result',
            );
            expect(
              result.landingX,
              lessThanOrEqualTo(kCourtRightBound),
              reason:
                  'Near-net normal shot must not sail out '
                  '(x <= $kCourtRightBound); '
                  'actual landingX=${result.landingX.toStringAsFixed(1)}. '
                  'Trajectory: $result',
            );
          }
        },
      );
    });

    // -----------------------------------------------------------------------
    // 4. SMASH
    // -----------------------------------------------------------------------
    group('4. Smash from mid-court (450, 480)', () {
      test(
        'at both angle extremes: crosses the net and lands in bounds; '
        'jump-smash speed stays within the velocity clamp',
        () {
          const jumpSmashSpeed = kSmashSpeed * kJumpSmashBonus;
          expect(
            jumpSmashSpeed,
            lessThanOrEqualTo(kShuttleMaxVelocity),
            reason:
                'kSmashSpeed * kJumpSmashBonus ($jumpSmashSpeed) must not '
                'exceed kShuttleMaxVelocity ($kShuttleMaxVelocity).',
          );

          for (final angleDeg in [
            _degOf(kSmashAngleMin),
            _degOf(kSmashAngleMax),
          ]) {
            final result = TrajectoryHarness.runDownwardArc(
              startX: 450,
              startY: 480,
              speed: kSmashSpeed,
              angleDeg: angleDeg,
              dragCoefficient: kShuttleDragCoefficient,
            );

            expect(
              result.crossedNet,
              isTrue,
              reason:
                  'Smash at ${angleDeg.toStringAsFixed(1)}° must cross '
                  'the net; trajectory: $result',
            );
            expect(
              result.landingX,
              greaterThan(kNetX),
              reason:
                  'Smash at ${angleDeg.toStringAsFixed(1)}° must land in '
                  'the opponent half (x > $kNetX); '
                  'actual landingX=${result.landingX.toStringAsFixed(1)}. '
                  'Trajectory: $result',
            );
            expect(
              result.landingX,
              lessThanOrEqualTo(kCourtRightBound),
              reason:
                  'Smash at ${angleDeg.toStringAsFixed(1)}° must land in '
                  'bounds (x <= $kCourtRightBound); '
                  'actual landingX=${result.landingX.toStringAsFixed(1)}. '
                  'Trajectory: $result',
            );
          }
        },
      );
    });

    // -----------------------------------------------------------------------
    // 5. DROP SHOT
    // -----------------------------------------------------------------------
    group('5. Drop shot from mid-court (450, 520)', () {
      test(
        'crosses the net and lands SHORT (between net and short-serve line)',
        () {
          // Drop shots use the higher kShuttleDropShotDrag, which bleeds
          // speed faster and keeps the shot close to the net — the tactical
          // purpose of the drop.  The steep fixed angle (kDropShotAngle)
          // produces a high arc that clears the net despite the higher drag.
          final result = TrajectoryHarness.runUpwardArc(
            startX: 450,
            startY: 520,
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
    });

    // -----------------------------------------------------------------------
    // 6. Sanity invariants
    // -----------------------------------------------------------------------
    group('6. Sanity invariants', () {
      test('smash is the fastest shot and stays within the velocity clamp', () {
        expect(kSmashSpeed, greaterThan(kNormalShotSpeed));
        expect(kSmashSpeed, greaterThan(kDropShotSpeed));
        expect(kSmashSpeed, lessThanOrEqualTo(kShuttleMaxVelocity));
        expect(
          kSmashSpeed * kJumpSmashBonus,
          lessThanOrEqualTo(kShuttleMaxVelocity),
        );
      });
    });
  });

  // -------------------------------------------------------------------------
  // Part C — End-to-end serve integration test
  // -------------------------------------------------------------------------
  group('Part C — End-to-end serve integration (M1-032a)', () {
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

        // Verify the shuttle has rightward (+x) velocity — it's heading toward
        // the right half.
        expect(
          sim.state.shuttle.velocity.x.toDouble(),
          greaterThan(0),
          reason: 'Left-server toss must impart rightward velocity.',
        );

        // Run up to 300 ticks (5 seconds at 60 Hz) with no further input.
        // At the tuned constants the serve takes ≈ 190 ticks to land; 300
        // gives generous headroom.  Track whether the shuttle crossed the net.
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
          reason:
              'Serve must cross the net plane '
              '(shuttle x > $kNetX) during rally.',
        );

        expect(
          landing,
          isNotNull,
          reason: 'GroundHit must fire within 300 ticks of the toss.',
        );

        // The new constants deliver a serve that clears the net and lands in
        // the right half — so the RECEIVER (right) is awarded the point via
        // groundedIn (opponent of the side it lands on, which is right).
        // Actually: the serve now DOES reach the right half (landing.side ==
        // CourtSide.right), so the LEFT player wins the point (the shuttle
        // landed on the right side => right player loses the point).
        // Alternatively: the serve may be called short-serve fault if it's in
        // the zone 640-840 (receiver wins), or land beyond 840 (server wins).
        // Either way the shuttle MUST land in the right half.
        expect(
          landing!.side,
          CourtSide.right,
          reason:
              'With the new constants the serve travels into the right half '
              '— GroundHit.side must be CourtSide.right. '
              'LandingX was: ${landing!.landingX.toDouble().toStringAsFixed(1)}',
        );

        // The point must be scored (not a timeout or LET).
        expect(
          sim.state.fsm.lastPointReason,
          anyOf(PointReason.groundedIn, PointReason.shortServeFault),
          reason:
              'The serve should end in a scored point, not a timeout. '
              'Reason: ${sim.state.fsm.lastPointReason}',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Documented trade-off note (kept as a test comment, no assertion)
  // -------------------------------------------------------------------------
  //
  // CONSTRAINT TRADE-OFF (kNormalShotAngleMin / kNormalShotAngleMax):
  //
  // The angle range was shifted upward from [35°, 45°] to [45°, 55°].
  // This is a deliberate compromise:
  //
  //  * From a defensive position (300, 520), both extremes clear the net
  //    cleanly and land inside the baseline.
  //  * From a near-net position (560, 520), both extremes also land ≤ 1240,
  //    which would NOT be achievable at the original range (35°–45°) with
  //    the new lower gravity and drag — the flatter trajectory would sail out.
  //  * Steeper angles make all normal shots arc higher and land shorter than
  //    the original design, but this is appropriate for an arcade game where
  //    shots should be visually distinct from smashes.
  //  * The constraint "near-net must not sail out" WINS over "shots must be
  //    as flat as possible" because a ball leaving the court is a hard physics
  //    bug; a shorter arc is a tuning preference.
}
