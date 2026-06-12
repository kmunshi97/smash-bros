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

/// Maximum flight time (ticks) for a serve.
///
/// Empirically: at kTossSpeed=13, kTossAngle=43°, kShuttleGravity=0.14,
/// the serve from (200, 520) is airborne for 117 ticks.  The ceiling of 135
/// ticks (2.25 s) locks in the snappy-feel target and guards against future
/// constants accidentally re-introducing floatiness.
const int kServeMaxFlightTicks = 135;

/// Maximum flight time (ticks) for a normal clear/drive shot.
///
/// Empirically: at kNormalShotSpeed=12, kShuttleGravity=0.14, the defensive
/// shot from (300, 520) is airborne for 114 ticks (min angle) to 128 ticks
/// (max angle).  The ceiling of 135 ticks (2.25 s) is the snappy-feel target.
const int kNormalMaxFlightTicks = 135;

/// Maximum flight time (ticks) for a drop shot.
///
/// Empirically: at kDropShotSpeed=9, kDropShotAngle=65°, kShuttleGravity=0.14,
/// the drop from (450, 520) is airborne for 115 ticks.  The ceiling of 120
/// ticks (2.0 s) keeps the drop shot feeling tight and distinct from a clear.
const int kDropMaxFlightTicks = 120;

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

      test(
        'flight time ≤ $kServeMaxFlightTicks ticks (snappy-feel target: no more than 2.25 s in the air)',
        () {
          // Empirical baseline: kTossSpeed=13 @43°, kShuttleGravity=0.14
          // → 117 ticks.  Ceiling guards against future gravity regressions.
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
                '(≤ ${kServeMaxFlightTicks / 60} s at 60 Hz) to feel snappy; '
                'actual=${result.flightTicks} ticks. '
                'Raise kTossSpeed or kShuttleGravity if this fails. '
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
        'from defensive position (300, 520) at both angle extremes: '
        'flight time ≤ $kNormalMaxFlightTicks ticks (snappy-feel target)',
        () {
          // Empirical baseline: kNormalShotSpeed=12, kShuttleGravity=0.14
          // → 114 ticks @ 45°, 128 ticks @ 55°.
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
      // Near-net normal shot — option (b): net fault documented as intentional
      // -----------------------------------------------------------------------
      //
      // CONSTRAINT ANALYSIS (M1-032a retune):
      //
      // From the near-net position (560, 520), the shuttle starts only 80 units
      // from the net (x = 640) and 170 units below the net top (y = 350).
      // At kNormalShotSpeed = 12 and kShuttleGravity = 0.14 the shuttle cannot
      // arc high enough over those 80 horizontal units to clear the net:
      //
      //   min angle (45°): net crossing y ≈ 447 — below the tape band bottom
      //                    (kNetTopY + kNetTapeHeight = 358).
      //   max angle (55°): net crossing y ≈ 417 — also below the tape bottom.
      //
      // This is OPTION (b): "crosses below the tape — net fault; acceptable
      // because clearing a LOW shuttle right at the net is risky in real
      // badminton."  Documented here instead of left hand-waved.
      //
      // WHY THIS IS CORRECT:
      //   - A player standing at x = 560 hitting a shuttle at waist height
      //     (y = 520) barely has room to arc the shuttle over a 350-height net
      //     that is only 80 units away.  In real badminton this shot is a
      //     net-cord error unless executed as a cross-court dribble (not
      //     modelled).
      //   - The constraint "near-net must not sail out" no longer wins over
      //     "the shot must clear the net", because option (b) is a VALID
      //     physical outcome rather than a bug: hitting into the net is a
      //     mistake the PLAYER makes, not a physics fault.
      //   - We prefer option (b) over lowering the shot speed (which would
      //     either make defensive shots bounce off the net or sail out) or
      //     raising the angle beyond 55° (which would make all shots arch so
      //     high they look comically floaty).
      test(
        'from near-net position (560, 520) at both angle extremes: '
        'OPTION (b) — crosses below the tape band (net fault, intentional)',
        () {
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

            // The shuttle must cross the net plane (x = kNetX) — it does
            // reach x = 640, just too low.
            expect(
              result.crossedNet,
              isTrue,
              reason:
                  'Near-net normal at ${angleDeg.toStringAsFixed(1)}° must '
                  'at least reach the net plane; trajectory: $result',
            );

            // Crossing y must be BELOW the tape bottom — i.e. a net-body hit,
            // not a clean passage.  kNetTopY + kNetTapeHeight = 358.
            expect(
              result.netCrossingY,
              greaterThan(kNetTopY + kNetTapeHeight),
              reason:
                  'Near-net normal at ${angleDeg.toStringAsFixed(1)}° is '
                  'expected to be a net fault (crossing y > ${kNetTopY + kNetTapeHeight}); '
                  'actual netCrossingY=${result.netCrossingY.toStringAsFixed(1)}. '
                  'If this fails the physics changed — re-evaluate option (a)/(b). '
                  'Trajectory: $result',
            );
          }
        },
      );
    });

    // -----------------------------------------------------------------------
    // 4. SMASH — jump contact (positive) and grounded contact (negative)
    // -----------------------------------------------------------------------
    group('4. Smash', () {
      test(
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
        },
      );

      test(
        'from mid-court JUMP contact (450, 290) at both angle extremes: '
        'crosses net above tape and lands in opponent half (preferably ≤ 1240)',
        () {
          // Launch position: x=450 (mid-court), y=290 (racquet at jump apex).
          // kPlayerJumpApexY = 380 (feet), hitbox height 80 → top = 300,
          // racquet reach 40 → contact y ≈ 260–290.  290 is a conservative
          // (lower) estimate ensuring the test covers realistic geometry.
          //
          // Empirical (kSmashSpeed=16, kShuttleGravity=0.14, kShuttleDragCoefficient=0.001):
          //   min angle (10°): land ≈ 1089, netCrossY ≈ 336 ✓
          //   max angle (13°): land ≈ 1049, netCrossY ≈ 347 ✓
          for (final angleDeg in [
            _degOf(kSmashAngleMin),
            _degOf(kSmashAngleMax),
          ]) {
            final result = TrajectoryHarness.runDownwardArc(
              startX: 450,
              startY: 290,
              speed: kSmashSpeed,
              angleDeg: angleDeg,
              dragCoefficient: kShuttleDragCoefficient,
            );

            expect(
              result.crossedNet,
              isTrue,
              reason:
                  'Jump smash at ${angleDeg.toStringAsFixed(1)}° from '
                  '(450, 290) must cross the net; trajectory: $result',
            );
            expect(
              result.netCrossingY,
              lessThan(kNetTopY),
              reason:
                  'Jump smash at ${angleDeg.toStringAsFixed(1)}° must cross '
                  'the net ABOVE the tape (netCrossingY < $kNetTopY); '
                  'actual=${result.netCrossingY.toStringAsFixed(1)}. '
                  'Trajectory: $result',
            );
            expect(
              result.landingX,
              greaterThan(kNetX),
              reason:
                  'Jump smash at ${angleDeg.toStringAsFixed(1)}° must land '
                  'in the opponent half (x > $kNetX); '
                  'actual landingX=${result.landingX.toStringAsFixed(1)}. '
                  'Trajectory: $result',
            );
            // Landing ≤ 1240 is preferred (both angle extremes achieve it at
            // the current constants) but not a hard rule — a hard smash that
            // sails slightly out is a player error, not a physics fault.
            expect(
              result.landingX,
              lessThanOrEqualTo(kCourtRightBound),
              reason:
                  'Jump smash at ${angleDeg.toStringAsFixed(1)}° lands at '
                  'x=${result.landingX.toStringAsFixed(1)}, which is beyond '
                  '$kCourtRightBound. At the current constants both extremes '
                  'land ≤ 1240; if this fails recheck kSmashAngleMax. '
                  'Trajectory: $result',
            );
          }
        },
      );

      test(
        'NEGATIVE: grounded contact (450, 520) at both angle extremes: '
        'crosses net BELOW the tape band — this is a net fault in real play',
        () {
          // Design intent: smashing a LOW shuttle from mid-court (waist height,
          // y = 520) is a mistake.  The geometry is: start y = 520, net top
          // y = 350, tape bottom y = 358.  A downward smash from this height
          // does not have the vertical clearance to arc over the net; it hits
          // the net body.  This test locks in that physical truth.
          //
          // Empirical (kSmashSpeed=16, kShuttleGravity=0.14):
          //   min angle (10°): netCrossY ≈ 566 >> 358 ✓
          //   max angle (13°): netCrossY ≈ 577 >> 358 ✓
          for (final angleDeg in [
            _degOf(kSmashAngleMin),
            _degOf(kSmashAngleMax),
          ]) {
            final result = TrajectoryHarness.runDownwardArc(
              startX: 450,
              startY: 520,
              speed: kSmashSpeed,
              angleDeg: angleDeg,
              dragCoefficient: kShuttleDragCoefficient,
            );

            expect(
              result.crossedNet,
              isTrue,
              reason:
                  'Grounded smash at ${angleDeg.toStringAsFixed(1)}° must '
                  'at least reach the net plane; trajectory: $result',
            );
            // Crossing y > 358 means BELOW the tape bottom — a net fault.
            expect(
              result.netCrossingY,
              greaterThan(kNetTopY + kNetTapeHeight),
              reason:
                  'Grounded smash at ${angleDeg.toStringAsFixed(1)}° from '
                  '(450, 520) must be a net fault '
                  '(netCrossingY > ${kNetTopY + kNetTapeHeight}); '
                  'actual=${result.netCrossingY.toStringAsFixed(1)}. '
                  'If this passes clean, a grounded smash unfairly escapes the '
                  'net — recheck kSmashAngleMin or kShuttleGravity. '
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
          // Drop shots use the same kShuttleDropShotDrag as normal flight
          // (both = 0.001) at the new gravity (0.14).  The steeper fixed angle
          // (65°, kDropShotAngle) and speed 9 produce a high arc that clears
          // the net and drops inside the short-service zone without a separate
          // elevated drag coefficient.  Empirical: land ≈ 778, netCrossY ≈ 342,
          // 115 ticks.
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

      test(
        'flight time ≤ $kDropMaxFlightTicks ticks (snappy-feel target)',
        () {
          // Empirical: 115 ticks at kDropShotSpeed=9, kDropShotAngle=65°,
          // kShuttleGravity=0.14.
          final result = TrajectoryHarness.runUpwardArc(
            startX: 450,
            startY: 520,
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

      test('gravity is at least 0.10 (anti-floatiness guard)', () {
        // Gravity below 0.10 was measured to produce 3+ second rally shots
        // (177–198 ticks) that feel like slow motion in arcade play.
        // This assertion prevents a well-intentioned but regressive retune.
        expect(
          kShuttleGravity,
          greaterThanOrEqualTo(0.10),
          reason:
              'kShuttleGravity ($kShuttleGravity) is below 0.10; anything '
              'below this threshold produces floaty 3-second shots. '
              'See M1-032a retune for measurement details.',
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
        // At the retuned constants the serve takes ≈ 117 ticks to land; 300
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
  // CONSTRAINT TRADE-OFF (M1-032a retune — kShuttleGravity, kNormalShotSpeed,
  //   kTossSpeed, kDropShotSpeed, kDropShotAngle, kSmashAngleMax):
  //
  // MEASURED PROBLEM (pre-retune constants: gravity=0.06, normal speed=8):
  //   Serve:  190 ticks (3.2 s)  — slow-motion
  //   Normal: 177–198 ticks (3.0 s) — slow-motion
  //   Drop:   176 ticks (2.9 s)  — slow-motion
  //
  // SOLUTION:
  //   Raise kShuttleGravity from 0.06 → 0.14 (primary lever on flight time).
  //   Re-derive launch speeds so every shot still clears the net:
  //     - kNormalShotSpeed: 8 → 12 (needed at g=0.14 to clear net from y=520)
  //     - kTossSpeed:       9 → 13 (same reason, serve start x=200 y=520)
  //     - kTossAngle:       45° → 43° (slightly shallower for landing range)
  //     - kDropShotSpeed:   7 → 9  (needed at g=0.14 and 65° to clear net)
  //     - kDropShotAngle:   60° → 65° (steeper compensates for short distance)
  //     - kShuttleDropShotDrag: 0.002 → 0.001 (drop uses normal drag; stronger
  //       gravity + steep angle provide sufficient landing-zone control)
  //     - kSmashAngleMax:   25° → 13° (geometry: from correct jump contact y=290
  //       at g=0.14, angles > 13° produce net-body hits; old test from y=480
  //       was physically wrong — 130 units below the net top)
  //
  // ACHIEVED TARGETS:
  //   Serve:  117 ticks (1.95 s) ≤ 135 ✓
  //   Normal: 114–128 ticks (1.9–2.1 s) ≤ 135 ✓
  //   Drop:   115 ticks (1.92 s) ≤ 120 ✓
  //
  // NEAR-NET NORMAL (option b, intentional):
  //   From (560, 520) at 45°: net crossing y ≈ 447 → net fault.
  //   From (560, 520) at 55°: net crossing y ≈ 417 → net fault.
  //   REASON: 80 horizontal units is not enough run-up at g=0.14/speed=12 to
  //   arc a shuttle 170 vertical units over the net.  This is CORRECT badminton
  //   physics — a waist-height shot at the net is a net-cord error.
  //
  // SMASH GEOMETRY FIX:
  //   Old test (450, 480): launch 130 u below net top — physically incoherent.
  //   New test (450, 290): racquet reach at jump apex (feet y=380, hitbox 80,
  //   racquet reach 40 → y ≈ 260–290).  At g=0.14 angles [10°,13°] clear;
  //   14° just clips the tape.  Grounded (450, 520) → always net fault ✓.
}
