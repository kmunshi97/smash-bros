import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/entities/player.dart';
import 'package:smash_bros/engine/entities/shuttle.dart';
import 'package:smash_bros/engine/entities/tunables.dart';
import 'package:smash_bros/engine/input/input_action.dart';
import 'package:smash_bros/engine/math/fix.dart';
import 'package:smash_bros/engine/math/fix_vec2.dart';
import 'package:smash_bros/engine/random/game_random.dart';
import 'package:smash_bros/engine/systems/rally_state.dart';
import 'package:smash_bros/engine/systems/shot_system.dart';

const _court = Court();

// Geometry recap (constants.dart): hitbox width 48 (half 24), height 80,
// groundY 600, racquetReach 40, netX 640.
//
// A grounded left-side player centred at x=300 facing right has:
//   hitboxLeft   = 276, hitboxRight  = 324
//   hitboxTop    = 520, hitboxBottom = 600
// Expanded (facing right, upward): x in [276, 364], y in [480, 600].

Player _leftPlayer({double x = 300, Facing facing = Facing.right}) =>
    Player(x: Fix.of(x), courtSide: CourtSide.left, facing: facing);

Player _rightPlayer({double x = 980, Facing facing = Facing.left}) =>
    Player(x: Fix.of(x), courtSide: CourtSide.right, facing: facing);

Shuttle _shuttleAt(double x, double y) =>
    Shuttle(position: FixVec2(Fix.of(x), Fix.of(y)));

/// A shuttle inside the reach box of [_leftPlayer] (centred at x=300, facing
/// right): x=320 (within [276, 364]), y=560 (within [480, 600]).
Shuttle _inReachLeft() => _shuttleAt(320, 560);

GameRandom _rng() => GameRandom(12345);

