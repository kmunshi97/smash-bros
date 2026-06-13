// Tests ImpactEffectsComponent.reactTo (M2-004) via the emit/position seams —
// asserts which events spawn a particle burst, without a Flame harness.
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/render/render_state.dart';
import 'package:smash_bros/engine/systems/shot_type.dart';
import 'package:smash_bros/game/components/effects/impact_effects_component.dart';

void main() {
  late List<ParticleSystemComponent> emitted;
  late ImpactEffectsComponent effects;

  setUp(() {
    emitted = [];
    effects = ImpactEffectsComponent(
      seed: 1,
      emitOverride: emitted.add,
      shuttlePositionOverride: () => Vector2(500, 300),
    );
  });

  SwingEvent swing(ShotType type, {bool airborne = false}) =>
      SwingEvent(side: CourtSide.left, shotType: type, wasAirborne: airborne);

  test('a smash swing spawns one burst at the shuttle position', () {
    effects.reactTo([swing(ShotType.smash, airborne: true)]);
    expect(emitted, hasLength(1));
    expect(emitted.single.position, Vector2(500, 300));
  });

  test('a perfect block spawns one burst', () {
    effects.reactTo([
      const BlockEvent(side: CourtSide.right, isPerfect: true),
    ]);
    expect(emitted, hasLength(1));
  });

  test('a shuttle landing spawns a ground dust puff at the landing x', () {
    effects.reactTo([
      const ShuttleLandedEvent(x: 420, side: CourtSide.right, isInBounds: true),
    ]);
    expect(emitted, hasLength(1));
    expect(emitted.single.position.x, 420);
  });

  test('net-cord and net-body hits each spawn a burst at the crossing', () {
    effects.reactTo([
      const NetCordEvent(x: 640, y: 455),
      const NetBodyEvent(x: 640, y: 500),
    ]);
    expect(emitted, hasLength(2));
    expect(emitted[0].position, Vector2(640, 455));
    expect(emitted[1].position, Vector2(640, 500));
  });

  test('non-impact events (normal swing, imperfect block) spawn nothing', () {
    effects.reactTo([
      swing(ShotType.normal),
      swing(ShotType.toss),
      const BlockEvent(side: CourtSide.left, isPerfect: false),
    ]);
    expect(emitted, isEmpty);
  });
}
