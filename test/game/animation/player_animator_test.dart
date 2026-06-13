// Unit tests for the PlayerAnimator state machine (M2-005). Pure — no Flame.
import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/game/animation/player_animator.dart';

void main() {
  // Convenience: drive one frame with explicit facts (idle defaults).
  void step(
    PlayerAnimator a, {
    double dt = 1 / 60,
    bool stunned = false,
    bool airborne = false,
    bool rising = false,
    bool moving = false,
    double swing01 = -1,
  }) {
    a.update(
      dt,
      stunned: stunned,
      airborne: airborne,
      rising: rising,
      moving: moving,
      swing01: swing01,
    );
  }

  group('state classification + priority', () {
    test('defaults to idle', () {
      final a = PlayerAnimator();
      step(a);
      expect(a.state, PlayerAnimState.idle);
    });

    test('moving on the ground is run', () {
      final a = PlayerAnimator();
      step(a, moving: true);
      expect(a.state, PlayerAnimState.run);
    });

    test('airborne + rising is rise; airborne + !rising is fall', () {
      final a = PlayerAnimator();
      step(a, airborne: true, rising: true);
      expect(a.state, PlayerAnimState.rise);
      step(a, airborne: true);
      expect(a.state, PlayerAnimState.fall);
    });

    test('mid-swing is swing', () {
      final a = PlayerAnimator();
      step(a, swing01: 0.5);
      expect(a.state, PlayerAnimState.swing);
    });

    test('stunned wins over swing, airborne, and moving', () {
      final a = PlayerAnimator();
      step(a, stunned: true, swing01: 0.5, airborne: true, moving: true);
      expect(a.state, PlayerAnimState.stunned);
    });

    test('swing wins over airborne and moving', () {
      final a = PlayerAnimator();
      step(a, swing01: 0.3, airborne: true, moving: true);
      expect(a.state, PlayerAnimState.swing);
    });

    test('swing01 >= 1 is not a swing', () {
      final a = PlayerAnimator();
      step(a, swing01: 1);
      expect(a.state, isNot(PlayerAnimState.swing));
    });
  });

  group('landing squash', () {
    test('an airborne→grounded transition enters land with a squash', () {
      final a = PlayerAnimator();
      step(a, airborne: true); // in the air
      step(a); // touchdown this frame
      expect(a.state, PlayerAnimState.land);
      // Squash = wider and shorter than neutral.
      expect(a.pose.scaleY, lessThan(1));
      expect(a.pose.scaleX, greaterThan(1));
    });

    test('the land squash decays back toward neutral, then to idle', () {
      final a = PlayerAnimator();
      step(a, airborne: true);
      step(a); // land begins
      final firstSquash = a.pose.scaleY;
      // Advance past the land duration.
      for (var i = 0; i < 12; i++) {
        step(a);
      }
      expect(a.state, PlayerAnimState.idle);
      // Earlier squash was deeper (smaller scaleY) than the settled state.
      expect(firstSquash, lessThan(1));
    });
  });

  group('pose characteristics', () {
    test('rise stretches tall (scaleY > 1 > scaleX)', () {
      final a = PlayerAnimator();
      step(a, airborne: true, rising: true);
      expect(a.pose.scaleY, greaterThan(1));
      expect(a.pose.scaleX, lessThan(1));
    });

    test('idle bob oscillates around zero over time', () {
      final a = PlayerAnimator();
      var sawPositive = false;
      var sawNegativeOrZero = false;
      for (var i = 0; i < 120; i++) {
        step(a);
        if (a.pose.bobY > 0.1) sawPositive = true;
        if (a.pose.bobY <= 0) sawNegativeOrZero = true;
      }
      expect(sawPositive && sawNegativeOrZero, isTrue);
    });

    test('run leans (non-zero rotation) and bobs', () {
      final a = PlayerAnimator();
      var sawBob = false;
      for (var i = 0; i < 30; i++) {
        step(a, moving: true);
        if (a.pose.bobY.abs() > 0.1) sawBob = true;
      }
      expect(a.pose.rotation, isNot(0));
      expect(sawBob, isTrue);
    });

    test('swing rotation winds back early then swings forward', () {
      final a = PlayerAnimator();
      step(a, swing01: 0.1); // early → wind-up (negative)
      final early = a.pose.rotation;
      step(a, swing01: 0.45); // mid → forward swipe (positive)
      final mid = a.pose.rotation;
      expect(early, lessThan(0));
      expect(mid, greaterThan(0));
    });

    test('stunned wobbles (rotation varies in sign over time)', () {
      final a = PlayerAnimator();
      var sawPos = false;
      var sawNeg = false;
      for (var i = 0; i < 120; i++) {
        step(a, stunned: true);
        if (a.pose.rotation > 0.01) sawPos = true;
        if (a.pose.rotation < -0.01) sawNeg = true;
      }
      expect(sawPos && sawNeg, isTrue);
    });
  });
}