void main() {
  group('ShotType.fromBitmask', () {
    test('maps each shot bit', () {
      expect(ShotType.fromBitmask(InputAction.normalShot), ShotType.normal);
      expect(ShotType.fromBitmask(InputAction.smash), ShotType.smash);
      expect(ShotType.fromBitmask(InputAction.dropShot), ShotType.drop);
      expect(ShotType.fromBitmask(InputAction.toss), ShotType.toss);
    });

    test('returns null when no shot bit is set', () {
      expect(ShotType.fromBitmask(InputAction.none), isNull);
      expect(
        ShotType.fromBitmask(InputAction.moveLeft | InputAction.jump),
        isNull,
      );
    });
  });

  group('ShotSystem reach', () {
    test('in-range shuttle connects for a right-facing left player', () {
      final result = ShotSystem.trySwing(
        player: _leftPlayer(),
        shuttle: _inReachLeft(),
        rally: RallyState(),
        shotType: ShotType.normal,
        random: _rng(),
        court: _court,
      );
      expect(result, isNotNull);
    });

    test('in-range shuttle connects for a left-facing right player', () {
      // Right player centred at x=980 facing left: x in [916, 1004], y[480,600].
      // Shuttle at x=940, y=560 is within reach (extends leftward).
      final result = ShotSystem.trySwing(
        player: _rightPlayer(),
        shuttle: _shuttleAt(940, 560),
        rally: RallyState(),
        shotType: ShotType.normal,
        random: _rng(),
        court: _court,
      );
      expect(result, isNotNull);
    });

    test('shuttle behind the back whiffs (right-facing player)', () {
      // Facing right, reach extends rightward only. A shuttle to the left of
      // hitboxLeft (276) is behind the body. x=250 < 276 → whiff.
      final result = ShotSystem.trySwing(
        player: _leftPlayer(),
        shuttle: _shuttleAt(250, 560),
        rally: RallyState(),
        shotType: ShotType.normal,
        random: _rng(),
        court: _court,
      );
      expect(result, isNull);
    });

    test('shuttle behind the back whiffs (left-facing player)', () {
      // Facing left, reach extends leftward only. A shuttle to the right of
      // hitboxRight (1004) is behind the body. x=1030 > 1004 → whiff.
      final result = ShotSystem.trySwing(
        player: _rightPlayer(),
        shuttle: _shuttleAt(1030, 560),
        rally: RallyState(),
        shotType: ShotType.normal,
        random: _rng(),
        court: _court,
      );
      expect(result, isNull);
    });

    test('above-head shuttle within the upward reach connects', () {
      // y top of hitbox is 520; reach extends it up to 480. y=490 connects.
      final result = ShotSystem.trySwing(
        player: _leftPlayer(),
        shuttle: _shuttleAt(320, 490),
        rally: RallyState(),
        shotType: ShotType.normal,
        random: _rng(),
        court: _court,
      );
      expect(result, isNotNull);
    });

    test('below the feet whiffs', () {
      // y=610 is below hitboxBottom (600).
      final result = ShotSystem.trySwing(
        player: _leftPlayer(),
        shuttle: _shuttleAt(320, 610),
        rally: RallyState(),
        shotType: ShotType.normal,
        random: _rng(),
        court: _court,
      );
      expect(result, isNull);
    });

    test('beyond the racquet reach whiffs', () {
      // Facing right, reach edge is 364. x=370 > 364.
      final result = ShotSystem.trySwing(
        player: _leftPlayer(),
        shuttle: _shuttleAt(370, 560),
        rally: RallyState(),
        shotType: ShotType.normal,
        random: _rng(),
        court: _court,
      );
      expect(result, isNull);
    });
  });

  group('ShotSystem lockout', () {
    test('locked-out player whiffs', () {
      final result = ShotSystem.trySwing(
        player: _leftPlayer(),
        shuttle: _inReachLeft(),
        rally: RallyState(hitLockout: CourtSide.left),
        shotType: ShotType.normal,
        random: _rng(),
        court: _court,
      );
      expect(result, isNull);
    });

    test('a hit arms the lockout and records the shot type', () {
      final rally = RallyState();
      ShotSystem.trySwing(
        player: _leftPlayer(),
        shuttle: _inReachLeft(),
        rally: rally,
        shotType: ShotType.smash,
        random: _rng(),
        court: _court,
      );
      expect(rally.hitLockout, CourtSide.left);
      expect(rally.lastHitter, CourtSide.left);
      expect(rally.lastShotType, ShotType.smash);
    });

    test('after the shuttle crosses, the same player can hit again', () {
      final rally = RallyState();
      final player = _leftPlayer();

      // First hit arms the lockout.
      ShotSystem.trySwing(
        player: player,
        shuttle: _inReachLeft(),
        rally: rally,
        shotType: ShotType.normal,
        random: _rng(),
        court: _court,
      );
      expect(rally.hitLockout, CourtSide.left);

      // Shuttle crosses to the right side; observe lifts the lockout.
      rally.observe(_shuttleAt(900, 300), _court);
      expect(rally.hitLockout, isNull);

      // The same player can now connect again.
      final second = ShotSystem.trySwing(
        player: player,
        shuttle: _inReachLeft(),
        rally: rally,
        shotType: ShotType.normal,
        random: _rng(),
        court: _court,
      );
      expect(second, isNotNull);
    });
  });

  group('ShotSystem direction and vertical sign', () {
    test('left-side player launches with positive vx', () {
      final result = ShotSystem.trySwing(
        player: _leftPlayer(),
        shuttle: _inReachLeft(),
        rally: RallyState(),
        shotType: ShotType.normal,
        random: _rng(),
        court: _court,
      )!;
      expect(result.launchVelocity.x > Fix.zero, isTrue);
    });

    test('right-side player launches with negative vx', () {
      final result = ShotSystem.trySwing(
        player: _rightPlayer(),
        shuttle: _shuttleAt(940, 560),
        rally: RallyState(),
        shotType: ShotType.normal,
        random: _rng(),
        court: _court,
      )!;
      expect(result.launchVelocity.x < Fix.zero, isTrue);
    });

    test('normal/toss/drop arc upward (negative vy); smash downward', () {
      Fix vyOf(ShotType type, {Shuttle? shuttle}) => ShotSystem.trySwing(
        player: _leftPlayer(),
        shuttle: shuttle ?? _inReachLeft(),
        rally: RallyState(),
        shotType: type,
        random: _rng(),
        court: _court,
      )!.launchVelocity.y;

      expect(vyOf(ShotType.normal) < Fix.zero, isTrue);
      expect(vyOf(ShotType.toss) < Fix.zero, isTrue);
      expect(vyOf(ShotType.drop) < Fix.zero, isTrue);
      expect(vyOf(ShotType.smash) > Fix.zero, isTrue);
    });
  });

  group('ShotSystem normal-shot angle bounds', () {
    test('200 draws all stay within [min, max]', () {
      final random = _rng();
      final minSin = FixMath.sin(Tunables.normalShotAngleMin).toDouble();
      final maxSin = FixMath.sin(Tunables.normalShotAngleMax).toDouble();
      final speed = Tunables.normalShotSpeed.toDouble();

      for (var i = 0; i < 200; i++) {
        final result = ShotSystem.trySwing(
          player: _leftPlayer(),
          shuttle: _inReachLeft(),
          rally: RallyState(),
          shotType: ShotType.normal,
          random: random,
          court: _court,
        )!;
        // Recover sin(angle) from -vy / speed (vy is negative for an up-arc).
        final recoveredSin = -result.launchVelocity.y.toDouble() / speed;
        expect(recoveredSin, greaterThanOrEqualTo(minSin - 1e-9));
        expect(recoveredSin, lessThanOrEqualTo(maxSin + 1e-9));
      }
    });
  });

  group('ShotSystem jump smash', () {
    test('airborne smash speed is smashSpeed * jumpSmashBonus', () {
      // At jumpTick 20 of 40 (apex) the feet rise to y=380, so the hitbox is
      // [276, 364] x [300, 380] expanded up to y=260. Place the shuttle there.
      final airborne = _leftPlayer()..jumpTick = 20; // mid-jump, not grounded
      expect(airborne.isGrounded, isFalse);

      final result = ShotSystem.trySwing(
        player: airborne,
        shuttle: _shuttleAt(320, 350),
        rally: RallyState(),
        shotType: ShotType.smash,
        random: _rng(),
        court: _court,
      )!;

      final speed = result.launchVelocity.magnitude.toDouble();
      final expected = (Tunables.smashSpeed * Tunables.jumpSmashBonus)
          .toDouble();
      expect(speed, closeTo(expected, 1e-6));
      expect(result.wasAirborne, isTrue);
    });

    test('grounded smash has no bonus', () {
      final result = ShotSystem.trySwing(
        player: _leftPlayer(),
        shuttle: _inReachLeft(),
        rally: RallyState(),
        shotType: ShotType.smash,
        random: _rng(),
        court: _court,
      )!;
      final speed = result.launchVelocity.magnitude.toDouble();
      expect(speed, closeTo(Tunables.smashSpeed.toDouble(), 1e-6));
      expect(result.wasAirborne, isFalse);
    });
  });

  group('ShotSystem modifiers', () {
    test('powerMultiplier 2.0 doubles launch speed for every shot type', () {
      for (final type in ShotType.values) {
        // Use a high shuttle so an airborne-independent grounded smash applies.
        final base = ShotSystem.trySwing(
          player: _leftPlayer(),
          shuttle: _inReachLeft(),
          rally: RallyState(),
          shotType: type,
          random: _rng(),
          court: _court,
        )!;
        final boosted = ShotSystem.trySwing(
          player: _leftPlayer(),
          shuttle: _inReachLeft(),
          rally: RallyState(),
          shotType: type,
          random: _rng(),
          court: _court,
          modifiers: const ShotModifiers(powerMultiplier: Fix.of(2)),
        )!;
        expect(
          boosted.launchVelocity.magnitude.toDouble(),
          closeTo(base.launchVelocity.magnitude.toDouble() * 2, 1e-6),
          reason: 'shot type $type should double',
        );
      }
    });
  });

  group('ShotSystem PRNG discipline', () {
    test('a lockout whiff leaves the generator unchanged', () {
      final random = _rng();
      final before = random.state;
      ShotSystem.trySwing(
        player: _leftPlayer(),
        shuttle: _inReachLeft(),
        rally: RallyState(hitLockout: CourtSide.left),
        shotType: ShotType.normal,
        random: random,
        court: _court,
      );
      expect(random.state, before);
    });

    test('an out-of-reach whiff leaves the generator unchanged', () {
      final random = _rng();
      final before = random.state;
      ShotSystem.trySwing(
        player: _leftPlayer(),
        shuttle: _shuttleAt(370, 560), // beyond reach
        rally: RallyState(),
        shotType: ShotType.normal,
        random: random,
        court: _court,
      );
      expect(random.state, before);
    });

    test('a successful drop draws no randomness (fixed angle)', () {
      final random = _rng();
      final before = random.state;
      ShotSystem.trySwing(
        player: _leftPlayer(),
        shuttle: _inReachLeft(),
        rally: RallyState(),
        shotType: ShotType.drop,
        random: random,
        court: _court,
      );
      expect(random.state, before);
    });

    test('a successful toss draws no randomness (fixed angle)', () {
      final random = _rng();
      final before = random.state;
      ShotSystem.trySwing(
        player: _leftPlayer(),
        shuttle: _inReachLeft(),
        rally: RallyState(),
        shotType: ShotType.toss,
        random: random,
        court: _court,
      );
      expect(random.state, before);
    });

    test('a successful normal shot advances the generator', () {
      final random = _rng();
      final before = random.state;
      ShotSystem.trySwing(
        player: _leftPlayer(),
        shuttle: _inReachLeft(),
        rally: RallyState(),
        shotType: ShotType.normal,
        random: random,
        court: _court,
      );
      expect(random.state, isNot(before));
    });

    test('a successful smash advances the generator', () {
      final random = _rng();
      final before = random.state;
      ShotSystem.trySwing(
        player: _leftPlayer(),
        shuttle: _inReachLeft(),
        rally: RallyState(),
        shotType: ShotType.smash,
        random: random,
        court: _court,
      );
      expect(random.state, isNot(before));
    });
  });

  group('ShotSystem drag coefficient effects', () {
    test('a drop switches the active drag to the drop-shot coefficient', () {
      final rally = RallyState();
      ShotSystem.trySwing(
        player: _leftPlayer(),
        shuttle: _inReachLeft(),
        rally: rally,
        shotType: ShotType.drop,
        random: _rng(),
        court: _court,
      );
      expect(rally.activeDragCoefficient, Tunables.shuttleDropShotDrag);
    });

    test('a non-drop shot resets the active drag to the rally default', () {
      final rally = RallyState()
        ..activeDragCoefficient = Tunables.shuttleDropShotDrag;
      ShotSystem.trySwing(
        player: _leftPlayer(),
        shuttle: _inReachLeft(),
        rally: rally,
        shotType: ShotType.normal,
        random: _rng(),
        court: _court,
      );
      expect(rally.activeDragCoefficient, Tunables.shuttleDragCoefficient);
    });
  });

  group('ShotSystem launches the shuttle', () {
    test('a hit imparts the launch velocity to the shuttle', () {
      final shuttle = _inReachLeft();
      final result = ShotSystem.trySwing(
        player: _leftPlayer(),
        shuttle: shuttle,
        rally: RallyState(),
        shotType: ShotType.normal,
        random: _rng(),
        court: _court,
      )!;
      expect(shuttle.velocity, result.launchVelocity);
    });
  });

  group('ShotSystem determinism', () {
    test('same seed and setup twice produce identical results', () {
      SwingResult run() {
        final shuttle = _inReachLeft();
        return ShotSystem.trySwing(
          player: _leftPlayer(),
          shuttle: shuttle,
          rally: RallyState(),
          shotType: ShotType.normal,
          random: GameRandom(99),
          court: _court,
        )!;
      }

      final a = run();
      final b = run();
      expect(a, b);
      expect(a.launchVelocity, b.launchVelocity);
    });
  });
}
