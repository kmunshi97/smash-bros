import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/entities/tunables.dart';
import 'package:smash_bros/engine/input/input_action.dart';
import 'package:smash_bros/engine/input/input_buffer.dart';
import 'package:smash_bros/engine/math/fix.dart';
import 'package:smash_bros/engine/rules/match_phase.dart';
import 'package:smash_bros/engine/rules/point_reason.dart';
import 'package:smash_bros/engine/sim/game_state.dart';
import 'package:smash_bros/engine/sim/simulation.dart';
import 'package:smash_bros/engine/systems/collision_system.dart';

/// Writes [bitmask] to [buffer] for the inclusive frame range [from]..[to].
void _hold(InputBuffer buffer, int bitmask, int from, int to) {
  for (var f = from; f <= to; f++) {
    buffer.set(f, bitmask);
  }
}

/// Queues a serve for [sim]'s server player at the current frame.
///
/// Hold-to-charge semantics (M1-034): the toss bit must be HIGH for
/// [holdTicks] consecutive frames and then LOW for one frame before the launch
/// fires. The minimum is [holdTicks] = 1 (hold one tick, release the next).
///
/// After calling, advance the simulation by [holdTicks] + 1 ticks to consume
/// the queued serve.
void _enqueueServe(Simulation sim, {int holdTicks = 1}) {
  final f = sim.state.frame;
  final serverSide = sim.state.fsm.server;
  final buf = sim.state.inputsOn(serverSide);
  // Hold toss bit for holdTicks consecutive frames.
  for (var i = 0; i < holdTicks; i++) {
    buf.set(f + i, InputAction.toss);
  }
  // Frame f + holdTicks has no toss bit (default InputAction.none) → release.
}

/// Ticks [sim] until [test] holds or [maxTicks] elapse; returns the tick count.
int _tickUntil(Simulation sim, bool Function() test, {int maxTicks = 100000}) {
  var ticks = 0;
  while (!test() && ticks < maxTicks) {
    sim.tick();
    ticks++;
  }
  return ticks;
}

