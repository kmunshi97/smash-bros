import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/render/render_state.dart';
import 'package:smash_bros/engine/systems/shot_type.dart';
import 'package:smash_bros/game/badminton_game.dart';
import 'package:smash_bros/ui/theme/app_colors.dart';

/// Spawns particle bursts on impact events (M2-004).
///
/// Pure presentation: reads only [BadmintonGame.frameEvents] (delivered once
/// per simulation tick) and the interpolated [BadmintonGame.view] for hit
/// positions; it never touches the simulation. Spawned [ParticleSystemComponent]s
/// are added to the world and remove themselves when their particles expire.
///
/// Coordinates are cosmetic, so the spread directions use `dart:math`'s
/// `Random` — never the engine PRNG.
///
/// Event → effect mapping:
///   * smash [SwingEvent]      → a sharp white spark burst at the shuttle.
///   * perfect [BlockEvent]    → a bright accent burst at the shuttle (the
///                               "clean counter" pop).
///   * [ShuttleLandedEvent]    → a low dust puff along the ground.
///   * [NetCordEvent] /
///     [NetBodyEvent]          → a small puff at the net crossing.
class ImpactEffectsComponent extends Component
    with HasGameReference<BadmintonGame> {
  /// Creates the effects component; [seed] makes the cosmetic spread
  /// reproducible for tests. [emitOverride] / [shuttlePositionOverride] are
  /// test seams — in production both read the live game.
  ImpactEffectsComponent({
    int seed = 0,
    void Function(ParticleSystemComponent system)? emitOverride,
    Vector2 Function()? shuttlePositionOverride,
  }) : _random = math.Random(seed),
       _emitOverride = emitOverride,
       _shuttlePositionOverride = shuttlePositionOverride;

  final math.Random _random;
  final void Function(ParticleSystemComponent system)? _emitOverride;
  final Vector2 Function()? _shuttlePositionOverride;

  @override
  void update(double dt) => reactTo(game.frameEvents);

  /// Spawns the burst for each event in [events].
  ///
  /// Extracted from [update] (which calls it with [BadmintonGame.frameEvents])
  /// so it is unit-testable with crafted events plus the constructor's emit /
  /// position seams, without a mounted game.
  void reactTo(Iterable<RenderEvent> events) {
    for (final event in events) {
      switch (event) {
        case SwingEvent(shotType: ShotType.smash):
          _spark(_shuttlePosition(), count: 14, speed: 220, color: _spark1);
        case BlockEvent(isPerfect: true):
          _spark(_shuttlePosition(), count: 18, speed: 260, color: _accent);
        case ShuttleLandedEvent(:final x):
          _dust(Vector2(x, kGroundY));
        case NetCordEvent(:final x, :final y):
        case NetBodyEvent(:final x, :final y):
          _spark(Vector2(x, y), count: 8, speed: 120, color: _net);
        case _:
          break;
      }
    }
  }

  // -- Effect builders --------------------------------------------------------

  /// A radial spark burst that accelerates outward then falls under gravity.
  void _spark(
    Vector2 origin, {
    required int count,
    required double speed,
    required Color color,
  }) {
    _emit(
      ParticleSystemComponent(
        position: origin,
        particle: Particle.generate(
          count: count,
          generator: (_) {
            final angle = _random.nextDouble() * 2 * math.pi;
            final mag = speed * (0.4 + _random.nextDouble() * 0.6);
            return AcceleratedParticle(
              speed: Vector2(math.cos(angle), math.sin(angle)) * mag,
              acceleration: Vector2(0, 600), // gravity pull (screen-down +y)
              lifespan: 0.35 + _random.nextDouble() * 0.25,
              child: CircleParticle(
                radius: 2 + _random.nextDouble() * 2,
                paint: Paint()..color = color,
              ),
            );
          },
        ),
      ),
    );
  }

  /// A low, sideways dust puff hugging the ground for a shuttle landing.
  void _dust(Vector2 origin) {
    _emit(
      ParticleSystemComponent(
        position: origin,
        particle: Particle.generate(
          count: 12,
          generator: (_) {
            // Mostly horizontal spread, slight upward lift.
            final dir =
                (_random.nextBool() ? 1 : -1) * (0.3 + _random.nextDouble());
            return AcceleratedParticle(
              speed: Vector2(dir * 90, -20 - _random.nextDouble() * 30),
              acceleration: Vector2(0, 200),
              lifespan: 0.4 + _random.nextDouble() * 0.2,
              child: CircleParticle(
                radius: 2 + _random.nextDouble() * 2.5,
                paint: Paint()..color = _dustColor,
              ),
            );
          },
        ),
      ),
    );
  }

  void _emit(ParticleSystemComponent system) {
    final override = _emitOverride;
    if (override != null) {
      override(system);
    } else {
      // Project the spawn origin onto the visual court (M2 POC) so bursts line
      // up with the projected players/shuttle. Particle spread velocities stay
      // in screen units, so only the origin needs projecting.
      system.position = game.courtProjection.apply(
        system.position.x,
        system.position.y,
      );
      game.world.add(system);
    }
  }

  /// The current (interpolated) shuttle position in world space — where a
  /// connecting swing made contact.
  Vector2 _shuttlePosition() {
    final override = _shuttlePositionOverride;
    if (override != null) return override();
    final s = game.view.shuttle;
    return Vector2(s.x, s.y);
  }

  // -- Palette (cosmetic) -----------------------------------------------------

  static const Color _spark1 = AppColors.shuttle; // white
  static const Color _accent = AppColors.accent;
  static const Color _net = AppColors.grey;
  static const Color _dustColor = Color(0xFFBFA98A);
}
