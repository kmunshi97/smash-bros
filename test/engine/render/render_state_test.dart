// Pure engine test — no flutter_test widgets, no Flame imports.
// Tests the RenderState capture, event mapping, and lerp logic (M1-021).
import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/input/input_action.dart';
import 'package:smash_bros/engine/render/render_state.dart';
import 'package:smash_bros/engine/rules/match_phase.dart';
import 'package:smash_bros/engine/sim/simulation.dart';
import 'package:smash_bros/engine/systems/shot_system.dart';
import 'package:smash_bros/engine/systems/shot_type.dart';

void main() {
  // -- capture ----------------------------------------------------------------

  group('RenderState.capture — initial snapshot', () {
    late Simulation sim;
    late RenderState snap;

    setUp(() {
      sim = Simulation(seed: 42)..start();
      // start() transitions to servePending, no tick issued yet — so
      // lastTickSwings and lastTickCollisions are both empty.
      snap = RenderState.capture(sim);
    });

    test('frame mirrors GameState.frame (== 0 before first tick)', () {
      expect(snap.frame, 0);
    });

    test('phase is servePending after start()', () {
      expect(snap.phase, MatchPhase.servePending);
    });

    test('left player x equals kPlayer1StartX', () {
      expect(snap.leftPlayer.x, closeTo(kPlayer1StartX, 1e-9));
    });

    test('right player x equals kPlayer2StartX', () {
      expect(snap.rightPlayer.x, closeTo(kPlayer2StartX, 1e-9));
    });

    test('stamina fractions are 1.0 at full stamina', () {
      expect(snap.leftPlayer.staminaFraction, closeTo(1.0, 1e-9));
      expect(snap.rightPlayer.staminaFraction, closeTo(1.0, 1e-9));
    });

    test('shuttle is parked in front of the left server', () {
      // Left server → shuttle offset rightward by kServeShuttleOffsetX.
      expect(
        snap.shuttle.x,
        closeTo(kPlayer1StartX + kServeShuttleOffsetX, 1e-9),
      );
      expect(
        snap.shuttle.y,
        closeTo(kGroundY - kServeShuttleHeight, 1e-9),
      );
      expect(snap.shuttle.vx, closeTo(0.0, 1e-9));
      expect(snap.shuttle.vy, closeTo(0.0, 1e-9));
    });

    test('scores are 0-0', () {
      expect(snap.leftScore, 0);
      expect(snap.rightScore, 0);
    });

    test('server is left (the default firstServer)', () {
      expect(snap.server, CourtSide.left);
    });

    test('no events in initial capture (no tick has run)', () {
      expect(snap.events, isEmpty);
    });

    test('pointWinner is null before any point', () {
      expect(snap.pointWinner, isNull);
    });

    test('lastPointReason is null before any point', () {
      expect(snap.lastPointReason, isNull);
    });
  });

  // -- events -----------------------------------------------------------------

  group('RenderState.capture — SwingEvent from a serve toss', () {
    test('a toss on frame 0 produces a SwingEvent(left, toss, false)', () {
      final sim = Simulation(seed: 42)..start();
      // M1-034 hold-to-charge: hold toss bit on frame 0 to charge, then
      // release on frame 1 (no toss bit) so the serve fires.
      sim.state.leftInputs.set(0, InputAction.toss);
      sim
        ..tick() // frame 0: toss HIGH → charge accumulates, still servePending
        ..tick(); // frame 1: toss absent → release → serve launches

      final snap = RenderState.capture(sim);
      // The toss fired during the second tick (the release tick).
      expect(snap.events, hasLength(1));

      final ev = snap.events.first;
      expect(ev, isA<SwingEvent>());
      final swing = ev as SwingEvent;
      expect(swing.side, CourtSide.left);
      expect(swing.shotType, ShotType.toss);
      expect(swing.wasAirborne, isFalse); // server is grounded during serve
    });

    test('SwingResult.side is left for a left-side player', () {
      // This also validates Part A's addition of the `side` field.
      // M1-034: hold frame 0, release frame 1.
      final sim = Simulation(seed: 42)..start();
      sim.state.leftInputs.set(0, InputAction.toss);
      sim
        ..tick() // frame 0: charge
        ..tick(); // frame 1: release → swing fires

      expect(sim.lastTickSwings, hasLength(1));
      expect(sim.lastTickSwings.first.side, CourtSide.left);
    });
  });

  // -- lerp -------------------------------------------------------------------

  group('RenderState.lerp', () {
    /// Build two consecutive snapshots from a live simulation.
    /// Returns (frameA, frameB) where frameB is the tick after frameA.
    (RenderState, RenderState) twoFrames({int seed = 7}) {
      final sim = Simulation(seed: seed)..start();
      final a = RenderState.capture(sim);
      sim.tick();
      final b = RenderState.capture(sim);
      return (a, b);
    }

    test('at t=0 continuous fields equal a', () {
      final (a, b) = twoFrames();
      final result = RenderState.lerp(a, b, 0);
      expect(result.leftPlayer.x, closeTo(a.leftPlayer.x, 1e-9));
      expect(result.shuttle.x, closeTo(a.shuttle.x, 1e-9));
      expect(result.shuttle.y, closeTo(a.shuttle.y, 1e-9));
    });

    test('at t=1 continuous fields equal b', () {
      final (a, b) = twoFrames();
      final result = RenderState.lerp(a, b, 1);
      expect(result.leftPlayer.x, closeTo(b.leftPlayer.x, 1e-9));
      expect(result.shuttle.x, closeTo(b.shuttle.x, 1e-9));
      expect(result.shuttle.y, closeTo(b.shuttle.y, 1e-9));
    });

    test('at t=0.5 shuttle x is midpoint between a and b', () {
      final (a, b) = twoFrames();
      final result = RenderState.lerp(a, b, 0.5);
      final expectedX = (a.shuttle.x + b.shuttle.x) / 2;
      expect(result.shuttle.x, closeTo(expectedX, 1e-9));
    });

    test('at t=0.5 player x is midpoint between a and b', () {
      final (a, b) = twoFrames();
      final result = RenderState.lerp(a, b, 0.5);
      final expectedX = (a.leftPlayer.x + b.leftPlayer.x) / 2;
      expect(result.leftPlayer.x, closeTo(expectedX, 1e-9));
    });

    test('discrete fields are always taken from b', () {
      final (a, b) = twoFrames();
      final result = RenderState.lerp(a, b, 0.5);
      expect(result.frame, b.frame);
      expect(result.phase, b.phase);
      expect(result.leftScore, b.leftScore);
      expect(result.rightScore, b.rightScore);
      expect(result.server, b.server);
    });

    test('events are always const [] in a lerped state', () {
      // Create a toss so there is a real event in b.
      // M1-034: hold frame 0 to charge; release on frame 1 fires the serve.
      final sim = Simulation(seed: 7)..start();
      final a = RenderState.capture(sim);
      sim.state.leftInputs.set(0, InputAction.toss);
      sim
        ..tick() // frame 0: charge (servePending, no event)
        ..tick(); // frame 1: release → serve fires (SwingEvent in b)
      final b = RenderState.capture(sim);

      // b should have a SwingEvent from the toss release.
      expect(b.events, isNotEmpty);

      // Even though a.frame=0 and b.frame=2 (gap>1, snap rule), the lerp
      // contract always returns empty events — non-consecutive triggers snap.
      final lerped = RenderState.lerp(a, b, 0.5);
      expect(lerped.events, isEmpty);
    });

    test('t is clamped: t < 0 snaps to a, t > 1 snaps to b', () {
      final (a, b) = twoFrames();

      final atNeg = RenderState.lerp(a, b, -0.5);
      expect(atNeg.shuttle.x, closeTo(a.shuttle.x, 1e-9));

      final atOver = RenderState.lerp(a, b, 1.5);
      expect(atOver.shuttle.x, closeTo(b.shuttle.x, 1e-9));
    });

    test('snap rule: non-consecutive frames return b with empty events', () {
      final sim = Simulation(seed: 7)..start();
      final a = RenderState.capture(sim);
      // Skip a tick so b is 2 frames ahead.
      sim
        ..tick()
        ..tick();
      final b = RenderState.capture(sim);

      expect(b.frame, a.frame + 2); // gap > 1 triggers snap rule
      final result = RenderState.lerp(a, b, 0.5);
      // Should NOT interpolate — just return b's positions.
      expect(result.shuttle.x, closeTo(b.shuttle.x, 1e-9));
      expect(result.events, isEmpty);
    });

    test('snap rule: phase change returns b with empty events', () {
      // Drive a toss so a is servePending and b is inPlay.
      // M1-034: hold frame 0, release frame 1 — serve fires on tick 2.
      final sim = Simulation(seed: 7)..start();
      final a = RenderState.capture(sim);
      expect(a.phase, MatchPhase.servePending);
      sim.state.leftInputs.set(0, InputAction.toss);
      sim
        ..tick() // frame 0: charge
        ..tick(); // frame 1: release → inPlay
      final b = RenderState.capture(sim);
      expect(b.phase, MatchPhase.inPlay);

      // Phases differ (and frames are non-consecutive) → snap to b.
      final result = RenderState.lerp(a, b, 0.5);
      expect(result.shuttle.x, closeTo(b.shuttle.x, 1e-9));
      expect(result.events, isEmpty);
    });
  });

  // -- SwingResult.side (Part A) ---------------------------------------------

  group('SwingResult.side field', () {
    test('right-side player toss produces SwingResult with side = right', () {
      // M1-034: hold frame 0, release frame 1.
      final sim = Simulation(
        seed: 42,
        firstServer: CourtSide.right,
      )..start();
      sim.state.rightInputs.set(0, InputAction.toss);
      sim
        ..tick() // frame 0: charge
        ..tick(); // frame 1: release → swing fires

      expect(sim.lastTickSwings, hasLength(1));
      expect(sim.lastTickSwings.first.side, CourtSide.right);
    });

    test('SwingResult equality includes side field', () {
      // Two identical SwingResults with different sides must not be equal.
      // M1-034: hold frame 0, release frame 1 for both simulations.
      final sim = Simulation(seed: 42)..start();
      sim.state.leftInputs.set(0, InputAction.toss);
      sim
        ..tick() // frame 0: charge
        ..tick(); // frame 1: release → swing fires
      final leftSwing = sim.lastTickSwings.first;

      final sim2 = Simulation(
        seed: 42,
        firstServer: CourtSide.right,
      )..start();
      sim2.state.rightInputs.set(0, InputAction.toss);
      sim2
        ..tick() // frame 0: charge
        ..tick(); // frame 1: release → swing fires
      final rightSwing = sim2.lastTickSwings.first;

      // Same shotType and wasAirborne, different side → not equal.
      expect(leftSwing.side, CourtSide.left);
      expect(rightSwing.side, CourtSide.right);
      expect(leftSwing == rightSwing, isFalse);
    });
  });
}
