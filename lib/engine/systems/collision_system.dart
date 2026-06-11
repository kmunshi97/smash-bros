import 'package:meta/meta.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/entities/shuttle.dart';
import 'package:smash_bros/engine/entities/tunables.dart';
import 'package:smash_bros/engine/math/fix.dart';
import 'package:smash_bros/engine/math/fix_vec2.dart';

/// Something the shuttle's sweep ran into this tick.
///
/// Events are pure geometric facts: the [CollisionSystem] knows where the
/// shuttle went and what planes it crossed, but it does not know badminton
/// rules. The match-rules layer (a later PR) consumes these events to decide
/// scoring, faults and rally transitions.
@immutable
sealed class CollisionEvent {
  /// Const base constructor for the sealed hierarchy.
  const CollisionEvent();
}

/// The sweep crossed the net plane against the *solid body* of the net — below
/// the net-cord (tape) band, i.e. at a y strictly greater than
/// [Court.netTopY] + the tape height.
///
/// A net-body hit stops the shuttle dead at the net (see [CollisionSystem]).
@immutable
final class NetBodyHit extends CollisionEvent {
  /// Creates a net-body hit recording the [crossing] point on the net plane.
  const NetBodyHit(this.crossing);

  /// The point at which the sweep crossed the net plane (`x == netX`).
  final FixVec2 crossing;

  @override
  bool operator ==(Object other) =>
      other is NetBodyHit && other.crossing == crossing;

  @override
  int get hashCode => crossing.hashCode;

  @override
  String toString() => 'NetBodyHit($crossing)';
}

/// The sweep crossed the net plane within the net-cord (tape) band
/// `[netTopY, netTopY + tapeHeight]`.
///
/// A net-cord hit clips the tape and continues, damped (see [CollisionSystem]).
@immutable
final class NetCordHit extends CollisionEvent {
  /// Creates a net-cord hit recording the [crossing] point on the net plane.
  const NetCordHit(this.crossing);

  /// The point at which the sweep crossed the net plane (`x == netX`).
  final FixVec2 crossing;

  @override
  bool operator ==(Object other) =>
      other is NetCordHit && other.crossing == crossing;

  @override
  int get hashCode => crossing.hashCode;

  @override
  String toString() => 'NetCordHit($crossing)';
}

/// The sweep reached the ground plane (`y >= groundY`).
///
/// This is the line-call input: [landingX] is the x interpolated at the exact
/// ground crossing, [side] is which half of the court it landed on, and
/// [isInBounds] is whether that x lies within the inclusive court bounds
/// (on the line counts as IN).
@immutable
final class GroundHit extends CollisionEvent {
  /// Creates a ground hit with the interpolated [landingX], the [side] of the
  /// court it landed on, and whether it was [isInBounds].
  const GroundHit({
    required this.landingX,
    required this.side,
    required this.isInBounds,
  });

  /// The x coordinate interpolated at the exact ground crossing.
  final Fix landingX;

  /// The side of the court the landing x falls on (via [Court.sideOfX]).
  final CourtSide side;

  /// Whether [landingX] lies within the inclusive court bounds.
  final bool isInBounds;

  @override
  bool operator ==(Object other) =>
      other is GroundHit &&
      other.landingX == landingX &&
      other.side == side &&
      other.isInBounds == isInBounds;

  @override
  int get hashCode => Object.hash(landingX, side, isInBounds);

  @override
  String toString() =>
      'GroundHit(landingX: $landingX, side: $side, isInBounds: $isInBounds)';
}

/// Swept-collision resolution for the shuttle against the net and the ground.
///
/// ## Contract
///
/// The shuttle has *already* integrated this tick. [resolve] inspects the
/// sweep segment `shuttle.previousPosition -> shuttle.position`, returns the
/// geometric events that occurred (ordered by ascending sweep parameter `t`),
/// and applies the physical responses to the shuttle in place. It knows
/// geometry, not badminton rules.
///
/// ## Tick order
///
/// Runs after the entity-integration step (the shuttle moved) and before the
/// match-rules step (which reads the returned events). It is the bridge from
/// "where the shuttle is" to "what just happened".
///
/// ## Conventions and simplifications
///
/// * **Start exactly on the net plane** (`P0.x == netX`): the start point is
///   treated as belonging to its *previous* side. Concretely, we only report a
///   net crossing when the x components strictly straddle the plane, i.e. the
///   sign of `(x - netX)` differs between the endpoints. A sweep that starts on
///   the plane and moves away does not re-trigger; a degenerate sweep with
///   `d.x == 0` (purely vertical) never crosses the net and is guarded against
///   divide-by-zero.
/// * **Net-cord continuation is approximate**: on a net-cord hit the shuttle's
///   velocity is damped but its position is *not* re-projected for the damped
///   remainder of the tick — it continues to the already-integrated
///   `shuttle.position`. This one-tick inaccuracy is deterministic and
///   accepted; the ground check for the same tick uses the *original* segment.
/// * **Net-body hits consume the sweep**: the shuttle is parked at the net, so
///   no later event (e.g. a ground hit) is reported for that tick.
abstract final class CollisionSystem {
  /// Small inset that nudges a net-body-stopped shuttle back onto the hitter's
  /// side of the net plane so it never reads as exactly on the line.
  static const Fix _netEpsilon = Fix.of(0.5);

