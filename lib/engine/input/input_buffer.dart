import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/input/input_action.dart';

/// A fixed-capacity ring buffer storing one frame's input bitmask per entry,
/// indexed by *absolute* frame number.
///
/// ## Purpose
///
/// The rollback-netcode layer (Milestone 3) re-reads up to [kMaxRollbackFrames]
/// of inputs when reconciling a mis-predicted state.  [InputBuffer] is therefore
/// sized to exactly [kMaxRollbackFrames] by default, guaranteeing that any frame
/// within the rollback window is retrievable without allocation.
///
/// ## Indexing
///
/// Absolute frame numbers are mapped onto the backing list via
/// `frame % capacity`, so arbitrarily large frame counters work without ever
/// growing the buffer.
///
/// ## The stale-slot hazard
///
/// Because the modulo index wraps, frame `N` and frame `N + capacity` occupy
/// the **same slot**.  If a caller skips forward by more than one frame — e.g.
/// writes frame 0 then jumps directly to frame 100 — the slots for frames 1..99
/// still hold whatever was written `capacity` frames earlier.  Reading them
/// would silently return stale data from a previous cycle.
///
/// To prevent this, [set] **clears every slot** between the previous newest
/// frame and the new frame (exclusive) whenever it detects a gap larger than
/// one.  See [set] for the exact invariant.
final class InputBuffer {
  /// Creates a buffer that retains the most recent [capacity] frames of input.
  ///
  /// [capacity] defaults to [kMaxRollbackFrames] so the rollback layer can
  /// always re-read its full rewind window.
  InputBuffer({int capacity = kMaxRollbackFrames})
    : _capacity = capacity,
      _data = List<int>.filled(capacity, InputAction.none);

  final int _capacity;
  final List<int> _data;
  int _newestFrame = -1;

  /// Highest frame number ever stored, or `-1` if the buffer is empty.
  int get newestFrame => _newestFrame;

  /// Stores [bitmask] as the input for [frame].
  ///
  /// ### Stale-slot clearing
  ///
  /// If [frame] is more than one ahead of the current [newestFrame], the slots
  /// for frames `newestFrame + 1 .. frame - 1` are cleared to
  /// [InputAction.none] before writing [frame].  This prevents a read of any
  /// skipped frame from returning a value written `capacity` frames ago —
  /// the classic ring-buffer stale-data hazard.
  ///
  /// ### Eviction guard
  ///
  /// Throws [ArgumentError] if [frame] is more than [_capacity] frames behind
  /// the current [newestFrame]: that slot has already been overwritten and the
  /// caller's history reference is stale.
  void set(int frame, int bitmask) {
    if (_newestFrame >= 0 && frame <= _newestFrame - _capacity) {
      throw ArgumentError(
        'Frame $frame has already been evicted '
        '(newestFrame=$_newestFrame, capacity=$_capacity).',
      );
    }

    // Clear any skipped slots to guard against stale-data reads.
    if (_newestFrame >= 0 && frame > _newestFrame + 1) {
      for (var f = _newestFrame + 1; f < frame; f++) {
        _data[f % _capacity] = InputAction.none;
      }
    }

    _data[frame % _capacity] = bitmask;
    if (frame > _newestFrame) {
      _newestFrame = frame;
    }
  }

  /// Returns the stored bitmask for [frame].
  ///
  /// Returns [InputAction.none] for any frame within the retained window that
  /// was never explicitly set (including slots cleared by the stale-slot logic
  /// in [set]).
  ///
  /// Throws [ArgumentError] if [frame] is older than the retained window
  /// (`frame <= newestFrame - capacity`).
  int get(int frame) {
    if (_newestFrame >= 0 && frame <= _newestFrame - _capacity) {
      throw ArgumentError(
        'Frame $frame has already been evicted '
        '(newestFrame=$_newestFrame, capacity=$_capacity).',
      );
    }
    return _data[frame % _capacity];
  }

  /// Returns an independent deep copy of this buffer.
  ///
  /// Used by the rollback snapshot system to capture a point-in-time image of
  /// the input history without sharing mutable state with the live buffer.
  InputBuffer copy() {
    final clone = InputBuffer(capacity: _capacity);
    clone._data.setAll(0, _data);
    clone._newestFrame = _newestFrame;
    return clone;
  }
}
