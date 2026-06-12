import 'package:meta/meta.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/entities/player.dart';
import 'package:smash_bros/engine/entities/shuttle.dart';
import 'package:smash_bros/engine/entities/tunables.dart';
import 'package:smash_bros/engine/math/fix.dart';
import 'package:smash_bros/engine/math/fix_vec2.dart';
import 'package:smash_bros/engine/random/game_random.dart';
import 'package:smash_bros/engine/systems/rally_state.dart';
import 'package:smash_bros/engine/systems/shot_type.dart';

// ShotType moved to shot_type.dart to break the rally_state <-> shot_system
// import cycle; re-exported so existing `shot_system.dart` importers keep it.
export 'package:smash_bros/engine/systems/shot_type.dart';

/// Per-shot stat modifiers — the Milestone 3 loadout hook (M1-010).
///
/// Until Milestone 3, every swing uses [identity] (an all-neutral instance).
/// The `StatCalculator` introduced with player loadouts will construct
/// non-identity instances (e.g. a power-stat that raises [powerMultiplier])
/// and hand them to [ShotSystem.trySwing]; the shot maths already routes every
/// launch speed through [powerMultiplier], so no further wiring is needed then.
///
/// The [tossSpeedOverride] field is used by M1-034's hold-to-charge serve to
/// supply the lerped charge speed directly. When non-null it replaces the
/// default toss speed constants before [powerMultiplier] is applied.
@immutable
final class ShotModifiers {
  /// Creates modifiers; every field defaults to its neutral value.
  const ShotModifiers({this.powerMultiplier = Fix.one, this.tossSpeedOverride});

  /// The neutral instance used by every swing until Milestone 3 loadouts land.
  static const ShotModifiers identity = ShotModifiers();

  /// Multiplier applied to the launch speed of every shot.
  final Fix powerMultiplier;

  /// When non-null, overrides the toss speed constants ([Tunables.tossSpeedMin]
  /// / [Tunables.tossSpeedMax]) for this swing. Used by the hold-to-charge
  /// serve (M1-034) to inject the lerped charge speed without duplicating
  /// the launch-velocity computation.
  ///
  /// Ignored for all shot types except [ShotType.toss].
  final Fix? tossSpeedOverride;
}

/// The record of a swing that connected.
///
/// Returned by [ShotSystem.trySwing] on success (a whiff returns `null`).
/// Value-semantic, mirroring the `CollisionEvent` classes.
@immutable
final class SwingResult {
  /// Creates a swing result for the connected [shotType] with its computed
  /// [launchVelocity], the [side] of the court the hitter occupies, and
  /// whether the player [wasAirborne] at contact.
  const SwingResult({
    required this.shotType,
    required this.launchVelocity,
    required this.side,
    required this.wasAirborne,
  });

  /// The kind of shot that was played.
  final ShotType shotType;

  /// The velocity imparted to the shuttle, in game units per tick.
  final FixVec2 launchVelocity;

  /// The court side of the player who hit the shuttle.
  ///
  /// Populated from [Player.courtSide] at the moment [ShotSystem.trySwing]
  /// connects. The presentation layer uses this to attribute sounds and
  /// visual effects to the correct player.
  final CourtSide side;

  /// Whether the player was off the ground at the moment of contact.
  final bool wasAirborne;

  @override
  bool operator ==(Object other) =>
      other is SwingResult &&
      other.shotType == shotType &&
      other.launchVelocity == launchVelocity &&
      other.side == side &&
      other.wasAirborne == wasAirborne;

  @override
  int get hashCode => Object.hash(shotType, launchVelocity, side, wasAirborne);

  @override
  String toString() =>
      'SwingResult(shotType: $shotType, launchVelocity: $launchVelocity, '
      'side: $side, wasAirborne: $wasAirborne)';
}

