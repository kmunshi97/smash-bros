import 'package:meta/meta.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/rules/match_fsm.dart';
import 'package:smash_bros/engine/sim/game_state.dart';
import 'package:smash_bros/engine/sim/simulation.dart';

/// One frame of input history captured in a [CrashReport].
@immutable
final class CrashInputFrame {
  /// Creates a record of the [frame]'s input bitmasks for both players.
  const CrashInputFrame({
    required this.frame,
    required this.leftBitmask,
    required this.rightBitmask,
  });

  /// The absolute frame number these inputs were read for.
  final int frame;

  /// The left player's raw input bitmask on [frame].
  final int leftBitmask;

  /// The right player's raw input bitmask on [frame].
  final int rightBitmask;

  @override
  bool operator ==(Object other) =>
      other is CrashInputFrame &&
      other.frame == frame &&
      other.leftBitmask == leftBitmask &&
      other.rightBitmask == rightBitmask;

  @override
  int get hashCode => Object.hash(frame, leftBitmask, rightBitmask);

  @override
  String toString() => 'f$frame: L=$leftBitmask R=$rightBitmask';
}

/// An immutable post-mortem of a simulation fault (M1-018).
///
/// Captures everything needed to reproduce and triage a crash: the [frame] the
/// fault struck, the [error] and [stackTrace], the [GameState.debugSignature]
/// at the moment of failure ([stateSignature]), and up to
/// [kCrashInputHistoryFrames] of [recentInputs] ending at [frame] so a replay
/// can re-feed the exact inputs that led there.
@immutable
final class CrashReport {
  /// Creates a crash report. All fields are captured at the failure point.
  const CrashReport({
    required this.frame,
    required this.error,
    required this.stackTrace,
    required this.stateSignature,
    required this.recentInputs,
  });

  /// The frame the fault occurred on.
  final int frame;

  /// The thrown error object.
  final Object error;

  /// The stack trace of the thrown error.
  final StackTrace stackTrace;

  /// The [GameState.debugSignature] captured at the failure point.
  final String stateSignature;

  /// The last (up to [kCrashInputHistoryFrames]) frames of input ending at
  /// [frame], oldest first. Frames evicted from the buffer are skipped.
  final List<CrashInputFrame> recentInputs;

  @override
  String toString() {
    final history = recentInputs.map((CrashInputFrame f) => '  $f').join('\n');
    return 'CrashReport(frame: $frame)\n'
        '  error: $error\n'
        '  state: $stateSignature\n'
        '  recentInputs (${recentInputs.length}):\n'
        '$history\n'
        '  stackTrace:\n$stackTrace';
  }
}

/// Wraps a [Simulation] so a thrown fault terminates the match gracefully
/// instead of propagating (M1-018).
///
/// ## Contract
///
/// [safeTick] runs one [Simulation.tick] inside a try/catch. On a clean tick it
/// returns `true`. On **any** thrown error it captures a [CrashReport]
/// (signature + recent inputs), marks the handler [hasCrashed], aborts the FSM
/// to `matchOver` via [MatchFsm.abortMatch] so the match cannot wedge, and
/// returns `false`. Every subsequent [safeTick] is a no-op returning `false`:
/// once crashed, the simulation is not trusted to advance again.
final class MatchErrorHandler {
  /// Wraps [simulation] with crash-safe ticking.
  MatchErrorHandler(this.simulation);

  /// The wrapped simulation.
  final Simulation simulation;

  CrashReport? _crashReport;

  /// The captured crash report, or `null` if no fault has occurred.
  CrashReport? get crashReport => _crashReport;

  /// Whether a fault has been caught.
  bool get hasCrashed => _crashReport != null;

  /// Runs one simulation tick safely.
  ///
  /// Returns `true` on a clean tick. On a thrown fault it records the
  /// [crashReport], aborts the match to `matchOver`, and returns `false`. Once
  /// [hasCrashed], further calls are inert no-ops returning `false`.
  bool safeTick() {
    if (hasCrashed) return false;

    try {
      simulation.tick();
      return true;
    } on Object catch (error, stackTrace) {
      _capture(error, stackTrace);
      return false;
    }
  }

  /// Builds the crash report and forces the match to terminate.
  void _capture(Object error, StackTrace stackTrace) {
    final state = simulation.state;
    _crashReport = CrashReport(
      frame: state.frame,
      error: error,
      stackTrace: stackTrace,
      stateSignature: state.debugSignature,
      recentInputs: _captureRecentInputs(),
    );
    state.fsm.abortMatch(state.frame, 'simulation fault: $error');
  }

  /// Reads up to [kCrashInputHistoryFrames] of input history ending at the
  /// current frame, clamping at frame 0 and skipping any frame already evicted
  /// from a buffer.
  List<CrashInputFrame> _captureRecentInputs() {
    final state = simulation.state;
    final frame = state.frame;
    final oldest = frame - kCrashInputHistoryFrames + 1;
    final from = oldest < 0 ? 0 : oldest;

    final history = <CrashInputFrame>[];
    for (var f = from; f <= frame; f++) {
      final int left;
      final int right;
      try {
        left = state.inputsOn(CourtSide.left).get(f);
        right = state.inputsOn(CourtSide.right).get(f);
      }
      // InputBuffer.get throws ArgumentError for an evicted frame; catching it
      // is the sanctioned way to skip frames that have aged out of the ring.
      // ignore: avoid_catching_errors
      on ArgumentError {
        // The frame fell outside the retained ring window; skip it gracefully.
        continue;
      }
      history.add(
        CrashInputFrame(frame: f, leftBitmask: left, rightBitmask: right),
      );
    }
    return history;
  }
}
