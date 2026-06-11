import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/sim/fixed_timestep_driver.dart';

void main() {
  group('FixedTimestepDriver (ADR-7)', () {
    test('one 60Hz frame yields exactly one tick', () {
      var ticks = 0;
      FixedTimestepDriver(onTick: () => ticks++).advance(kTickDuration);
      expect(ticks, 1);
    });

    test('120Hz frames yield one tick every two frames, not two per frame', () {
      var ticks = 0;
      final driver = FixedTimestepDriver(onTick: () => ticks++);
      const frame120 = 1.0 / 120.0;
      for (var i = 0; i < 120; i++) {
        driver.advance(frame120);
      }
      // One second of 120Hz frames must produce ~60 simulation ticks.
      expect(ticks, inInclusiveRange(59, 60));
    });

    test('a slow 30Hz frame yields two catch-up ticks', () {
      var ticks = 0;
      final driver = FixedTimestepDriver(onTick: () => ticks++);
      final issued = driver.advance(2 * kTickDuration);
      expect(issued, 2);
      expect(ticks, 2);
    });

    test('remainder is banked across calls', () {
      var ticks = 0;
      final driver = FixedTimestepDriver(onTick: () => ticks++)
        ..advance(kTickDuration * 0.6);
      expect(ticks, 0);
      driver.advance(kTickDuration * 0.6);
      expect(ticks, 1, reason: '0.6 + 0.6 tick-lengths covers one tick');
    });

    test('hitch is capped at maxTicksPerAdvance and backlog is dropped', () {
      var ticks = 0;
      final driver = FixedTimestepDriver(onTick: () => ticks++);
      // A 1-second hitch is 60 ticks of backlog.
      final issued = driver.advance(1);
      expect(issued, driver.maxTicksPerAdvance);
      expect(ticks, driver.maxTicksPerAdvance);

      // The dropped backlog must not leak into the next ordinary frame.
      final nextIssued = driver.advance(kTickDuration);
      expect(nextIssued, 1);
    });

    test('alpha reports the banked fraction of the next tick', () {
      final driver = FixedTimestepDriver(onTick: () {});
      expect(driver.alpha, 0);
      driver.advance(kTickDuration * 0.25);
      expect(driver.alpha, closeTo(0.25, 1e-9));
      driver.advance(kTickDuration * 0.75);
      expect(driver.alpha, closeTo(0, 1e-9));
    });

    test('totalTicks counts across advances', () {
      final driver = FixedTimestepDriver(onTick: () {})
        ..advance(kTickDuration * 3)
        ..advance(kTickDuration * 2);
      expect(driver.totalTicks, 5);
    });

    test('reset discards banked time', () {
      var ticks = 0;
      FixedTimestepDriver(onTick: () => ticks++)
        ..advance(kTickDuration * 0.9)
        ..reset()
        ..advance(kTickDuration * 0.9);
      expect(ticks, 0, reason: 'banked time before reset must not count');
    });
  });
}
