import 'package:meta/meta.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/entities/player.dart';
import 'package:smash_bros/engine/entities/shuttle.dart';
import 'package:smash_bros/engine/entities/tunables.dart';
import 'package:smash_bros/engine/input/input_action.dart';
import 'package:smash_bros/engine/input/input_validator.dart';
import 'package:smash_bros/engine/math/fix.dart';
import 'package:smash_bros/engine/math/fix_vec2.dart';
import 'package:smash_bros/engine/rules/match_fsm.dart';
import 'package:smash_bros/engine/rules/match_phase.dart';
import 'package:smash_bros/engine/sim/game_state.dart';
import 'package:smash_bros/engine/systems/collision_system.dart';
import 'package:smash_bros/engine/systems/shot_system.dart';
import 'package:smash_bros/engine/systems/stamina_system.dart';
import 'package:smash_bros/engine/systems/stun_system.dart';

/// Advances a [GameState] by exactly one tick per [tick] call (M1-017).
///
/// ## The system order is the contract
///
/// A single tick runs these steps **in this exact order**, each a private
/// method. The order is load-bearing: replays and Milestone-3 rollback
/// re-execute `tick()` from a snapshot to reproduce a frame bit-for-bit, so
/// **any reorder is a desync**. The order mirrors causality — read intent,
/// resolve the match phase, move bodies, swing, fly the shuttle, detect
/// collisions, age timers, apply rules:
///
/// 1. **Read + sanitise inputs** — both players' raw bitmasks for [GameState.frame]
///    are run through [InputValidator.sanitize] with the per-player context
///    (serving for the server during `servePending`, otherwise rally).
/// 2. **Phase pump** — non-play phases advance their timers here: the serve
///    timer and toss in `servePending`, the point pause in `pointScored`;
///    `preMatch`/`matchOver` do nothing. Serve placement happens on every entry
///    into `servePending`.
/// 3. **Movement + jump** (`servePending`/`inPlay`) — horizontal movement
///    (stamina-scaled, stun-gated) and jump start/advance. During
///    `servePending` the parked shuttle is then re-pinned to the server's
///    hand so it tracks the server's walk (M1-014b).
/// 4. **Swing resolution** (`inPlay`) — decode each player's shot, resolve a
///    simultaneous swing by shuttle side (M1-015), evaluate block timing
///    (M1-035), launch via [ShotSystem.trySwing], charge stamina, stun on an
///    imperfect block, and signal `onServeReturned` when the receiver returns a
///    serve.
/// 5. **Shuttle physics** (`inPlay`) — one [Shuttle.integrate] with the rally's
///    active drag.
/// 6. **Collision** (`inPlay`) — [CollisionSystem.resolve] then
///    `RallyState.observe` to lift a stale lockout.
/// 7. **Stamina + stun ticks** (`servePending`/`inPlay`) — per-player
///    [StaminaSystem.tick] and [StunSystem.tick].
/// 8. **Rules** (`inPlay`) — [MatchFsm.onCollisionEvents] turns this tick's
///    collision facts into scoring / phase changes (and serve LETs).
/// 9. **`frame++`** — always, in every phase, so the input buffers stay aligned
///    with wall-clock frames even while `preMatch`/`matchOver`/`pointScored`.
///
/// ## Outputs for the presentation layer
///
/// [lastTickCollisions] and [lastTickSwings] expose the collision events and
/// connected swings produced *this* tick. They are cleared at the top of every
/// [tick] and filled as the relevant steps run, so the renderer/audio layer
/// (the RenderState PR) can react to "what just happened" without re-deriving
/// it.
final class Simulation {
  /// Creates a simulation owning a fresh [GameState] for [seed].
  Simulation({
    required int seed,
    CourtSide firstServer = CourtSide.left,
    int targetScore = kDefaultTargetScore,
  }) : _state = GameState(
         seed: seed,
         firstServer: firstServer,
         targetScore: targetScore,
       );

  final GameState _state;

  /// The simulation state this drives.
  GameState get state => _state;

  final List<CollisionEvent> _lastTickCollisions = <CollisionEvent>[];
  final List<SwingResult> _lastTickSwings = <SwingResult>[];

  /// The collision events produced during the most recent [tick].
  ///
  /// Cleared at the start of each [tick] and filled during step 6. Consumed by
  /// the presentation layer for impact effects/audio.
  List<CollisionEvent> get lastTickCollisions =>
      List<CollisionEvent>.unmodifiable(_lastTickCollisions);

  /// The connected swings produced during the most recent [tick].
  ///
  /// Cleared at the start of each [tick] and filled during steps 2 (serve toss)
  /// and 4 (rally swings). Consumed by the presentation layer for swing
  /// effects/audio.
  List<SwingResult> get lastTickSwings =>
      List<SwingResult>.unmodifiable(_lastTickSwings);

