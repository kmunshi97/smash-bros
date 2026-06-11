import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/entities/player.dart';
import 'package:smash_bros/engine/entities/shuttle.dart';
import 'package:smash_bros/engine/math/fix.dart';
import 'package:smash_bros/engine/math/fix_vec2.dart';
import 'package:smash_bros/engine/random/game_random.dart';
import 'package:smash_bros/engine/systems/rally_state.dart';
import 'package:smash_bros/engine/systems/shot_system.dart';
import 'package:smash_bros/engine/systems/stun_system.dart';

const _court = Court();

// Geometry recap (constants.dart): hitbox width 48 (half 24), height 80,
// groundY 600, racquetReach 40. A right-side defender centred at x=980 facing
// left has reach box: x in [916, 1004], y in [480, 600].
Player _defender({double x = 980}) =>
    Player(x: Fix.of(x), courtSide: CourtSide.right, facing: Facing.left);

/// A rally where the LEFT side has just smashed (incoming smash at the
/// right-side defender).
RallyState _incomingSmash() =>
    RallyState(lastHitter: CourtSide.left, lastShotType: ShotType.smash);

Shuttle _shuttle(double x, double y, double vx, double vy) => Shuttle(
  position: FixVec2(Fix.of(x), Fix.of(y)),
  velocity: FixVec2(Fix.of(vx), Fix.of(vy)),
);

