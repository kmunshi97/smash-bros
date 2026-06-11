import 'package:smash_bros/engine/entities/tunables.dart';
import 'package:smash_bros/engine/math/fix.dart';
import 'package:smash_bros/engine/math/fix_vec2.dart';

/// The shuttlecock: the single projectile the whole match revolves around.
///
/// State is value-semantic and mutable in place; [copy] produces a deep,
/// independent snapshot for the rollback buffer. All quantities are expressed
/// in *per-tick* units (the simulation runs at a fixed 60 Hz), so velocity is
/// "game units per tick" and gravity is "units per tick per tick".
///
/// Coordinate convention follows [FixVec2]: +x rightward, +y downward, so
/// gravity is a positive y acceleration.
final class Shuttle {
  /// Creates a shuttle at [position] with the given [velocity].
  ///
  /// [previousPosition] defaults to [position] so a freshly spawned shuttle
  /// reports a zero-length sweep segment until its first [integrate] step.
  Shuttle({
    required this.position,
    this.velocity = FixVec2.zero,
    FixVec2? previousPosition,
  }) : previousPosition = previousPosition ?? position;

  /// The shuttle's current centre position.
  FixVec2 position;

  /// The shuttle's current velocity, in game units per tick.
  FixVec2 velocity;

  /// The position recorded at the start of the most recent [integrate] step.
  ///
  /// The swept-collision system treats `previousPosition -> position` as the
  /// segment the shuttle traversed this tick, which is required to catch
  /// fast shuttles tunnelling through thin colliders (the net, rackets).
  FixVec2 previousPosition;

  /// Advances the shuttle by exactly one tick of semi-implicit Euler.
  ///
  /// Order of operations:
  /// 1. capture [previousPosition] for the sweep segment;
  /// 2. apply gravity (`velocity.y += gravity`, pulling downward = +y);
  /// 3. apply quadratic air drag opposing motion:
  ///    `velocity -= velocity * (dragCoefficient * |velocity|)`, i.e. a force
  ///    of `-k * |v| * v`. At `|v| == 0` the scale factor is zero, so the
  ///    stationary case needs no normalisation and is safe;
  /// 4. clamp the speed to [Tunables.shuttleMaxVelocity] (M1-003 stability
  ///    safeguard, so a mis-tuned shot can never explode the sim);
  /// 5. integrate position (`position += velocity`).
  ///
  /// [dragCoefficient] is a parameter rather than a constant because drop
  /// shots use a higher coefficient (`kShuttleDropShotDrag`) to bleed speed
  /// quickly near the net.
  void integrate({required Fix dragCoefficient}) {
    previousPosition = position;

    // 2. Gravity (downward is +y).
    velocity = FixVec2(velocity.x, velocity.y + Tunables.shuttleGravity);

    // 3. Quadratic drag opposing motion: -k * |v| * v.
    final dragScale = dragCoefficient * velocity.magnitude;
    velocity = velocity - velocity.scale(dragScale);

    // 4. Stability clamp.
    velocity = velocity.clampMagnitude(Tunables.shuttleMaxVelocity);

    // 5. Position update.
    position = position + velocity;
  }

  /// Sets the shuttle's velocity, used by the shot system when a player hits.
  ///
  /// Deliberately a verb-named method rather than a setter: at call sites
  /// "the racket launches the shuttle" reads as an event, not a property
  /// assignment, and keeps room for future launch-time bookkeeping.
  // ignore: use_setters_to_change_properties
  void launch(FixVec2 newVelocity) {
    velocity = newVelocity;
  }

  /// A deep, independent copy for the rollback snapshot buffer.
  Shuttle copy() => Shuttle(
    position: position,
    velocity: velocity,
    previousPosition: previousPosition,
  );
}