  /// A test-only fault hook invoked at the very top of [tick].
  ///
  /// `MatchErrorHandler` tests set this to throw on a chosen frame so the
  /// error-recovery path can be exercised without a real engine fault. It is
  /// never set in production.
  @visibleForTesting
  void Function()? debugFaultInjector;

  /// Starts the match: moves the FSM out of `preMatch` and places the shuttle
  /// for the opening serve. Idempotent-guarded (asserts the match has not
  /// already started).
  void start() {
    assert(
      _state.fsm.phase == MatchPhase.preMatch,
      'start() is only valid before the match has begun '
      '(was ${_state.fsm.phase})',
    );
    _state.fsm.startMatch(_state.frame);
    _placeForServe();
  }

  /// Advances the simulation by exactly one tick (see the class docs for the
  /// load-bearing step order).
  void tick() {
    debugFaultInjector?.call();

    _lastTickCollisions.clear();
    _lastTickSwings.clear();

    final inputs = _readInputs();
    _pumpPhase(inputs);
    _movement(inputs);
    _pinServeShuttle();
    _swings(inputs);
    _physics();
    _collision();
    _resourceTicks(inputs);
    _rules();

    _state.frame += 1;
  }

  // -- Step 1: read + sanitise inputs ---------------------------------------

  /// Reads and sanitises both players' inputs for the current frame.
  _TickInputs _readInputs() {
    final fsm = _state.fsm;
    final serving = fsm.phase == MatchPhase.servePending;
    return _TickInputs(
      left: _sanitise(CourtSide.left, serving: serving),
      right: _sanitise(CourtSide.right, serving: serving),
    );
  }

  int _sanitise(CourtSide side, {required bool serving}) {
    final player = _state.playerOn(side);
    final raw = _state.inputsOn(side).get(_state.frame);
    final isServer = _state.fsm.server == side;
    final context = serving && isServer
        ? InputContext.serving
        : InputContext.rally;
    return InputValidator.sanitize(
      bitmask: raw,
      isStunned: player.isStunned,
      context: context,
      isServer: isServer,
    );
  }

  // -- Step 2: phase pump ----------------------------------------------------

  /// Advances timers for the non-play phases and attempts the serve toss.
  void _pumpPhase(_TickInputs inputs) {
    final fsm = _state.fsm;
    switch (fsm.phase) {
      case MatchPhase.preMatch:
      case MatchPhase.matchOver:
        // Nothing happens this tick. The frame still advances at the end of
        // tick() so the input buffers stay aligned with wall-clock frames.
        return;

      case MatchPhase.servePending:
        fsm.tickServeTimer(_state.frame);
        // The timeout may have ended the serve in a point this very tick.
        if (fsm.phase != MatchPhase.servePending) {
          // A timeout mid-charge: reset the charge counter so it does not
          // carry into the next serve attempt.
          _state.serveChargeTicks = 0;
          return;
        }

        final serverSide = fsm.server;
        final serverInput = serverSide == CourtSide.left
            ? inputs.left
            : inputs.right;
        final tossHeld = InputAction.has(serverInput, InputAction.toss);

        if (tossHeld) {
          // Toss bit is HIGH → accumulate charge (cap at kServeChargeMaxTicks).
          _state.serveChargeTicks = (_state.serveChargeTicks + 1).clamp(
            0,
            kServeChargeMaxTicks,
          );
          // No launch yet — wait for the bit to go LOW.
          return;
        }

        // Toss bit is LOW.
        if (_state.serveChargeTicks == 0) {
          // Never held — nothing to do this tick.
          return;
        }

        // Bit just went LOW with a non-zero charge → RELEASE: launch the serve.
        final chargeFraction = _state.serveChargeTicks / kServeChargeMaxTicks;
        final chargedSpeed = Fix.of(
          kTossSpeedMin + (kTossSpeedMax - kTossSpeedMin) * chargeFraction,
        );
        _state.serveChargeTicks = 0;

        final server = _state.playerOn(serverSide);
        final result = ShotSystem.trySwing(
          player: server,
          shuttle: _state.shuttle,
          rally: _state.rally,
          shotType: ShotType.toss,
          random: _state.random,
          court: _state.court,
          modifiers: ShotModifiers(
            powerMultiplier: StaminaSystem.effortMultiplier(server),
            tossSpeedOverride: chargedSpeed,
          ),
        );
        if (result != null) {
          _lastTickSwings.add(result);
          StaminaSystem.chargeShot(server, ShotType.toss);
          fsm.onServeTossed(_state.frame);
        }

      case MatchPhase.pointScored:
        fsm.tickPointPause(_state.frame);
        if (fsm.phase == MatchPhase.servePending) {
          _placeForServe();
        }

      case MatchPhase.inPlay:
        // No phase-pump work in play; movement/swings/physics handle it.
        return;
    }
  }

