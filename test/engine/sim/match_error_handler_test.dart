import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/input/input_action.dart';
import 'package:smash_bros/engine/rules/match_phase.dart';
import 'package:smash_bros/engine/sim/match_error_handler.dart';
import 'package:smash_bros/engine/sim/simulation.dart';

void main() {
  group('MatchErrorHandler', () {
    test('a fault injected at frame F crashes safely with a full report', () {
      const faultFrame = 30;
      final sim = Simulation(seed: 1)..start();
      // Feed some input history so the report has something to capture.
      for (var f = 0; f <= faultFrame; f++) {
        sim.state.leftInputs.set(f, InputAction.moveRight);
        sim.state.rightInputs.set(f, InputAction.moveLeft);
      }
      sim.debugFaultInjector = () {
        if (sim.state.frame == faultFrame) {
          throw StateError('injected fault');
        }
      };

      final handler = MatchErrorHandler(sim);

      // Clean ticks up to the fault frame.
      for (var f = 0; f < faultFrame; f++) {
        expect(handler.safeTick(), isTrue);
      }

      // The fault tick: safeTick returns false and the handler has crashed.
      expect(handler.safeTick(), isFalse);
      expect(handler.hasCrashed, isTrue);

      final report = handler.crashReport!;
      expect(report.frame, faultFrame);
      expect(report.error, isA<StateError>());
      expect(report.stateSignature, isNotEmpty);

      // Recent inputs end at the fault frame and never exceed the cap.
      expect(
        report.recentInputs.length,
        lessThanOrEqualTo(kCrashInputHistoryFrames),
      );
      expect(report.recentInputs.last.frame, faultFrame);
      expect(report.recentInputs.last.leftBitmask, InputAction.moveRight);
      expect(report.recentInputs.last.rightBitmask, InputAction.moveLeft);

      // The match has been forced to terminate.
      expect(sim.state.fsm.phase, MatchPhase.matchOver);
    });

    test('further safeTick() calls are inert no-ops after a crash', () {
      final sim = Simulation(seed: 1)..start();
      sim.debugFaultInjector = () {
        if (sim.state.frame == 0) throw StateError('boom');
      };
      final handler = MatchErrorHandler(sim);

      expect(handler.safeTick(), isFalse);
      final firstReport = handler.crashReport;

      // Subsequent calls do nothing and keep returning false; the report is
      // unchanged.
      expect(handler.safeTick(), isFalse);
      expect(handler.safeTick(), isFalse);
      expect(handler.crashReport, same(firstReport));
    });

    test('the recent-input window is clamped to the cap on a late fault', () {
      const faultFrame = 200; // well beyond kCrashInputHistoryFrames (60)
      final sim = Simulation(seed: 1)..start();
      sim.debugFaultInjector = () {
        if (sim.state.frame == faultFrame) throw StateError('late fault');
      };
      final handler = MatchErrorHandler(sim);
      for (var f = 0; f < faultFrame; f++) {
        // Write inputs one frame ahead so the ring buffer never evicts a frame
        // before it is read.
        sim.state.leftInputs.set(sim.state.frame, InputAction.none);
        sim.state.rightInputs.set(sim.state.frame, InputAction.none);
        expect(handler.safeTick(), isTrue);
      }
      expect(handler.safeTick(), isFalse);

      final report = handler.crashReport!;
      expect(report.recentInputs.length, kCrashInputHistoryFrames);
      expect(
        report.recentInputs.first.frame,
        faultFrame - kCrashInputHistoryFrames + 1,
      );
      expect(report.recentInputs.last.frame, faultFrame);
    });

    test('a non-faulting run never crashes and ticks cleanly', () {
      final sim = Simulation(seed: 1)..start();
      sim.state.leftInputs.set(0, InputAction.toss);
      final handler = MatchErrorHandler(sim);
      for (var i = 0; i < 500; i++) {
        expect(handler.safeTick(), isTrue);
      }
      expect(handler.hasCrashed, isFalse);
      expect(handler.crashReport, isNull);
    });
  });
}
