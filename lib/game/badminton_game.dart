import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
// `Simulation` in flutter/widgets.dart (physics) conflicts with our engine's
// Simulation; hide the Flutter one to resolve the ambiguity.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Simulation;
import 'package:smash_bros/engine/ai/ai_controller.dart';
import 'package:smash_bros/engine/ai/basic_ai.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/render/render_state.dart';
import 'package:smash_bros/engine/sim/fixed_timestep_driver.dart';
import 'package:smash_bros/engine/sim/simulation.dart';
import 'package:smash_bros/game/components/components.dart';
import 'package:smash_bros/game/input/local_control_state.dart';

/// The Flame game host for Arcade Badminton (M1-020, extended in M1-025/029).
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
/// **never** touch the simulation or its `GameState` directly.
///
/// ## Event contract
///
/// Events (sound, VFX, animation triggers) are delivered via two surfaces:
///
/// * [frameEvents] — the stable per-frame event list. It is rebuilt once per
///   [update] call: all events produced by ticks that fired this render frame
///   are moved into `_frameEvents`, replacing the previous frame's contents.
///   Components read [frameEvents] during their own `update()` calls (which
///   run after [BadmintonGame.update]); the list is stable for the entire
///   render frame and never double-delivers across frames.
///
/// * [takeEvents] — retained for compatibility with M2 audio consumers.
///   Returns the same list as [frameEvents]; audio consumers in M2 will call
///   [frameEvents] directly. Either accessor delivers events exactly once per
///   simulation tick regardless of the display rate — reading `view.events`
///   instead would replay them each render frame.
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
///   T              → tossHeld hold (hold to charge, release to serve)
///   Space          → jump
///   J              → smash
///   K              → drop shot
///   L              → normal shot
class BadmintonGame extends FlameGame with KeyboardEvents {
  /// Creates a game with a deterministic [seed], the given [firstServer], and
  /// a match played to [targetScore].
  ///
  /// Pass [rightAi] to wire an [AIController] as the right player's input
  /// source. If omitted, the right player receives no input (useful for
  /// two-human or testing scenarios).
  BadmintonGame({
    required int seed,
    CourtSide firstServer = CourtSide.left,
    int targetScore = kDefaultTargetScore,
    AIController? rightAi,
  }) : _simulation = Simulation(
         seed: seed,
         firstServer: firstServer,
         targetScore: targetScore,
       ),
       _firstServer = firstServer,
       _targetScore = targetScore,
       _rightAi = rightAi,
       super(
         camera: CameraComponent.withFixedResolution(
           width: kCourtWidth,
           height: kCourtHeight,
         ),
       ) {
    _initDriver();
  }

  Simulation _simulation;
  AIController? _rightAi;

  // Stored so restartMatch can recreate the simulation with the same settings.
  final CourtSide _firstServer;
  final int _targetScore;

  late FixedTimestepDriver _driver;

  void _initDriver() {
    _driver = FixedTimestepDriver(
      onTick: () {
        final frame = _simulation.state.frame;
        // Write the local (left) player's input BEFORE ticking.
        _simulation.state.leftInputs.set(frame, controls.drainTick());
        // Write the AI's input BEFORE ticking (M1-029).
        final ai = _rightAi;
        if (ai != null) {
          _simulation.state.rightInputs.set(
            frame,
            ai.decide(_simulation.state),
          );
        }
        _simulation.tick();
        _previous = _current;
        _current = RenderState.capture(_simulation);
        _pendingEvents.addAll(_current.events);
      },
    );
  }

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

  // Events accumulated from ticks fired this render frame.
  // Populated once per update() and stable until the next update().
  final List<RenderEvent> _pendingEvents = [];
  List<RenderEvent> _frameEvents = const [];

  // Current safe-area insets in game units (updated by GameScreen each frame).
  EdgeInsets _safeArea = EdgeInsets.zero;

  // Touch control components — kept so safeArea can be forwarded on set.
  late MovePadComponent _movePad;
  late ActionButtonsComponent _actionButtons;

  // -- HUD components (M1-026) — kept so safeArea can be forwarded on set. --
  late ScoreHudComponent _scoreHud;
  late StaminaBarComponent _staminaLeft;
  late StaminaBarComponent _staminaRight;
  late PhaseBannerComponent _phaseBanner;

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

    // -- Debug-only fps counter -----------------------------------------------
    // Kept for the macOS feel-tuning loop; stripped from release builds.
    if (kDebugMode) {
      camera.viewport.add(FpsTextComponent(position: Vector2(8, 8)));
    }
    // -------------------------------------------------------------------------

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