void main() {
  group('start()', () {
    test('transitions to servePending and parks the shuttle for a LEFT '
        'server toward the net at the serve height', () {
      final sim = Simulation(seed: 1)..start();
      expect(sim.state.fsm.phase, MatchPhase.servePending);
      // Left server: shuttle is offset toward the net (rightward, +x).
      expect(
        sim.state.shuttle.position.x,
        const Fix.of(kPlayer1StartX + kServeShuttleOffsetX),
      );
      expect(
        sim.state.shuttle.position.y,
        Tunables.groundY - Tunables.serveShuttleHeight,
      );
      expect(sim.state.shuttle.velocity.x, Fix.zero);
      expect(sim.state.shuttle.velocity.y, Fix.zero);
    });

    test('parks the shuttle for a RIGHT server toward the net (−x)', () {
      final sim = Simulation(seed: 1, firstServer: CourtSide.right)..start();
      expect(
        sim.state.shuttle.position.x,
        const Fix.of(kPlayer2StartX - kServeShuttleOffsetX),
      );
      expect(
        sim.state.shuttle.position.y,
        Tunables.groundY - Tunables.serveShuttleHeight,
      );
    });

    test('asserts if called twice', () {
      final sim = Simulation(seed: 1)..start();
      expect(sim.start, throwsA(isA<AssertionError>()));
    });
  });

  group('serve flow', () {
    test('a toss launches the serve upward toward play and reaches inPlay '
        '(M1-034: hold frame 0, release frame 1)', () {
      final sim = Simulation(seed: 1)..start();
      // Hold-to-charge: hold toss on frame 0, release on frame 1.
      _enqueueServe(sim); // holdTicks=1: sets frame 0, frame 1 is none.
      sim.tick(); // frame 0: toss bit HIGH → charge accumulates, still servePending.
      expect(
        sim.state.fsm.phase,
        MatchPhase.servePending,
        reason: 'Holding toss must NOT immediately launch the serve.',
      );
      sim.tick(); // frame 1: toss bit absent → release → launch.

      expect(sim.state.fsm.phase, MatchPhase.inPlay);
      // The toss is an upward lob: negative y velocity (up the screen) and a
      // rightward (+x, toward the receiver) component for a left server.
      expect(sim.state.shuttle.velocity.y.toDouble(), lessThan(0));
      expect(sim.state.shuttle.velocity.x.toDouble(), greaterThan(0));
    });

    test('an empty serve times out and awards the point to the receiver, '
        'then returns to servePending', () {
      final sim = Simulation(seed: 1)..start();
      // No inputs at all. Tick past the timeout AND the point pause.
      for (var i = 0; i < kServeTimeoutFrames + kPointPauseTicks + 2; i++) {
        sim.tick();
      }
      // Receiver of the opening (left) serve is the right side.
      expect(sim.state.fsm.scoreboard.rightScore, 1);
      expect(sim.state.fsm.scoreboard.leftScore, 0);
      expect(sim.state.fsm.phase, MatchPhase.servePending);
      // The point winner serves next (v3 ruleset).
      expect(sim.state.fsm.server, CourtSide.right);
    });
  });

  group('zero-input full match', () {
    test('alternating serve timeouts end the match right 15 - left 14', () {
      // With NO inputs, every serve times out and the RECEIVER wins the point,
      // then becomes the server. So the receiver-of-point-1 (right) wins the
      // odd points and the original server (left) wins the even points; points
      // alternate after the first. Working the arithmetic to the default
      // target of 11 (cap 15): the score climbs to 14-14 (deuce) and the next
      // point is the golden point. The side that wins the ODD points (right)
      // reaches the cap first, so the final is right 15 - left 14 over 29
      // points, with the match ending in matchOver.
      final sim = Simulation(seed: 1)..start();
      // 29 points are needed; each is at most a full timeout plus a point
      // pause. Bound generously so a regression that fails to end the match is
      // caught rather than spinning forever.
      const bound = 30 * (kServeTimeoutFrames + kPointPauseTicks) + 1000;
      _tickUntil(
        sim,
        () => sim.state.fsm.phase == MatchPhase.matchOver,
        maxTicks: bound,
      );

      expect(sim.state.fsm.phase, MatchPhase.matchOver);
      expect(sim.state.fsm.scoreboard.rightScore, 15);
      expect(sim.state.fsm.scoreboard.leftScore, 14);
      expect(sim.state.fsm.scoreboard.winner, CourtSide.right);
    });
  });

  group('movement', () {
    test('holding moveRight slides the left player right, bounded and never '
        'past the net', () {
      final sim = Simulation(seed: 1)..start();
      final startX = sim.state.leftPlayer.x;
      _hold(sim.state.leftInputs, InputAction.moveRight, 0, 59);
      for (var i = 0; i < 60; i++) {
        sim.tick();
      }
      final endX = sim.state.leftPlayer.x;
      final moved = endX - startX;
      // Moved rightward, by at most 60 * speed (clamping/stamina only reduce it).
      expect(moved.toDouble(), greaterThan(0));
      expect(
        moved.toDouble(),
        lessThanOrEqualTo(60 * kPlayerSpeed + 0.001),
      );
      // Never crosses to the right of the net (hitbox right edge <= netX).
      expect(
        sim.state.leftPlayer.hitboxRight.toDouble(),
        lessThanOrEqualTo(Tunables.netX.toDouble()),
      );
    });
  });

  group('stamina', () {
    test('holding movement drains stamina; idling regenerates it', () {
      final sim = Simulation(seed: 1)..start();
      final full = sim.state.leftPlayer.stamina;

      _hold(sim.state.leftInputs, InputAction.moveLeft, 0, 19);
      for (var i = 0; i < 20; i++) {
        sim.tick();
      }
      final drained = sim.state.leftPlayer.stamina;
      expect(drained.toDouble(), lessThan(full.toDouble()));

      // Now idle (no inputs) and watch it climb back.
      for (var i = 0; i < 20; i++) {
        sim.tick();
      }
      expect(
        sim.state.leftPlayer.stamina.toDouble(),
        greaterThan(drained.toDouble()),
      );
    });
  });

  group('scripted point from a real serve', () {
    test('a toss crosses the net and lands in the receiver half — '
        'server wins the point (or short-serve fault)', () {
      // M1-034: hold-to-charge — hold for 1 tick then release.
      // kTossSpeedMin (@43°) lands at ≈ 866, past the short-service line (840),
      // so this should be groundedIn. Either groundedIn or shortServeFault
      // confirms net-crossing.
      final sim = Simulation(seed: 1)..start();
      _enqueueServe(sim); // hold frame 0, release frame 1

      GroundHit? landing;
      _tickUntil(sim, () {
        for (final e in sim.lastTickCollisions) {
          if (e is GroundHit) landing = e;
        }
        return sim.state.fsm.phase == MatchPhase.pointScored;
      }, maxTicks: 2000);

      expect(landing, isNotNull);
      expect(landing!.isInBounds, isTrue);
      // With the tuned constants the shuttle reaches the RIGHT half.
      expect(landing!.side, CourtSide.right);
      // The point reason is either groundedIn (server wins, shuttle past the
      // short-service line) or shortServeFault (receiver wins, shuttle in
      // the 640–840 zone).  Both confirm net-crossing.
      expect(
        sim.state.fsm.lastPointReason,
        anyOf(PointReason.groundedIn, PointReason.shortServeFault),
      );
    });
  });

  group('presentation outputs', () {
    test('lastTickSwings is populated on the release tick and cleared after '
        '(M1-034: swing fires on the bit-LOW frame)', () {
      final sim = Simulation(seed: 1)..start();
      // Hold frame 0 (charge), release frame 1 (launch).
      _enqueueServe(sim); // holdTicks=1
      sim.tick(); // frame 0: charging — no swing yet
      expect(
        sim.lastTickSwings,
        isEmpty,
        reason: 'No swing should fire while the toss bit is still held.',
      );
      sim.tick(); // frame 1: release → toss connects
      expect(sim.lastTickSwings, hasLength(1));

      sim.tick(); // a quiet in-play tick: no new swing
      expect(sim.lastTickSwings, isEmpty);
    });

    test('lastTickCollisions is populated on the landing tick', () {
      final sim = Simulation(seed: 1)..start();
      _enqueueServe(sim); // hold frame 0, release frame 1
      // frame 0: charging; frame 1: launch → inPlay
      sim
        ..tick()
        ..tick();
      var sawCollision = false;
      _tickUntil(sim, () {
        if (sim.lastTickCollisions.isNotEmpty) sawCollision = true;
        return sim.state.fsm.phase != MatchPhase.inPlay;
      }, maxTicks: 2000);
      expect(sawCollision, isTrue);
      // Once the point is scored we are no longer inPlay, so no collisions are
      // produced on the very next tick.
      sim.tick();
      expect(sim.lastTickCollisions, isEmpty);
    });
  });

  group('determinism (M1-019 headline)', () {
    test('two same-seed sims with identical scripted inputs stay '
        'byte-identical at EVERY frame across 10k ticks', () {
      final a = Simulation(seed: 20240611)..start();
      final b = Simulation(seed: 20240611)..start();

      // A rich, identical input script for both: a serve (hold+release),
      // jumps, movement and shot attempts spread across the first few hundred
      // frames.
      for (final sim in [a, b]) {
        // M1-034: hold frame 0 (charge), release frame 1.
        sim.state.leftInputs.set(0, InputAction.toss);
        // frame 1 has no toss bit → release (default InputAction.none).
        _hold(sim.state.leftInputs, InputAction.moveRight, 2, 41);
        _hold(
          sim.state.leftInputs,
          InputAction.jump | InputAction.smash,
          41,
          60,
        );
        _hold(sim.state.rightInputs, InputAction.moveLeft, 5, 50);
        _hold(sim.state.rightInputs, InputAction.jump, 51, 52);
        _hold(sim.state.rightInputs, InputAction.normalShot, 60, 120);
        _hold(sim.state.leftInputs, InputAction.dropShot, 200, 260);
        _hold(sim.state.rightInputs, InputAction.smash, 200, 260);
      }

      expect(a.state.debugSignature, b.state.debugSignature);
      for (var i = 0; i < 10000; i++) {
        a.tick();
        b.tick();
        // Compare EVERY frame, not just the end: the first divergent frame is
        // the desync frame.
        if (a.state.debugSignature != b.state.debugSignature) {
          fail(
            'Desync at tick ${i + 1}:\n'
            'A: ${a.state.debugSignature}\n'
            'B: ${b.state.debugSignature}',
          );
        }
      }
    });
  });

  group('stability stress', () {
    test('repeated max-power smashes never exceed the shuttle speed cap and '
        'keep the shuttle within generous world bounds', () {
      final sim = Simulation(seed: 5)..start();
      // Serve (hold frame 0, release frame 1), then both sides mash smash +
      // jump forever. Inputs are written one frame ahead inside the loop so
      // the ring buffer never evicts a frame before it is read.
      sim.state.leftInputs.set(0, InputAction.toss); // hold frame 0
      // frame 1 has no toss bit → release → launch

      for (var i = 0; i < 5000; i++) {
        final f = sim.state.frame;
        if (f >= 2) {
          sim.state.leftInputs.set(f, InputAction.jump | InputAction.smash);
        }
        sim.state.rightInputs.set(f, InputAction.jump | InputAction.smash);
        sim.tick();
        final v = sim.state.shuttle.velocity.magnitude;
        expect(
          v.toDouble(),
          lessThanOrEqualTo(Tunables.shuttleMaxVelocity.toDouble() + 0.001),
        );
        final p = sim.state.shuttle.position;
        expect(p.x.abs().toDouble(), lessThan(5000));
        expect(p.y.toDouble(), lessThan(kGroundY + 1));
      }
    });
  });

  // ---------------------------------------------------------------------------
  // M1-034: hold-to-charge serve
  // ---------------------------------------------------------------------------

  group('hold-to-charge serve (M1-034)', () {
    test('holding N ticks then releasing fires SwingEvent on the release tick '
        'and launch speed matches lerped expectation', () {
      const holdTicks = 20; // charge fraction = 20/45 ≈ 0.444

      final sim = Simulation(seed: 1)..start();
      _enqueueServe(sim, holdTicks: holdTicks);

      // Tick through the hold frames — no swing should fire.
      for (var i = 0; i < holdTicks; i++) {
        sim.tick();
        expect(
          sim.lastTickSwings,
          isEmpty,
          reason: 'No swing while toss bit still held (tick $i).',
        );
        expect(sim.state.fsm.phase, MatchPhase.servePending);
      }

      // One more tick (release frame) — swing must fire.
      sim.tick();
      expect(
        sim.lastTickSwings,
        hasLength(1),
        reason: 'SwingEvent must fire on the release tick.',
      );
      expect(sim.state.fsm.phase, MatchPhase.inPlay);

      // Verify launch speed is within [kTossSpeedMin, kTossSpeedMax].
      // Stamina multiplier is ~1.0 at full stamina, so speed should be very
      // close to the raw lerped value.
      final launchVx = sim.lastTickSwings.first.launchVelocity.x.toDouble();
      final launchVy = sim.lastTickSwings.first.launchVelocity.y.toDouble();
      final launchSpeed = math.sqrt(launchVx * launchVx + launchVy * launchVy);
      const chargeFraction = holdTicks / kServeChargeMaxTicks;
      const expectedSpeed =
          kTossSpeedMin + (kTossSpeedMax - kTossSpeedMin) * chargeFraction;
      // Allow ±0.1 for floating-point rounding through Fix.
      expect(
        launchSpeed,
        closeTo(expectedSpeed, 0.1),
        reason: 'Launch speed must match lerp(min, max, $chargeFraction).',
      );
    });

    test('charge caps at kServeChargeMaxTicks — holding 100 ticks gives the '
        'same speed as holding kServeChargeMaxTicks ticks', () {
      double runAndGetSpeed(int holdTicks) {
        final sim = Simulation(seed: 1)..start();
        _enqueueServe(sim, holdTicks: holdTicks);
        for (var i = 0; i <= holdTicks; i++) {
          sim.tick();
        }
        final vx = sim.lastTickSwings.first.launchVelocity.x.toDouble();
        final vy = sim.lastTickSwings.first.launchVelocity.y.toDouble();
        return math.sqrt(vx * vx + vy * vy);
      }

      final speedMax = runAndGetSpeed(kServeChargeMaxTicks);
      final speedOverflow = runAndGetSpeed(100); // exceeds cap
      expect(
        speedOverflow,
        closeTo(speedMax, 0.001),
        reason:
            'Speed at holdTicks=100 must equal speed at kServeChargeMaxTicks '
            '(charge is clamped).',
      );
    });

    test(
      'timeout mid-charge → fault to receiver and serveChargeTicks reset',
      () {
        final sim = Simulation(seed: 1)..start();
        // Start charging but never release — let the serve time out.
        // Timeout fires at kServeTimeoutFrames ticks.
        for (var f = 0; f < kServeTimeoutFrames; f++) {
          sim.state.leftInputs.set(f, InputAction.toss); // hold every frame
        }
        // Tick past the timeout.
        for (var i = 0; i < kServeTimeoutFrames + 1; i++) {
          sim.tick();
        }
        // The FSM awarded the point to the receiver (right side).
        expect(
          sim.state.fsm.phase,
          anyOf(MatchPhase.pointScored, MatchPhase.servePending),
          reason: 'After timeout the point must be scored.',
        );
        // serveChargeTicks must be reset to 0 after the timeout.
        expect(
          sim.state.serveChargeTicks,
          0,
          reason: 'serveChargeTicks must be reset to 0 after a timeout.',
        );
      },
    );

    test('serveChargeTicks appears in debugSignature — two states differing '
        'only in charge produce different signatures', () {
      final a = GameState(seed: 1);
      final b = GameState(seed: 1)..serveChargeTicks = 10;
      expect(
        a.debugSignature,
        isNot(b.debugSignature),
        reason:
            'debugSignature must include serveChargeTicks so rollback can '
            'detect desync in charge state.',
      );
    });

    test('GameState.copy preserves serveChargeTicks', () {
      final original = GameState(seed: 1)..serveChargeTicks = 23;
      final clone = original.copy();
      expect(
        clone.serveChargeTicks,
        23,
        reason: 'copy() must deep-copy serveChargeTicks.',
      );
      clone.serveChargeTicks = 99;
      expect(
        original.serveChargeTicks,
        23,
        reason: 'Mutating the copy must not affect the original.',
      );
    });
  });

  group('serve shuttle pin (M1-014b)', () {
    /// The expected parked shuttle x for the left server's current position.
    Fix expectedPinX(Simulation sim) =>
        sim.state.leftPlayer.x + Tunables.serveShuttleOffsetX;

    test('shuttle tracks the server while walking during servePending', () {
      final sim = Simulation(seed: 1)..start();
      expect(sim.state.fsm.phase, MatchPhase.servePending);
      expect(sim.state.fsm.server, CourtSide.left);

      // Walk the left server right for 30 ticks; the shuttle must keep the
      // serve offset relative to the server's hand on every tick.
      _hold(sim.state.leftInputs, InputAction.moveRight, 0, 29);
      for (var i = 0; i < 30; i++) {
        sim.tick();
        expect(
          sim.state.shuttle.position.x.toDouble(),
          closeTo(expectedPinX(sim).toDouble(), 1e-9),
          reason: 'tick $i: parked shuttle must track the server x',
        );
        expect(
          sim.state.shuttle.position.y.toDouble(),
          closeTo(
            (Tunables.groundY - Tunables.serveShuttleHeight).toDouble(),
            1e-9,
          ),
          reason: 'tick $i: parked shuttle stays at the serve height',
        );
      }
      // Sanity: the server actually moved (the pin is being exercised).
      expect(
        sim.state.leftPlayer.x.toDouble(),
        greaterThan(kPlayer1StartX),
        reason: 'precondition: the server must have walked rightward',
      );
    });

    test('shuttle does NOT follow the receiver during servePending', () {
      final sim = Simulation(seed: 1)..start();
      expect(sim.state.fsm.server, CourtSide.left);

      final parkedX = sim.state.shuttle.position.x.toDouble();
      // Walk the RECEIVER (right player); the server stays put.
      _hold(sim.state.rightInputs, InputAction.moveLeft, 0, 29);
      for (var i = 0; i < 30; i++) {
        sim.tick();
      }
      expect(
        sim.state.shuttle.position.x.toDouble(),
        closeTo(parkedX, 1e-9),
        reason: 'receiver movement must not drag the parked shuttle',
      );
    });

    test('pin releases once the toss launches (shuttle flies in inPlay)', () {
      final sim = Simulation(seed: 1)..start();
      _enqueueServe(sim, holdTicks: 5);
      _tickUntil(sim, () => sim.state.fsm.phase == MatchPhase.inPlay);
      expect(sim.state.fsm.phase, MatchPhase.inPlay);

      // Let the shuttle fly: its y must change across ticks (no longer
      // pinned at the serve height).
      final y0 = sim.state.shuttle.position.y.toDouble();
      sim
        ..tick()
        ..tick();
      expect(
        sim.state.shuttle.position.y.toDouble(),
        isNot(closeTo(y0, 1e-9)),
        reason: 'after launch the shuttle must be in free flight, not pinned',
      );
    });
  });
}
