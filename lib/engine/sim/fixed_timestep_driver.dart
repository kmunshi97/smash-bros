import 'package:smash_bros/engine/constants.dart';

/// Decouples the 60 Hz simulation from the display refresh rate (ADR-7).
///
/// Display-driven callbacks (`Ticker`, `FlameGame.update`) fire at whatever
/// rate the screen refreshes — 60, 90, or 120 Hz, with jitter. Stepping the
/// simulation once per callback would make the game literally run twice as
/// fast on a 120 Hz phone. Instead, callers feed wall-clock elapsed time
/// into [advance], and the driver issues zero or more fixed [kTickDuration]
/// ticks, banking any remainder for the next call.
///
/// Position in the architecture: the rendering layer owns one driver and
/// calls [advance] each frame; [onTick] advances the `Simulation` by exactly
/// one tick. [alpha] lets the renderer interpolate between the last two
/// simulation states for smooth motion at refresh rates above 60 Hz.
final class FixedTimestepDriver {
  /// Creates a driver that invokes [onTick] once per simulation tick.
  FixedTimestepDriver({
    required this.onTick,
    this.maxTicksPerAdvance = 5,
  });

  /// Advances the simulation by exactly one fixed tick.
  final void Function() onTick;

  /// Upper bound on ticks issued by a single [advance] call.
  ///
  /// Guards against the "spiral of death": after a long frame hitch (GC
  /// pause, app switch), simulating the entire backlog would make the next
  /// frame even longer. Excess backlog beyond this many ticks is dropped —
  /// the game slows momentarily instead of locking up. 5 ticks ≈ 83 ms of
  /// catch-up per frame.
  final int maxTicksPerAdvance;

  double _accumulator = 0;
  int _totalTicks = 0;

  /// Total ticks issued since construction (the simulation frame number).
  int get totalTicks => _totalTicks;

  /// Fraction of the next tick already elapsed, in `[0, 1)`.
  ///
  /// Renderers interpolate between the previous and current simulation
  /// states by this amount for smooth motion when the refresh rate exceeds
  /// the tick rate.
  double get alpha => _accumulator / kTickDuration;

  /// Feeds [elapsedSeconds] of wall-clock time into the accumulator and
  /// runs as many fixed ticks as it covers. Returns the number of ticks
  /// issued.
  int advance(double elapsedSeconds) {
    assert(elapsedSeconds >= 0, 'elapsed time must not be negative');
    _accumulator += elapsedSeconds;

    var ticksIssued = 0;
    while (_accumulator >= kTickDuration && ticksIssued < maxTicksPerAdvance) {
      _accumulator -= kTickDuration;
      ticksIssued++;
      _totalTicks++;
      onTick();
    }

    // Hitch recovery: drop backlog we refused to simulate so it cannot
    // snowball into the next frame.
    if (_accumulator >= kTickDuration) {
      _accumulator = _accumulator.remainder(kTickDuration);
    }
    return ticksIssued;
  }

  /// Discards any banked partial-tick time.
  ///
  /// Call when the game un-pauses, so time spent paused is not simulated.
  void reset() {
    _accumulator = 0;
  }
}
