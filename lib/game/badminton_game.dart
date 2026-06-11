import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
// `Simulation` in flutter/widgets.dart (physics) conflicts with our engine's
// Simulation; hide the Flutter one to resolve the ambiguity.
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Simulation;
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/render/render_state.dart';
import 'package:smash_bros/engine/sim/fixed_timestep_driver.dart';
import 'package:smash_bros/engine/sim/simulation.dart';
import 'package:smash_bros/game/components/components.dart';
import 'package:smash_bros/game/input/local_control_state.dart';

/// The Flame game host for Arcade Badminton (M1-020, extended in M1-025).
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
///
/// ## Keyboard (desktop dev target)
///
/// Keyboard input exists purely for the macOS desktop feel-tuning loop
/// (CLAUDE.md dev target). The shipping input path for Android/iOS is touch
/// (see [MovePadComponent] and [ActionButtonsComponent]).
///
/// Key mapping:
///   ←/A            → moveLeft hold
///   →/D            → moveRight hold
///   Space          → jump
///   J              → smash
///   K              → drop shot
///   L              → normal shot
///   T              → serve toss
class BadmintonGame extends FlameGame with KeyboardEvents {
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
        // Write the local player's input for the current frame BEFORE ticking.
        // Drain exactly once per simulation tick (not per render frame).
        _simulation.state.leftInputs.set(
          _simulation.state.frame,
          controls.drainTick(),
        );
        _simulation.tick();
        _previous = _current;
        _current = RenderState.capture(_simulation);
        _pendingEvents.addAll(_current.events);
      },
    );
  }

  final Simulation _simulation;
  late final FixedTimestepDriver _driver;

  /// The mutable input accumulator for the local (left) player.
  ///
  /// Touch components and the keyboard handler write into this; the driver's
  /// onTick drains it once per simulation tick.
  final LocalControlState controls = LocalControlState();

  // Snapshot pair for interpolation.
  late RenderState _previous;
  late RenderState _current;

  // Cached interpolated view, recomputed once per render frame in [update].
  late RenderState _view;

  // Events accumulated from captured snapshots since the last [takeEvents].
  final List<RenderEvent> _pendingEvents = [];

  // Current safe-area insets in game units (updated by GameScreen each frame).
  EdgeInsets _safeArea = EdgeInsets.zero;

  // Touch control components — kept so safeArea can be forwarded on set.
  late MovePadComponent _movePad;
  late ActionButtonsComponent _actionButtons;

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

    // The fixed-resolution viewfinder looks at world (0,0) anchored centre by
    // default, which would put the court's top-left corner in the middle of
    // the screen. Aim it at the court centre so world coords map 1:1 onto the
    // 1280×720 letterboxed screen.
    camera.viewfinder.position = Vector2(kCourtWidth / 2, kCourtHeight / 2);

    // -- World components (M1-022..024) ---------------------------------------
    // Order matters: court is drawn first (background), then players, then the
    // shuttle on top. All three are added to the world (not the viewport) so
    // they live in game-unit world space where world coords == screen coords
    // for our fixed-resolution 1280×720 camera.
    await world.add(CourtComponent());
    await world.add(PlayerComponent(CourtSide.left));
    await world.add(PlayerComponent(CourtSide.right));
    await world.add(ShuttleComponent());

    // -- Touch controls (M1-025) added to viewport (HUD space) ---------------
    // Each component handles its own safe-area insets; updates its anchor
    // position in update() each frame as safeArea changes.
    _movePad = MovePadComponent(safeArea: _safeArea);
    _actionButtons = ActionButtonsComponent(safeArea: _safeArea);
    await camera.viewport.add(_movePad);
    await camera.viewport.add(_actionButtons);
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

  /// The current safe-area insets in game units.
  EdgeInsets get safeArea => _safeArea;

  /// Updates the safe-area insets (in game units) used to offset touch controls.
  ///
  /// Called by the game screen each build with the current device padding
  /// converted to game units. The two control components pick this up on their
  /// next `update` call.
  set safeArea(EdgeInsets value) {
    _safeArea = value;
    // Forward to the components only after onLoad (they may not exist yet on
    // first set during the widget build before onLoad completes).
    if (isLoaded) {
      _movePad.safeArea = value;
      _actionButtons.safeArea = value;
    }
  }

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

  // -- Keyboard input (macOS desktop feel-tuning target) ---------------------
  //
  // Keyboard exists for the desktop feel-tuning loop (CLAUDE.md dev target);
  // touch is the shipping input path (Android/iOS). The key→action mapping
  // lives in [handleKeyChange] so tests can exercise the pure mapping logic
  // without synthesising raw [KeyEvent] instances.

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    final isDown = event is KeyDownEvent || event is KeyRepeatEvent;
    final isUp = event is KeyUpEvent;
    if (!isDown && !isUp) return KeyEventResult.ignored;

    final consumed = handleKeyChange(event.logicalKey, isDown: isDown);
    return consumed ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  /// Maps a keyboard key to a [controls] action and applies it.
  ///
  /// Returns `true` if the key is one this game consumes; `false` otherwise.
  /// Extracted as a named method so unit tests can call it directly without
  /// constructing raw [KeyEvent] objects.
  bool handleKeyChange(LogicalKeyboardKey key, {required bool isDown}) {
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      controls.moveLeft = isDown;
      return true;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyD) {
      controls.moveRight = isDown;
      return true;
    }
    if (isDown) {
      if (key == LogicalKeyboardKey.space) {
        controls.pressJump();
        return true;
      }
      if (key == LogicalKeyboardKey.keyJ) {
        controls.pressSmash();
        return true;
      }
      if (key == LogicalKeyboardKey.keyK) {
        controls.pressDrop();
        return true;
      }
      if (key == LogicalKeyboardKey.keyL) {
        controls.pressNormal();
        return true;
      }
      if (key == LogicalKeyboardKey.keyT) {
        controls.pressToss();
        return true;
      }
    }
    return false;
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