/// Resolves a player's attempt to hit the shuttle into a launch (or a whiff).
///
/// ## Contract
///
/// [trySwing] is the single entry point. Given a player, the shuttle, the
/// current [RallyState] and a [ShotType], it decides whether the swing
/// connects and, if so, mutates the shuttle (launches it) and the rally state
/// (records the hitter, arms the lockout, sets the air-drag coefficient) and
/// returns a [SwingResult]. Any failed check returns `null` — a whiff — and
/// leaves every input untouched.
///
/// ## Tick order
///
/// Runs in the input-resolution step, after [ShotType.fromBitmask] has decoded
/// the sanitized input and before the shuttle integrates this tick (so a fresh
/// launch velocity is integrated immediately). Reach is tested against the
/// shuttle's *current* position.
///
/// ## Determinism / PRNG discipline
///
/// A whiff consumes **zero** PRNG draws, and shots with no angle spread (drop,
/// toss) consume none either. The generator is only advanced when a connected
/// shot genuinely needs spread (normal, smash). This keeps the random stream a
/// function of the *effects* the simulation produced rather than of every
/// attempt, which makes replays compact to reason about and stops a player
/// mashing whiff inputs from perturbing later random outcomes.
abstract final class ShotSystem {
  /// Attempts a swing of [shotType] by [player] at [shuttle].
  ///
  /// Returns the [SwingResult] on a clean hit, or `null` on a whiff. Checks run
  /// in this order, each returning `null` on failure:
  ///
  /// 1. **Lockout** — if [RallyState.hitLockout] equals the player's side the
  ///    swing simply does not connect. This is the arcade reading of the
  ///    carry/double-hit fault: no fault point is awarded, the swing just
  ///    whiffs.
  /// 2. **Reach box** — the shuttle centre must lie inside the player's hitbox
  ///    expanded by [Tunables.racquetReach] on the *facing side only* and
  ///    upward. Contact behind the player's back is a whiff (the
  ///    behind-the-body rule, M1-009); facing direction is mechanical.
  /// 3. Only once both checks pass may [random] be drawn from (see class docs
  ///    on PRNG discipline).
  ///
  /// On success the launch velocity is computed in per-tick units (+y is
  /// *downward*): the horizontal direction is `+1` for a left-side player
  /// (shots travel rightward toward the opponent) and `-1` otherwise; every
  /// speed is finally scaled by [ShotModifiers.powerMultiplier]. The shuttle is
  /// launched, [RallyState.lastHitter] and [RallyState.hitLockout] are set to
  /// the player's side, and [RallyState.activeDragCoefficient] is switched to
  /// the drop-shot drag for a drop or back to the rally default otherwise.
  static SwingResult? trySwing({
    required Player player,
    required Shuttle shuttle,
    required RallyState rally,
    required ShotType shotType,
    required GameRandom random,
    required Court court,
    ShotModifiers modifiers = ShotModifiers.identity,
  }) {
    // 1. Lockout: the locked-out side's swing does not connect.
    if (rally.hitLockout == player.courtSide) {
      return null;
    }

    // 2. Reach box: hitbox expanded by the racquet reach on the facing side
    //    and upward. Contact behind the body is a whiff.
    if (!isWithinReach(player, shuttle.position)) {
      return null;
    }

    // 3. Both checks passed — now (and only now) may we draw from the PRNG.
    final wasAirborne = !player.isGrounded;
    // Left-side players hit rightward (+x); right-side players hit leftward.
    final dir = player.courtSide == CourtSide.left ? Fix.one : -Fix.one;

    final FixVec2 velocity;
    switch (shotType) {
      case ShotType.normal:
        final angle = random.nextFixRange(
          Tunables.normalShotAngleMin,
          Tunables.normalShotAngleMax,
        );
        velocity = _upwardArc(angle, Tunables.normalShotSpeed, dir, modifiers);
        rally.activeDragCoefficient = Tunables.shuttleDragCoefficient;
      case ShotType.smash:
        final angle = random.nextFixRange(
          Tunables.smashAngleMin,
          Tunables.smashAngleMax,
        );
        var speed = Tunables.smashSpeed;
        if (wasAirborne) {
          speed = speed * Tunables.jumpSmashBonus;
        }
        velocity = _downwardArc(angle, speed, dir, modifiers);
        rally.activeDragCoefficient = Tunables.shuttleDragCoefficient;
      case ShotType.drop:
        // Fixed angle, so no PRNG draw — a drop has no spread.
        velocity = _upwardArc(
          Tunables.dropShotAngle,
          Tunables.dropShotSpeed,
          dir,
          modifiers,
        );
        rally.activeDragCoefficient = Tunables.shuttleDropShotDrag;
      case ShotType.toss:
        // Fixed angle, so no PRNG draw. Speed comes from the charge override
        // if provided (M1-034 hold-to-charge serve), otherwise falls back to
        // the minimum toss speed (a tap with no charge).
        final tossSpeed = modifiers.tossSpeedOverride ?? Tunables.tossSpeedMin;
        velocity = _upwardArc(Tunables.tossAngle, tossSpeed, dir, modifiers);
        rally.activeDragCoefficient = Tunables.shuttleDragCoefficient;
    }

    shuttle.launch(velocity);
    rally
      ..lastHitter = player.courtSide
      ..hitLockout = player.courtSide
      ..lastShotType = shotType;

    return SwingResult(
      shotType: shotType,
      launchVelocity: velocity,
      side: player.courtSide,
      wasAirborne: wasAirborne,
    );
  }

  /// Whether [point] lies inside [player]'s hitbox expanded by the racquet
  /// reach on the facing side and upward — the canonical "can this player
  /// contact the shuttle here?" test.
  ///
  /// Public and static so the single reach geometry is shared rather than
  /// duplicated: `StunSystem.evaluateBlockTiming`'s lookahead and (later) the
  /// AI both need the identical predicate, and two copies would silently drift.
  static bool isWithinReach(Player player, FixVec2 point) {
    final Fix left;
    final Fix right;
    switch (player.facing) {
      case Facing.right:
        left = player.hitboxLeft;
        right = player.hitboxRight + Tunables.racquetReach;
      case Facing.left:
        left = player.hitboxLeft - Tunables.racquetReach;
        right = player.hitboxRight;
    }
    final top = player.hitboxTop - Tunables.racquetReach;
    final bottom = player.hitboxBottom;
    return point.x >= left &&
        point.x <= right &&
        point.y >= top &&
        point.y <= bottom;
  }

  /// An upward-arced launch velocity: `(cos(a)*speed*dir, -sin(a)*speed)`,
  /// scaled by the power multiplier. Negative y is upward.
  static FixVec2 _upwardArc(
    Fix angle,
    Fix speed,
    Fix dir,
    ShotModifiers modifiers,
  ) {
    final s = speed * modifiers.powerMultiplier;
    return FixVec2(FixMath.cos(angle) * s * dir, -FixMath.sin(angle) * s);
  }

  /// A downward-arced launch velocity: `(cos(a)*speed*dir, +sin(a)*speed)`,
  /// scaled by the power multiplier. Positive y is downward (a smash).
  static FixVec2 _downwardArc(
    Fix angle,
    Fix speed,
    Fix dir,
    ShotModifiers modifiers,
  ) {
    final s = speed * modifiers.powerMultiplier;
    return FixVec2(FixMath.cos(angle) * s * dir, FixMath.sin(angle) * s);
  }
}