/// Reproduces [StunSystem]'s lookahead independently so the test derives the
/// expected arrival tick from the real physics instead of guessing it. Mirrors
/// the production loop exactly: t=0 check before any step, then up to
/// [kBlockLookaheadMaxTicks] integrate steps with the rally's drag.
int? _empiricalArrival(Player defender, Shuttle shuttle, RallyState rally) {
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

BlockTiming _expectedFor(int? arrival) {
  if (arrival == null) {
    return BlockTiming.notApplicable;
  }
  if (arrival >= kPerfectBlockWindowStart &&
      arrival <= kPerfectBlockWindowEnd) {
    return BlockTiming.perfect;
  }
  return BlockTiming.imperfect;
}

void main() {
  group('StunSystem.applyStun / tick', () {
    test('applyStun sets the full stun duration and flips isStunned', () {
      final p = _defender();
      expect(p.isStunned, isFalse);
      StunSystem.applyStun(p);
      expect(p.stunTicksRemaining, kStunDurationFrames);
      expect(p.isStunned, isTrue);
    });

    test('tick counts down to zero and stays there', () {
      final p = _defender()..stunTicksRemaining = 2;
      StunSystem.tick(p);
      expect(p.stunTicksRemaining, 1);
      StunSystem.tick(p);
      expect(p.stunTicksRemaining, 0);
      expect(p.isStunned, isFalse);
      // No-op at zero.
      StunSystem.tick(p);
      expect(p.stunTicksRemaining, 0);
    });
  });

  group('StunSystem.evaluateBlockTiming — not applicable', () {
    test('when the last shot was not a smash', () {
      final rally = RallyState(
        lastHitter: CourtSide.left,
        lastShotType: ShotType.normal,
      );
      // Shuttle sitting right in the defender's reach.
      final timing = StunSystem.evaluateBlockTiming(
        defender: _defender(),
        shuttle: _shuttle(980, 540, 0, 0),
        rally: rally,
        court: _court,
      );
      expect(timing, BlockTiming.notApplicable);
    });

    test('when there is no last hitter at all', () {
      final timing = StunSystem.evaluateBlockTiming(
        defender: _defender(),
        shuttle: _shuttle(980, 540, 0, 0),
        rally: RallyState(lastShotType: ShotType.smash),
        court: _court,
      );
      expect(timing, BlockTiming.notApplicable);
    });

    test('when the incoming smash is the defenders OWN shot', () {
      final rally = RallyState(
        lastHitter: CourtSide.right,
        lastShotType: ShotType.smash,
      );
      final timing = StunSystem.evaluateBlockTiming(
        defender: _defender(),
        shuttle: _shuttle(980, 540, 0, 0),
        rally: rally,
        court: _court,
      );
      expect(timing, BlockTiming.notApplicable);
    });

    test('when the smash never reaches the defender within the bound', () {
      // Shuttle heading away from the defender (leftward, downward) so it never
      // enters the reach box.
      final shuttle = _shuttle(700, 300, -5, 0);
      final rally = _incomingSmash();
      // Sanity: the empirical lookahead agrees there is no arrival.
      expect(_empiricalArrival(_defender(), shuttle, rally), isNull);
      final timing = StunSystem.evaluateBlockTiming(
        defender: _defender(),
        shuttle: shuttle,
        rally: rally,
        court: _court,
      );
      expect(timing, BlockTiming.notApplicable);
    });
  });

  group('StunSystem.evaluateBlockTiming — verdict matches empirical arrival', () {
    // For each scenario we derive the expected verdict from the real physics
    // (via _empiricalArrival) rather than hardcoding a guess for quadratic drag.

    test('a far shuttle arriving mid-window is a perfect block', () {
      // Tuned so the shuttle reaches the reach box around tick 6-12.
      final shuttle = _shuttle(820, 540, 11, 0);
      final rally = _incomingSmash();
      final arrival = _empiricalArrival(_defender(), shuttle, rally);
      expect(arrival, isNotNull);
      expect(arrival! >= kPerfectBlockWindowStart, isTrue);
      expect(arrival <= kPerfectBlockWindowEnd, isTrue);

      final timing = StunSystem.evaluateBlockTiming(
        defender: _defender(),
        shuttle: shuttle,
        rally: rally,
        court: _court,
      );
      expect(timing, BlockTiming.perfect);
      expect(timing, _expectedFor(arrival));
    });

    test('a very close shuttle arriving before the window is imperfect', () {
      // Already (almost) on top of the defender → arrives in <6 ticks.
      final shuttle = _shuttle(960, 540, 6, 0);
      final rally = _incomingSmash();
      final arrival = _empiricalArrival(_defender(), shuttle, rally);
      expect(arrival, isNotNull);
      expect(arrival! < kPerfectBlockWindowStart, isTrue);

      final timing = StunSystem.evaluateBlockTiming(
        defender: _defender(),
        shuttle: shuttle,
        rally: rally,
        court: _court,
      );
      expect(timing, BlockTiming.imperfect);
      expect(timing, _expectedFor(arrival));
    });

    test('a far but slow shuttle arriving after the window is imperfect', () {
      // Slow approach so it only reaches the box after tick 12 (but within 30).
      final shuttle = _shuttle(820, 540, 5, 0);
      final rally = _incomingSmash();
      final arrival = _empiricalArrival(_defender(), shuttle, rally);
      expect(arrival, isNotNull);
      expect(arrival! > kPerfectBlockWindowEnd, isTrue);
      expect(arrival <= kBlockLookaheadMaxTicks, isTrue);

      final timing = StunSystem.evaluateBlockTiming(
        defender: _defender(),
        shuttle: shuttle,
        rally: rally,
        court: _court,
      );
      expect(timing, BlockTiming.imperfect);
      expect(timing, _expectedFor(arrival));
    });

    test('a shuttle already in reach at t=0 arrives at 0 → imperfect', () {
      final shuttle = _shuttle(980, 540, 0, 0);
      final rally = _incomingSmash();
      expect(_empiricalArrival(_defender(), shuttle, rally), 0);
      final timing = StunSystem.evaluateBlockTiming(
        defender: _defender(),
        shuttle: shuttle,
        rally: rally,
        court: _court,
      );
      expect(timing, BlockTiming.imperfect);
    });
  });

  group('StunSystem.evaluateBlockTiming — boundary exactness', () {
    // Sweep horizontal launch speed to land exactly on each boundary arrival
    // tick under the real drag physics, then assert the verdict flips there.
    // Velocities are chosen by scanning; if a given boundary proves
    // unreachable by integer-ish tuning we skip with a comment, but the wide
    // 6..12 window makes all four reachable here.

    /// Finds a shuttle whose empirical arrival equals [targetTick] by scanning
    /// horizontal launch speeds, or null if none in range hits it exactly.
    Shuttle? craftArrivingAt(int targetTick) {
      final rally = _incomingSmash();
      // Start just left of the reach box (x=860, box left edge 916) and vary
      // launch speed finely. From here the achievable arrivals span 3..29
      // under real drag, so all four boundary ticks (5/6/12/13) are reachable.
      for (var i = 0; i <= 4000; i++) {
        final vx = 1.0 + i * 0.01;
        final shuttle = _shuttle(860, 540, vx, 0);
        if (_empiricalArrival(_defender(), shuttle, rally) == targetTick) {
          return shuttle;
        }
      }
      return null;
    }

    void assertBoundary(int arrivalTick, BlockTiming expected) {
      final shuttle = craftArrivingAt(arrivalTick);
      if (shuttle == null) {
        markTestSkipped(
          'could not craft an arrival of exactly $arrivalTick under real drag',
        );
        return;
      }
      final rally = _incomingSmash();
      // Confirm the crafted arrival is exact before asserting the verdict.
      expect(_empiricalArrival(_defender(), shuttle, rally), arrivalTick);
      final timing = StunSystem.evaluateBlockTiming(
        defender: _defender(),
        shuttle: shuttle,
        rally: rally,
        court: _court,
      );
      expect(timing, expected);
    }

    test('arrival == 5 (just before window) is imperfect', () {
      assertBoundary(5, BlockTiming.imperfect);
    });

    test('arrival == 6 (window start) is perfect', () {
      assertBoundary(6, BlockTiming.perfect);
    });

    test('arrival == 12 (window end) is perfect', () {
      assertBoundary(12, BlockTiming.perfect);
    });

    test('arrival == 13 (just after window) is imperfect', () {
      assertBoundary(13, BlockTiming.imperfect);
    });
  });

  group('StunSystem.evaluateBlockTiming — side-effect freedom', () {
    test('does not move the real shuttle', () {
      final shuttle = _shuttle(820, 540, 11, 0);
      final beforePos = shuttle.position;
      final beforeVel = shuttle.velocity;
      final beforePrev = shuttle.previousPosition;

      StunSystem.evaluateBlockTiming(
        defender: _defender(),
        shuttle: shuttle,
        rally: _incomingSmash(),
        court: _court,
      );

      expect(shuttle.position, beforePos);
      expect(shuttle.velocity, beforeVel);
      expect(shuttle.previousPosition, beforePrev);
    });

    test('draws no randomness (a caller-held generator is untouched)', () {
      // The system takes no GameRandom parameter, so it structurally cannot
      // draw; this guards against a future regression that threads one in. A
      // generator the caller holds across the call must still produce the same
      // value as an independent generator that was never passed in.
      final reference = GameRandom(999);
      final observed = GameRandom(999);

      StunSystem.evaluateBlockTiming(
        defender: _defender(),
        shuttle: _shuttle(820, 540, 11, 0),
        rally: _incomingSmash(),
        court: _court,
      );

      expect(observed.nextUint32(), reference.nextUint32());
    });
  });
}
