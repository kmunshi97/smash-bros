import 'package:smash_bros/engine/math/fix.dart';

/// The engine's deterministic pseudo-random number generator (ADR-8).
///
/// All gameplay randomness — shot-angle spread, AI decision noise — must
/// flow through the single [GameRandom] instance owned by the game state.
/// Never use `dart:math`'s `Random` in engine code: its sequence is not
/// part of the simulation state, so replays and netcode rollback would
/// silently diverge.
///
/// Implementation: xoshiro128++ with explicit 32-bit masking, so the
/// sequence is bit-identical on every platform regardless of native int
/// width. The full generator state is four 32-bit lanes, exposed via
/// [state] / [GameRandom.fromState] for snapshots, replays, and rollback.
final class GameRandom {
  /// Creates a generator from a single integer [seed].
  ///
  /// The seed is expanded into the four internal lanes with a splitmix32
  /// sequence, so any seed value (including 0) produces a valid,
  /// well-mixed state.
  GameRandom(int seed) {
    var x = seed & _mask32;
    for (var i = 0; i < _state.length; i++) {
      // splitmix32 step: increment by the golden-ratio constant, then mix.
      x = (x + 0x9E3779B9) & _mask32;
      var z = x;
      z = (z ^ (z >> 16)) * 0x21F0AAAD & _mask32;
      z = (z ^ (z >> 15)) * 0x735A2D97 & _mask32;
      _state[i] = (z ^ (z >> 15)) & _mask32;
    }
  }

  /// Restores a generator from a previously captured [state].
  GameRandom.fromState(List<int> state) {
    if (state.length != 4) {
      throw ArgumentError.value(state, 'state', 'must have exactly 4 lanes');
    }
    if (state.every((int lane) => lane == 0)) {
      throw ArgumentError.value(state, 'state', 'must not be all zero');
    }
    for (var i = 0; i < 4; i++) {
      _state[i] = state[i] & _mask32;
    }
  }

  static const int _mask32 = 0xFFFFFFFF;

  final List<int> _state = List<int>.filled(4, 0);

  /// A copy of the generator state, for snapshots and serialization.
  List<int> get state => List<int>.unmodifiable(_state);

  static int _rotl(int value, int amount) =>
      ((value << amount) | (value >> (32 - amount))) & _mask32;

  /// The next raw 32-bit unsigned value in the sequence.
  int nextUint32() {
    final result =
        (_rotl((_state[0] + _state[3]) & _mask32, 7) + _state[0]) & _mask32;
    final t = (_state[1] << 9) & _mask32;
    _state[2] ^= _state[0];
    _state[3] ^= _state[1];
    _state[1] ^= _state[2];
    _state[0] ^= _state[3];
    _state[2] ^= t;
    _state[3] = _rotl(_state[3], 11);
    return result;
  }

  /// A uniform integer in `[0, maxExclusive)`.
  ///
  /// Uses rejection sampling, so the distribution is unbiased for any
  /// [maxExclusive] up to 2^32.
  int nextInt(int maxExclusive) {
    if (maxExclusive <= 0) {
      throw ArgumentError.value(
        maxExclusive,
        'maxExclusive',
        'must be positive',
      );
    }
    final threshold = (_mask32 + 1) - (_mask32 + 1) % maxExclusive;
    int candidate;
    do {
      candidate = nextUint32();
    } while (candidate >= threshold);
    return candidate % maxExclusive;
  }

  /// `true` or `false` with equal probability.
  bool nextBool() => nextUint32().isOdd;

  /// A uniform scalar in `[min, max)`.
  ///
  /// Quantized to 2^20 steps across the range — far finer than gameplay
  /// needs, and deliberately *not* dependent on double bit-patterns so the
  /// Milestone 3 fixed-point swap preserves sequences exactly.
  Fix nextFixRange(Fix min, Fix max) {
    const steps = 1 << 20;
    final t = Fix.fromInt(nextInt(steps)) / const Fix.fromInt(steps);
    return min + (max - min) * t;
  }
}
