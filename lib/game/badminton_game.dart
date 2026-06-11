import 'package:flame/components.dart';
import 'package:flame/game.dart';
// `Simulation` in flutter/widgets.dart (physics) conflicts with our engine's
// Simulation; hide the Flutter one to resolve the ambiguity.
import 'package:flutter/widgets.dart' hide Simulation;
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/render/render_state.dart';
import 'package:smash_bros/engine/sim/fixed_timestep_driver.dart';
import 'package:smash_bros/engine/sim/simulation.dart';
import 'package:smash_bros/game/components/components.dart';

/// The Flame game host for Arcade Badminton (M1-020).
///
/// ## ADR-7 — Fixed-timestep render loop
///
/// [BadmintonGame] owns the fixed-timestep loop. A [FixedTimestepDriver]
/// drives the [Simulation] at exactly 60 ticks/sec regardless of the display
/// refresh rate. Each tick, the previous `RenderState` snapshot is stored in
/// `_previous` and a fresh one is captured into `_current`.
///
/// Callers read [view] — a linearly-interpolated `RenderState` between the
/// previous and current snapshots at `FixedTimestepDriver.alpha`. At 120 Hz
/// the alpha oscillates between 0 and 1, giving smooth sub-tick motion without
/// running the simulation faster.
///
/// ## Component contract
///
/// All Flame components must read [view] for positional data. They must
/// **never** touch the simulation or its `GameState` directly. One-off events
/// (sound, VFX) must be consumed via [takeEvents]; events are guaranteed to
/// arrive exactly once per tick regardless of the display rate.
class BadmintonGame extends FlameGame {
  /// Creates a game with a deterministic [seed], the given [firstServer], and
  /// a match played to [targetScore].
  BadmintonGame({
    required int seed,
    CourtSide firstServer = CourtSide.left,
    int targetScore = kDefaultTargetScore,
  }) : _simulation = Simulation(
         seed: seed,
         firstServer: firstServer,
         targetScore: targetScore,
       ),
       super(
         camera: CameraComponent.withFixedResolution(
           width: kCourtWidth,
           height: kCourtHeight,
         ),
       ) {
    _driver = FixedTimestepDriver(
      onTick: () {
        _simulation.tick();
        _previous = _current;
        _current = RenderState.capture(_simulation);
        _pendingEvents.addAll(_current.events);
      },
    );
  }

  final Simulation _simulation;
  late final FixedTimestepDriver _driver;

  // Snapshot pair for interpolation.
  late RenderState _previous;
  late RenderState _current;

  // Cached interpolated view, recomputed once per render frame in [update].
  late RenderState _view;

  // Events accumulated from captured snapshots since the last [takeEvents].
  final List<RenderEvent> _pendingEvents = [];

  // -- Debug HUD (replaced by the real HUD in M1-026) -----------------------

  /// Debug text overlay showing frame / phase / score. Marked for removal when
  /// the proper HUD lands in M1-026.
  late TextComponent _debugText;

  // -- FlameGame overrides ---------------------------------------------------

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Boot the engine and capture the initial state into both slots so the
    // first [view] call never reads uninitialised memory.
    _simulation.start();
    _current = RenderState.capture(_simulation);
    _previous = _current;
    // Cache the initial view so [view] is ready before the first update().
    _view = RenderState.lerp(_previous, _current, _driver.alpha);

    // -- Debug scaffolding (remove in M1-026) ----------------------------------
    // FpsTextComponent shows the current frame rate in the top-left corner.
    camera.viewport.add(FpsTextComponent(position: Vector2(8, 8)));

    // A small one-line status shows frame / phase / score. Updated each tick
    // in [update]; the component is added to the viewport so it renders in
    // screen space (HUD overlay), not world space.
    _debugText = TextComponent(
      text: _debugString(),
      position: Vector2(8, 32),
    );
    camera.viewport.add(_debugText);
    // -- End debug scaffolding ------------------------------------------------

    // -- World components (M1-022..024) ---------------------------------------
    // Order matters: court is drawn first (background), then players, then the
    // shuttle on top. All three are added to the world (not the viewport) so
    // they live in game-unit world space where world coords == screen coords
    // for our fixed-resolution 1280×720 camera.
    await world.add(CourtComponent());
    await world.add(PlayerComponent(CourtSide.left));
    await world.add(PlayerComponent(CourtSide.right));
    await world.add(ShuttleComponent());
  }

  @override
  void update(double dt) {
    super.update(dt);
    _driver.advance(dt);
    // Recompute the cached view once per render frame (after advancing the
    // driver so alpha is current for this frame's interpolation point).
    _view = RenderState.lerp(_previous, _current, _driver.alpha);
    // Refresh the debug overlay every render frame (cheap string update).
    _debugText.text = _debugString();
  }

  /// The interpolated render state between the previous and current ticks,
  /// cached once per render frame in [update].
  ///
  /// Components must read this for all positional data and must never reach
  /// into the simulation directly. The value is recomputed once per [update]
  /// call (once per render frame) so repeated reads within a frame return the
  /// identical object without re-lerping.
  RenderState get view => _view;

  /// Returns all [RenderEvent]s accumulated since the last call and clears the
  /// pending queue.
  ///
  /// Audio and VFX consumers must call this exactly once per render frame.
  /// Events are guaranteed to arrive once per simulation tick regardless of the
  /// display rate — using `view.events` would replay them each render frame.
  List<RenderEvent> takeEvents() {
    if (_pendingEvents.isEmpty) return const [];
    final copy = List<RenderEvent>.unmodifiable(_pendingEvents);
    _pendingEvents.clear();
    return copy;
  }

  // -- Lifecycle -------------------------------------------------------------

  @override
  void lifecycleStateChange(AppLifecycleState state) {
    // Let FlameGame handle its internal pauseWhenBackgrounded logic first.
    super.lifecycleStateChange(state);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        pauseEngine();
      case AppLifecycleState.resumed:
        // Discard banked time so the pause duration is not simulated as a
        // spike of catch-up ticks (see FixedTimestepDriver.reset).
        _driver.reset();
        resumeEngine();
      case AppLifecycleState.detached:
        // No-op: the OS is tearing down the isolate; nothing to restore.
        break;
    }
  }

  // -- Helpers ---------------------------------------------------------------

  String _debugString() {
    final v = _current;
    return 'frame=${v.frame} phase=${v.phase.name} '
        'score=${v.leftScore}-${v.rightScore}';
  }
}