  // -- Step 3: movement + jump ----------------------------------------------

  /// Moves and jumps both players (only while `servePending` or `inPlay`).
  void _movement(_TickInputs inputs) {
    if (!_isMovementPhase) return;
    inputs
      ..leftMoved = _moveAndJump(CourtSide.left, inputs.left)
      ..rightMoved = _moveAndJump(CourtSide.right, inputs.right);
  }

  /// Applies movement and jump for one player; returns whether the player
  /// actively moved this tick (nonzero movement and not stunned), which feeds
  /// the stamina drain in step 7.
  bool _moveAndJump(CourtSide side, int input) {
    final player = _state.playerOn(side);

    var dir = Fix.zero;
    if (InputAction.has(input, InputAction.moveLeft)) dir = -Fix.one;
    if (InputAction.has(input, InputAction.moveRight)) dir = Fix.one;

    final moved = dir != Fix.zero && !player.isStunned;
    if (dir != Fix.zero) {
      final dx =
          dir *
          const Fix.of(kPlayerSpeed) *
          StaminaSystem.effortMultiplier(player);
      player.moveBy(dx, _state.court);
    }

    if (InputAction.has(input, InputAction.jump) && player.startJump()) {
      StaminaSystem.chargeJump(player);
    }
    player.tickJump();

    return moved;
  }

  // -- Step 4: swing resolution ---------------------------------------------

  /// Resolves rally swings (only while `inPlay`), implementing M1-015's
  /// both-in-range tie-break by shuttle side.
  void _swings(_TickInputs inputs) {
    if (_state.fsm.phase != MatchPhase.inPlay) return;

    final leftShot = ShotType.fromBitmask(inputs.left);
    final rightShot = ShotType.fromBitmask(inputs.right);
    if (leftShot == null && rightShot == null) return;

    if (leftShot != null && rightShot != null) {
      // Both swung this frame: priority goes to the player on the shuttle's
      // current side (M1-015). If the priority swing connects, the other is
      // dropped; a whiff does NOT veto the other player's attempt.
      final priority = MatchFsm.resolveSimultaneousSwing(
        _state.shuttle,
        _state.court,
      );
      final other = priority == CourtSide.left
          ? CourtSide.right
          : CourtSide.left;
      final priorityShot = priority == CourtSide.left ? leftShot : rightShot;
      final otherShot = priority == CourtSide.left ? rightShot : leftShot;

      final connected = _attemptSwing(priority, priorityShot);
      if (!connected) {
        _attemptSwing(other, otherShot);
      }
    } else if (leftShot != null) {
      _attemptSwing(CourtSide.left, leftShot);
    } else if (rightShot != null) {
      _attemptSwing(CourtSide.right, rightShot);
    }
  }

  /// Attempts one player's swing of [shotType], applying the block-timing and
  /// stamina consequences. Returns whether it connected.
  bool _attemptSwing(CourtSide side, ShotType shotType) {
    final player = _state.playerOn(side);

    final blockTiming = StunSystem.evaluateBlockTiming(
      defender: player,
      shuttle: _state.shuttle,
      rally: _state.rally,
      court: _state.court,
    );

    var power = StaminaSystem.effortMultiplier(player);
    if (blockTiming == BlockTiming.imperfect) {
      power = power * Tunables.imperfectBlockPower;
    }

    final result = ShotSystem.trySwing(
      player: player,
      shuttle: _state.shuttle,
      rally: _state.rally,
      shotType: shotType,
      random: _state.random,
      court: _state.court,
      modifiers: ShotModifiers(powerMultiplier: power),
    );
    if (result == null) return false;

    _lastTickSwings.add(result);
    StaminaSystem.chargeShot(player, shotType);
    if (blockTiming == BlockTiming.imperfect) {
      // An imperfectly timed block still connects but stuns the defender (the
      // weak pop-up per the StunSystem contract). A perfect block is clean.
      StunSystem.applyStun(player);
    }

    // If the connecting hitter is the receiver returning the live serve, the
    // serve-specific rules end here (M1-014).
    if (side == _state.fsm.receiver) {
      _state.fsm.onServeReturned(_state.frame);
    }
    return true;
  }

  // -- Step 5: shuttle physics ----------------------------------------------

  /// Integrates the shuttle one tick (only while `inPlay`).
  void _physics() {
    if (_state.fsm.phase != MatchPhase.inPlay) return;
    _state.shuttle.integrate(
      dragCoefficient: _state.rally.activeDragCoefficient,
    );
  }

  // -- Step 6: collision -----------------------------------------------------

  /// Resolves the shuttle's sweep and lifts a stale lockout (only `inPlay`).
  void _collision() {
    if (_state.fsm.phase != MatchPhase.inPlay) return;
    final events = CollisionSystem.resolve(_state.shuttle, _state.court);
    _lastTickCollisions.addAll(events);
    _state.rally.observe(_state.shuttle, _state.court);
  }

