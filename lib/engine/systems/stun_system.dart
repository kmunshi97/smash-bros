import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/entities/player.dart';
import 'package:smash_bros/engine/entities/shuttle.dart';
import 'package:smash_bros/engine/systems/rally_state.dart';
import 'package:smash_bros/engine/systems/shot_system.dart';

/// The verdict of a defender's swing-timing against an incoming smash (M1-035).
enum BlockTiming {
  /// The swing landed inside the perfect-block window — a clean, full-power
  /// counter with no penalty.
  perfect,

  /// The swing connected but outside the perfect window (too late or too
  /// early) — a weak pop-up return and the defender is stunned.
  imperfect,

  /// No block timing applies: the incoming shot is not a smash from the
  /// opponent, or it never arrives within the defender's reach inside the
  /// lookahead bound.
  notApplicable,
}

/// Owns stun bookkeeping and the perfect-block timing verdict (M1-012 / M1-035).
///
/// ## The block-timing design (M1-035)
///
/// The original feel spec was "a perfect block is swung 6–12 frames *before*
/// the shuttle reaches the player". Under quadratic air drag the shuttle's
/// flight has no closed-form arrival time, so "frames before arrival" cannot be
/// solved analytically. [evaluateBlockTiming] instead *measures* the arrival
/// tick by a bounded forward simulation: it clones the shuttle and integrates
/// the clone tick-by-tick (using the rally's active drag coefficient) until the
/// clone first lands inside the defender's reach box, then classifies that
/// arrival tick against the perfect window
/// `[kPerfectBlockWindowStart, kPerfectBlockWindowEnd]` (6..12).
///
/// This is deterministic: [Shuttle.integrate] is deterministic and the clone
/// draws no randomness, so the same inputs always yield the same verdict (safe
/// for lockstep/rollback). It is also cheap and bounded: at most
/// [kBlockLookaheadMaxTicks] (30) `integrate` calls, and only on the ticks a
/// defender actually swings at an incoming smash.
///
/// ## Contract with the Simulation (PR 9)
///
/// On a defender swing while an opponent's smash is incoming, the Simulation
/// calls [evaluateBlockTiming] and acts on the verdict:
///
/// * [BlockTiming.perfect] → a normal [ShotSystem.trySwing] (full-power
///   counter, no stun).
/// * [BlockTiming.imperfect] → if the swing connects (shuttle in reach *now*),
///   [ShotSystem.trySwing] with `ShotModifiers(powerMultiplier:
///   Tunables.imperfectBlockPower)` for a feeble pop-up, **and**
///   [applyStun] on the defender.
/// * [BlockTiming.notApplicable] → ordinary swing resolution; no block, no
///   stun.
///
/// [StunSystem] does not orchestrate that flow; it only supplies the verdict
/// ([evaluateBlockTiming]) and the stun bookkeeping ([applyStun] / [tick]).
abstract final class StunSystem {
  /// Evaluates the block timing of [defender]'s swing this tick against the
  /// shuttle.
  ///
  /// Returns [BlockTiming.notApplicable] immediately unless a smash from the
  /// opponent is incoming — that is, [RallyState.lastShotType] is
  /// [ShotType.smash], [RallyState.lastHitter] is set, and it is not the
  /// defender's own side.
  ///
  /// Otherwise it finds the shuttle's arrival tick by a bounded lookahead on a
  /// clone (the real [shuttle] is never moved):
  ///
  /// * if the shuttle is already within the defender's reach at t=0 (before any
  ///   integration step), arrival is 0;
  /// * else for `t = 1..kBlockLookaheadMaxTicks` it integrates the clone with
  ///   [RallyState.activeDragCoefficient] and stops at the first `t` whose
  ///   position lies inside [ShotSystem.isWithinReach];
  /// * no arrival within the bound → [BlockTiming.notApplicable] (the smash is
  ///   not actually coming at this defender).
  ///
  /// The arrival tick is then classified: inside
  /// `[kPerfectBlockWindowStart, kPerfectBlockWindowEnd]` (6..12) →
  /// [BlockTiming.perfect]; anything else (0..5 too late, 13..30 too early) →
  /// [BlockTiming.imperfect].
  static BlockTiming evaluateBlockTiming({
    required Player defender,
    required Shuttle shuttle,
    required RallyState rally,
    required Court court,
  }) {
    final hitter = rally.lastHitter;
    final isIncomingSmash =
        rally.lastShotType == ShotType.smash &&
        hitter != null &&
        hitter != defender.courtSide;
    if (!isIncomingSmash) {
      return BlockTiming.notApplicable;
    }

    final arrival = _arrivalTick(defender, shuttle, rally);
    if (arrival == null) {
      return BlockTiming.notApplicable;
    }

    if (arrival >= kPerfectBlockWindowStart &&
        arrival <= kPerfectBlockWindowEnd) {
      return BlockTiming.perfect;
    }
    return BlockTiming.imperfect;
  }

  /// The tick (0..[kBlockLookaheadMaxTicks]) at which the shuttle first enters
  /// [defender]'s reach, or `null` if it never does within the bound.
  ///
  /// Works on a clone so the real shuttle is untouched.
  static int? _arrivalTick(Player defender, Shuttle shuttle, RallyState rally) {
    // t=0: already in reach before any integration step.
    if (ShotSystem.isWithinReach(defender, shuttle.position)) {
      return 0;
    }
    final clone = shuttle.copy();
    for (var t = 1; t <= kBlockLookaheadMaxTicks; t++) {
      clone.integrate(dragCoefficient: rally.activeDragCoefficient);
      if (ShotSystem.isWithinReach(defender, clone.position)) {
        return t;
      }
    }
    return null;
  }

  /// Stuns [player] for [kStunDurationFrames] ticks.
  static void applyStun(Player player) {
    player.stunTicksRemaining = kStunDurationFrames;
  }

  /// Advances [player]'s stun by one tick, decrementing toward 0. No-op at 0.
  static void tick(Player player) {
    if (player.stunTicksRemaining > 0) {
      player.stunTicksRemaining--;
    }
  }
}