  /// Resolves the shuttle's sweep this tick against the net and the ground,
  /// mutating [shuttle] with the physical response and returning the ordered
  /// list of [CollisionEvent]s (ascending sweep parameter `t`).
  static List<CollisionEvent> resolve(Shuttle shuttle, Court court) {
    final p0 = shuttle.previousPosition;
    final p1 = shuttle.position;
    final d = p1 - p0;

    final events = <CollisionEvent>[];

    // -- Net plane crossing --------------------------------------------------
    // Only a strict sign change of (x - netX) counts as a crossing, so a sweep
    // starting exactly on the plane belongs to its previous side and a purely
    // vertical sweep (d.x == 0) never crosses (guarding the division below).
    final fromLeft = p0.x < court.netX;
    final toLeft = p1.x < court.netX;
    final crossesNet = d.x != Fix.zero && fromLeft != toLeft;

    Fix? netT;
    FixVec2? netCrossing;
    if (crossesNet) {
      netT = (court.netX - p0.x) / d.x;
      netCrossing = FixVec2(court.netX, p0.y + netT * d.y);
    }

    // -- Ground crossing -----------------------------------------------------
    // Only when the sweep starts above the ground and ends at or below it.
    final crossesGround = p0.y < court.groundY && p1.y >= court.groundY;

    Fix? groundT;
    Fix? landingX;
    if (crossesGround) {
      // d.y > 0 here (p0.y < groundY <= p1.y), so the division is safe.
      groundT = (court.groundY - p0.y) / d.y;
      landingX = p0.x + groundT * d.x;
    }

    // -- Determine the net event kind (if any) -------------------------------
    // Above the tape band (y < netTopY) is clean passage and produces no event.
    final bool netIsBody;
    final bool netIsCord;
    if (netCrossing != null) {
      final y = netCrossing.y;
      if (y < court.netTopY) {
        // Clean passage over the top of the net.
        netIsBody = false;
        netIsCord = false;
      } else if (y <= Tunables.netTapeBottomY) {
        netIsCord = true;
        netIsBody = false;
      } else {
        netIsBody = true;
        netIsCord = false;
      }
    } else {
      netIsBody = false;
      netIsCord = false;
    }

    // -- Ground reached before the net plane consumes the sweep --------------
    // A steep shot can land in front of the net while its extrapolated
    // segment continues across the net plane *below ground level* (the net
    // crossing y is then > groundY, which would otherwise read as a net-body
    // hit). Sweep order decides: the crossing with the smaller t happened
    // first, and a ground hit ends the rally, so nothing after it occurred.
    if (groundT != null && (netT == null || groundT <= netT)) {
      events.add(_groundHit(landingX!, court));
      _applyGround(shuttle, landingX, court);
      return events;
    }

    // -- Net-body hit consumes the sweep -------------------------------------
    if (netIsBody) {
      events.add(NetBodyHit(netCrossing!));
      _applyNetBody(shuttle, netCrossing, p0);
      return events;
    }

    // -- Otherwise gather the net-cord and any later ground event ------------
    // (A clean passage contributes no net event.) Reaching here means either
    // there is no ground crossing, or it occurs after the net crossing
    // (netT < groundT), so events are already in ascending-t order.
    if (netIsCord) {
      events.add(NetCordHit(netCrossing!));
      _applyNetCord(shuttle);
    }
    if (groundT != null) {
      events.add(_groundHit(landingX!, court));
      _applyGround(shuttle, landingX, court);
    }

    return events;
  }

  /// Builds a [GroundHit] for the interpolated [landingX].
  static GroundHit _groundHit(Fix landingX, Court court) => GroundHit(
    landingX: landingX,
    side: court.sideOfX(landingX),
    isInBounds: landingX >= court.leftBound && landingX <= court.rightBound,
  );

  /// Stops the shuttle at the net and lets it slide down.
  ///
  /// Parks it at the crossing point nudged back onto the hitter's side by
  /// [_netEpsilon], zeroes horizontal velocity, and keeps only downward (+y)
  /// vertical velocity so gravity re-accumulates a slide on later ticks.
  static void _applyNetBody(Shuttle shuttle, FixVec2 crossing, FixVec2 p0) {
    // The hitter's side is the side the sweep started on.
    final cameFromLeft = p0.x < crossing.x;
    final parkedX = cameFromLeft
        ? crossing.x - _netEpsilon
        : crossing.x + _netEpsilon;
    final keptDownward = Fix.max(shuttle.velocity.y, Fix.zero);
    shuttle
      ..position = FixVec2(parkedX, crossing.y)
      ..velocity = FixVec2(Fix.zero, keptDownward);
  }

  /// Damps the shuttle's velocity on a net-cord clip; position is unchanged
  /// (the shuttle keeps the already-integrated position for this tick).
  static void _applyNetCord(Shuttle shuttle) {
    shuttle.velocity = shuttle.velocity.scale(Tunables.netCordDamping);
  }

  /// Clamps the shuttle to the ground at [landingX] and zeroes its velocity.
  static void _applyGround(Shuttle shuttle, Fix landingX, Court court) {
    shuttle
      ..position = FixVec2(landingX, court.groundY)
      ..velocity = FixVec2.zero;
  }
}
