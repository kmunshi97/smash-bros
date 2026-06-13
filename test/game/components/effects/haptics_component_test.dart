// Tests HapticsComponent.reactTo (M2-030) with recorder impulses — no Flame
// harness needed, since reactTo never touches the game reference.
import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/render/render_state.dart';
import 'package:smash_bros/engine/systems/shot_type.dart';
import 'package:smash_bros/game/components/effects/haptics_component.dart';

void main() {
  late int smashCount;
  late int perfectBlockCount;
  late HapticsComponent haptics;

  setUp(() {
    smashCount = 0;
    perfectBlockCount = 0;
    haptics = HapticsComponent(
      smashImpulse: () => smashCount++,
      perfectBlockImpulse: () => perfectBlockCount++,
    );
  });

  SwingEvent swing(ShotType type, {bool airborne = false}) =>
      SwingEvent(side: CourtSide.left, shotType: type, wasAirborne: airborne);

  test('a smash swing fires the smash impulse once', () {
    haptics.reactTo([swing(ShotType.smash, airborne: true)]);
    expect(smashCount, 1);
    expect(perfectBlockCount, 0);
  });

  test('a perfect block fires the perfect-block impulse once', () {
    haptics.reactTo([
      const BlockEvent(side: CourtSide.right, isPerfect: true),
    ]);
    expect(perfectBlockCount, 1);
    expect(smashCount, 0);
  });

  test('normal/drop/toss swings and imperfect blocks fire nothing', () {
    haptics.reactTo([
      swing(ShotType.normal),
      swing(ShotType.drop),
      swing(ShotType.toss),
      const BlockEvent(side: CourtSide.left, isPerfect: false),
      const ShuttleLandedEvent(x: 300, side: CourtSide.left, isInBounds: true),
      const NetCordEvent(x: 640, y: 460),
    ]);
    expect(smashCount, 0);
    expect(perfectBlockCount, 0);
  });

  test('multiple events in one tick each fire', () {
    haptics.reactTo([
      swing(ShotType.smash),
      const BlockEvent(side: CourtSide.right, isPerfect: true),
      swing(ShotType.smash),
    ]);
    expect(smashCount, 2);
    expect(perfectBlockCount, 1);
  });
}