    // -- HUD components (M1-026) added to viewport (HUD space) ---------------
    // All three read game.view each frame and never touch the simulation.
    _scoreHud = ScoreHudComponent(safeArea: _safeArea);
    _staminaLeft = StaminaBarComponent(
      side: CourtSide.left,
      safeArea: _safeArea,
    );
    _staminaRight = StaminaBarComponent(
      side: CourtSide.right,
      safeArea: _safeArea,
    );
    _phaseBanner = PhaseBannerComponent();
    await camera.viewport.add(_scoreHud);
    await camera.viewport.add(_staminaLeft);
    await camera.viewport.add(_staminaRight);
    await camera.viewport.add(_phaseBanner);

    // -- Tap-to-restart overlay (M1-029) — added last so it has the highest
    // priority and does not block normal HUD components while in play. During
    // active play containsLocalPoint returns false, so it is tap-transparent.
    await camera.viewport.add(RestartOverlayComponent());
  }

  @override
  void update(double dt) {
    super.update(dt);
    _driver.advance(dt);
    // Move all events produced by ticks that fired this render frame into the
    // stable _frameEvents list (replacing last frame's contents). Components
    // read frameEvents in their own update() calls; the list is stable for the
    // full render frame and never double-delivers across frames.
    _frameEvents = _pendingEvents.isEmpty
        ? const []
        : List<RenderEvent>.unmodifiable(_pendingEvents.toList());
    _pendingEvents.clear();
    // Recompute the cached view once per render frame (after advancing the
    // driver so alpha is current for this frame's interpolation point).
    _view = RenderState.lerp(_previous, _current, _driver.alpha);
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
      _scoreHud.safeArea = value;
      _staminaLeft.safeArea = value;
      _staminaRight.safeArea = value;
    }
  }

  /// All [RenderEvent]s produced by simulation ticks that fired this render
  /// frame.
  ///
  /// Populated once per [update] call and stable for the entire render frame:
  /// components that read [frameEvents] in their own `update()` receive
  /// exactly one delivery per tick regardless of the display rate. The list
  /// is replaced (not mutated) on each [update]; holding a reference across
  /// frames is safe but will observe stale events.
  ///
  /// Audio consumers in M2 will read [frameEvents] directly. [takeEvents] is
  /// retained for compatibility and returns the same list.
  List<RenderEvent> get frameEvents => _frameEvents;

  /// Returns all [RenderEvent]s for this render frame.
  ///
  /// Retained for compatibility. Returns [frameEvents] — the same stable list
  /// built once per [update]. Audio consumers in M2 should prefer [frameEvents]
  /// directly (same data, no aliasing concern). Events are guaranteed to arrive
  /// once per simulation tick regardless of the display rate — reading
  /// `view.events` instead would replay them each render frame.
  List<RenderEvent> takeEvents() => _frameEvents;

  /// Restarts the match with fresh seeds, resetting the simulation and AI.
  ///
  /// Replaces [_simulation] with a new one using [seed], recreates the AI
  /// with [aiSeed], resets the driver accumulator (so no burst of catch-up
  /// ticks on the first frame), and recaptures both render snapshots from
  /// the new initial state.
  ///
  /// Seeds are derived in the game layer from wall-clock time, which is
  /// explicitly allowed outside `lib/engine/` (see CLAUDE.md). The engine
  /// itself never sees wall-clock time — it only receives the seeded ints.
  void restartMatch({required int seed, required int aiSeed}) {
    _simulation = Simulation(
      seed: seed,
      firstServer: _firstServer,
      targetScore: _targetScore,
    );
    _simulation.start();
    _rightAi = BasicAI(side: CourtSide.right, seed: aiSeed);
    _driver.reset();
    _current = RenderState.capture(_simulation);
    _previous = _current;
    _view = RenderState.lerp(_previous, _current, _driver.alpha);
    _pendingEvents.clear();
    _frameEvents = const [];
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
    // OS key-repeat must not re-fire edge-triggered one-shots (holding J
    // would spam pressSmash ~30×/s). Hold keys are level-tracked from the
    // original down event, so repeats carry no information for us either way.
    if (event is KeyRepeatEvent) return KeyEventResult.ignored;
    final isDown = event is KeyDownEvent;
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
    // -- Level-triggered holds (set on down, clear on up) --------------------
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      controls.moveLeft = isDown;
      return true;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyD) {
      controls.moveRight = isDown;
      return true;
    }
    // T is now level-triggered (hold to charge, release to serve — M1-034).
    if (key == LogicalKeyboardKey.keyT) {
      controls.tossHeld = isDown;
      return true;
    }

    // -- Edge-triggered one-shots (only fire on key-down) --------------------
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
}
