import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/entities/tunables.dart';
import 'package:smash_bros/engine/input/input_action.dart';
import 'package:smash_bros/engine/input/input_buffer.dart';
import 'package:smash_bros/engine/math/fix.dart';
import 'package:smash_bros/engine/rules/match_phase.dart';
import 'package:smash_bros/engine/rules/point_reason.dart';
import 'package:smash_bros/engine/sim/simulation.dart';
import 'package:smash_bros/engine/systems/collision_system.dart';

/// Writes [bitmask] to [buffer] for the inclusive frame range [from]..[to].
void _hold(InputBuffer buffer, int bitmask, int from, int to) {
  for (var f = from; f <= to; f++) {
    buffer.set(f, bitmask);
  }
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
    test('a toss launches the serve upward toward play and reaches inPlay', () {
      final sim = Simulation(seed: 1)..start();
      sim.state.leftInputs.set(0, InputAction.toss);
      sim.tick(); // frame 0: the toss is consumed in the phase pump.

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
      // M1-032a: the serve constants were tuned so the toss reaches the
      // receiver's half of the court.  A shuttle landing IN on the right
      // half means the LEFT (server) wins the point via groundedIn.
      // If the serve lands short of the short-service line (640–840), the
      // receiver wins via shortServeFault instead.  Either outcome confirms
      // the shuttle crossed the net — the old KNOWN-BROKEN behaviour (serve
      // falls back on the server's own half) is hereby inverted.
      final sim = Simulation(seed: 1)..start();
      sim.state.leftInputs.set(0, InputAction.toss);

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
      // the 640–840 zone).  Both confirm net-crossing — a landing on the
      // LEFT half (groundedIn + pointWinner = right) would mean regression.
      expect(
        sim.state.fsm.lastPointReason,
        anyOf(PointReason.groundedIn, PointReason.shortServeFault),
      );
    });
  });

  group('presentation outputs', () {
    test('lastTickSwings is populated on the toss tick and cleared after', () {
      final sim = Simulation(seed: 1)..start();
      sim.state.leftInputs.set(0, InputAction.toss);
      sim.tick(); // toss connects this tick
      expect(sim.lastTickSwings, hasLength(1));

      sim.tick(); // a quiet in-play tick: no new swing
      expect(sim.lastTickSwings, isEmpty);
    });

    test('lastTickCollisions is populated on the landing tick', () {
      final sim = Simulation(seed: 1)..start();
      sim.state.leftInputs.set(0, InputAction.toss);
      sim.tick(); // consume the toss -> inPlay
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

      // A rich, identical input script for both: a serve, jumps, movement and
      // shot attempts spread across the first few hundred frames.
      for (final sim in [a, b]) {
        sim.state.leftInputs.set(0, InputAction.toss);
        _hold(sim.state.leftInputs, InputAction.moveRight, 1, 40);
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
      // Serve, then both sides mash smash + jump forever. Inputs are written
      // one frame ahead inside the loop so the ring buffer never evicts a frame
      // before it is read (writing 5000 frames up front would).
      sim.state.leftInputs.set(0, InputAction.toss);

      for (var i = 0; i < 5000; i++) {
        final f = sim.state.frame;
        if (f >= 1) {
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
}
