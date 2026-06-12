import 'dart:math' as math;

import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/shuttle.dart';
import 'package:smash_bros/engine/math/fix.dart';
import 'package:smash_bros/engine/math/fix_vec2.dart';

/// The outcome of simulating a shuttle trajectory from launch until it hits the
/// ground.
///
/// All positions are in game-unit coordinates (+y downward, matching the engine
/// convention).
final class TrajectoryResult {
  /// Creates a [TrajectoryResult] directly; prefer [TrajectoryHarness.runUpwardArc].
  const TrajectoryResult({
    required this.landingX,
    required this.crossedNet,
    required this.netCrossingY,
  });

  /// The x coordinate at which the shuttle reached the ground plane
  /// ([kGroundY]).
  final double landingX;

  /// Whether the shuttle's sweep crossed the net plane ([kNetX]) from left to
  /// right before landing.
  final bool crossedNet;

  /// The interpolated y at which the shuttle's sweep crossed [kNetX].
  ///
  /// Meaningful only when [crossedNet] is `true`; returns [double.nan]
  /// otherwise.
  final double netCrossingY;

  @override
  String toString() =>
      'TrajectoryResult('
      'landingX=${landingX.toStringAsFixed(1)}, '
      'crossedNet=$crossedNet, '
      'netCrossingY=${crossedNet ? netCrossingY.toStringAsFixed(1) : 'n/a'})';
}

/// A pure-Dart trajectory harness that drives [Shuttle.integrate] until the
/// shuttle reaches [kGroundY], then reports [TrajectoryResult].
///
/// ## Purpose
///
/// This harness uses the **real** [Shuttle.integrate] implementation (gravity,
/// quadratic drag, clamping — exactly the code the live simulation runs), so
/// the constants validated here are guaranteed to agree with the actual physics
/// pipeline.  Hand-computed analytic estimates would diverge when the discrete
/// integration drifts from the closed form.
///
/// ## Usage
///
/// ```dart
/// final result = TrajectoryHarness.runUpwardArc(
///   startX: 200, startY: 520,
///   speed: kTossSpeed,
///   angleDeg: kTossAngle * 180 / pi,
///   dragCoefficient: kShuttleDragCoefficient,
/// );
/// expect(result.netCrossingY, lessThan(340));
/// ```
abstract final class TrajectoryHarness {
  /// Simulates a shuttle launched with an **upward arc** (negative vy, so the
  /// shuttle initially rises) and returns its [TrajectoryResult].
  ///
  /// [angleDeg] is the launch elevation above horizontal in **degrees**.
  /// [dragCoefficient] selects normal ([kShuttleDragCoefficient]) or drop
  /// ([kShuttleDropShotDrag]) drag.
  ///
  /// The shuttle is launched toward **+x** (left-to-right, as the left player
  /// hits rightward).  Right-side launches are mirror-symmetric by construction
  /// — testing left is sufficient; a comment at each call site notes this.
  static TrajectoryResult runUpwardArc({
    required double startX,
    required double startY,
    required double speed,
    required double angleDeg,
    required double dragCoefficient,
  }) {
    final angle = Fix.of(angleDeg * math.pi / 180.0);
    final vx = Fix.of(math.cos(angle.toDouble()) * speed);
    final vy = Fix.of(-math.sin(angle.toDouble()) * speed); // negative = upward
    return _run(startX, startY, vx, vy, Fix.of(dragCoefficient));
  }

  /// Simulates a shuttle launched with a **downward arc** (positive vy, so the
  /// shuttle angles toward the ground immediately — a smash).
  ///
  /// [angleDeg] is the depression angle below horizontal in **degrees**.
  static TrajectoryResult runDownwardArc({
    required double startX,
    required double startY,
    required double speed,
    required double angleDeg,
    required double dragCoefficient,
  }) {
    final angle = Fix.of(angleDeg * math.pi / 180.0);
    final vx = Fix.of(math.cos(angle.toDouble()) * speed);
    final vy = Fix.of(
      math.sin(angle.toDouble()) * speed,
    ); // positive = downward
    return _run(startX, startY, vx, vy, Fix.of(dragCoefficient));
  }

  // ---------------------------------------------------------------------------
  // Implementation
  // ---------------------------------------------------------------------------

  /// Core simulation loop: ticks [Shuttle.integrate] until the shuttle reaches
  /// the ground plane or the tick budget is exhausted.
  static TrajectoryResult _run(
    double startX,
    double startY,
    Fix vx,
    Fix vy,
    Fix drag,
  ) {
    final shuttle = Shuttle(
      position: FixVec2(Fix.of(startX), Fix.of(startY)),
      velocity: FixVec2(vx, vy),
    );

    // Generous tick budget: at the lowest conceivable speed (drag-decaying to
    // near zero), the shuttle still lands within a few thousand ticks given
    // gravity > 0.  5000 is far beyond any realistic trajectory.
    const maxTicks = 5000;
    var crossedNet = false;
    var netCrossingY = double.nan;

    for (var tick = 0; tick < maxTicks; tick++) {
      final prevX = shuttle.position.x.toDouble();
      final prevY = shuttle.position.y.toDouble();

      shuttle.integrate(dragCoefficient: drag);

      final currX = shuttle.position.x.toDouble();
      final currY = shuttle.position.y.toDouble();

      // Net crossing: sweep from prevX < kNetX to currX >= kNetX.
      if (!crossedNet && prevX < kNetX && currX >= kNetX) {
        // Linear interpolation to find y at x == kNetX.
        final t = (kNetX - prevX) / (currX - prevX);
        netCrossingY = prevY + t * (currY - prevY);
        crossedNet = true;
      }

      // Ground hit: shuttle reached or passed the ground plane.
      if (currY >= kGroundY) {
        // Interpolate to find x at y == kGroundY (avoids over-shoot bias).
        final t = (kGroundY - prevY) / (currY - prevY);
        final landingX = prevX + t * (currX - prevX);
        return TrajectoryResult(
          landingX: landingX,
          crossedNet: crossedNet,
          netCrossingY: crossedNet ? netCrossingY : double.nan,
        );
      }
    }

    // Tick budget exhausted — return current position as landing estimate.
    // This path indicates a bug in the constants (gravity too low or drag too
    // high and the shuttle never reaches the ground), not a normal outcome.
    return TrajectoryResult(
      landingX: shuttle.position.x.toDouble(),
      crossedNet: crossedNet,
      netCrossingY: crossedNet ? netCrossingY : double.nan,
    );
  }
}