  // -- Step 7: stamina + stun ticks -----------------------------------------

  /// Advances stamina and stun for both players (`servePending`/`inPlay`).
  void _resourceTicks(_TickInputs inputs) {
    if (!_isMovementPhase) return;
    StaminaSystem.tick(_state.leftPlayer, moved: inputs.leftMoved);
    StaminaSystem.tick(_state.rightPlayer, moved: inputs.rightMoved);
    StunSystem.tick(_state.leftPlayer);
    StunSystem.tick(_state.rightPlayer);
  }

  // -- Step 8: rules ---------------------------------------------------------

  /// Feeds this tick's collision events to the FSM (only while `inPlay`).
  ///
  /// A net-cord LET on the serve sends the FSM back to `servePending`, so serve
  /// placement is re-run here too.
  void _rules() {
    if (_state.fsm.phase != MatchPhase.inPlay) return;
    _state.fsm.onCollisionEvents(
      _state.frame,
      _lastTickCollisions,
      _state.rally,
      _state.court,
    );
    if (_state.fsm.phase == MatchPhase.servePending) {
      _placeForServe();
    }
  }

  // -- Serve placement -------------------------------------------------------

  /// Resets the world for a serve: players to their start positions facing the
  /// net (grounded), the shuttle parked in front of the server, and the rally
  /// state cleared.
  ///
  /// Called on every entry into `servePending`: from [start], from a
  /// `pointScored -> servePending` transition, and from a serve net-cord LET.
  ///
  /// Stamina and stun deliberately **persist** across points: carrying fatigue
  /// between rallies is a core design goal, so this resets only position,
  /// facing and the jump arc — not the resource state.
  ///
  /// [GameState.serveChargeTicks] is always reset here so a stale charge from
  /// a previous or interrupted serve (e.g. a LET) does not carry over.
  void _placeForServe() {
    final left = _state.leftPlayer;
    final right = _state.rightPlayer;
    left
      ..x = const Fix.of(kPlayer1StartX)
      ..facing = Facing.right
      ..jumpTick = -1;
    right
      ..x = const Fix.of(kPlayer2StartX)
      ..facing = Facing.left
      ..jumpTick = -1;

    final serverSide = _state.fsm.server;
    final server = _state.playerOn(serverSide);
    // The shuttle sits in front of the server, toward the net.
    final dir = serverSide == CourtSide.left ? Fix.one : -Fix.one;
    final shuttlePos = FixVec2(
      server.x + Tunables.serveShuttleOffsetX * dir,
      Tunables.groundY - Tunables.serveShuttleHeight,
    );
    _state.shuttle = Shuttle(position: shuttlePos);

    _state.rally.reset();
    _state.serveChargeTicks = 0;
  }

  /// Re-pins the parked shuttle to the server while `servePending`.
  ///
  /// Runs every tick directly after movement (step 3): the server may walk
  /// during serve positioning (M1-014), so the shuttle must track the
  /// server's hand — same offset/height as the initial [_placeForServe]
  /// placement — or the toss would launch from wherever the server stood when
  /// the phase began. No-op in every other phase (the shuttle is in flight
  /// or the world is frozen).
  void _pinServeShuttle() {
    if (_state.fsm.phase != MatchPhase.servePending) {
      return;
    }
    final serverSide = _state.fsm.server;
    final server = _state.playerOn(serverSide);
    final dir = serverSide == CourtSide.left ? Fix.one : -Fix.one;
    final pinned = FixVec2(
      server.x + Tunables.serveShuttleOffsetX * dir,
      Tunables.groundY - Tunables.serveShuttleHeight,
    );
    // The pin is a teleport, not flight: keep previousPosition in lockstep so
    // the swept-collision segment is empty if a toss launches next tick.
    _state.shuttle
      ..position = pinned
      ..previousPosition = pinned;
  }

  /// Whether the current phase moves players and ticks their resources.
  bool get _isMovementPhase =>
      _state.fsm.phase == MatchPhase.servePending ||
      _state.fsm.phase == MatchPhase.inPlay;
}

/// This tick's sanitised inputs plus the derived per-player `moved` flags.
///
/// A small mutable carrier passed down the tick steps so movement (step 3) can
/// record the active-movement flag that the stamina tick (step 7) consumes,
/// without recomputing it.
final class _TickInputs {
  _TickInputs({required this.left, required this.right});

  /// The left player's sanitised input bitmask this frame.
  final int left;

  /// The right player's sanitised input bitmask this frame.
  final int right;

  /// Whether the left player actively moved this tick.
  bool leftMoved = false;

  /// Whether the right player actively moved this tick.
  bool rightMoved = false;
}
