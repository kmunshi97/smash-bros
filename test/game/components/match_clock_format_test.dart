// Unit tests for the Point Rush clock label formatting (M2-021).
import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/game/components/hud/match_clock_component.dart';

void main() {
  String fmt(int seconds) => MatchClockComponent.format(seconds * kTickRate);

  group('MatchClockComponent.format', () {
    test('formats whole seconds as m:ss', () {
      expect(fmt(90), '1:30');
      expect(fmt(60), '1:00');
      expect(fmt(9), '0:09');
      expect(fmt(0), '0:00');
    });

    test('rounds up partial seconds so it never shows 0:00 early', () {
      // Half a second left still reads 0:01.
      expect(MatchClockComponent.format(kTickRate ~/ 2), '0:01');
      // One tick left rounds up to a second.
      expect(MatchClockComponent.format(1), '0:01');
    });

    test('pads the seconds field to two digits', () {
      expect(fmt(125), '2:05');
    });
  });
}
