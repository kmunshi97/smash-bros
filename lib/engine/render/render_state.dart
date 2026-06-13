import 'package:meta/meta.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/entities/player.dart';
import 'package:smash_bros/engine/entities/shuttle.dart';
import 'package:smash_bros/engine/math/fix.dart';
import 'package:smash_bros/engine/rules/match_phase.dart';
import 'package:smash_bros/engine/rules/point_reason.dart';
import 'package:smash_bros/engine/sim/simulation.dart';
import 'package:smash_bros/engine/systems/collision_system.dart';
import 'package:smash_bros/engine/systems/shot_system.dart';

// ---------------------------------------------------------------------------
// Engine → Renderer contract (M1-021)
//
// This file is the single public surface the presentation layer reads.
// The renderer must capture a [RenderState] each tick and lerp between
// consecutive snapshots; it must NEVER reach into GameState or
// Simulation directly. All continuous values are plain doubles; the
// engine's Fix type must not appear in any public signature here — values
// are converted with Fix.toDouble at capture time so this file stays
// independently importable without Fix arithmetic.
// ---------------------------------------------------------------------------

/// A read-only view of one player for the renderer.
///
/// Created by [PlayerView.from]; all fields are plain scalars or enums.
@immutable
final class PlayerView {
  /// Creates a player view from explicit field values.
  const PlayerView({
    required this.x,
    required this.feetY,
    required this.facing,
    required this.side,
    required this.stamina,
    required this.staminaFraction,
    required this.isStunned,
    required this.isAirborne,
  });

  /// Snapshots a [Player] into a [PlayerView].
  ///
  /// Converts all [Fix] scalars to [double] at capture time so the
  /// renderer never needs to import the engine's math layer.
  factory PlayerView.from(Player p) => PlayerView(
    x: p.x.toDouble(),
    feetY: p.y.toDouble(),
    facing: p.facing,
    side: p.courtSide,
    stamina: p.stamina.toDouble(),
    staminaFraction: (p.stamina.toDouble() / kStaminaMax).clamp(0.0, 1.0),
    isStunned: p.isStunned,
    isAirborne: !p.isGrounded,
  );

  /// Horizontal centre of the player's hitbox, in game units.
  final double x;

  /// Y coordinate of the player's feet (ground-contact point), in game units.
  final double feetY;

  /// The direction the player is facing.
  final Facing facing;

  /// Which half of the court this player occupies.
  final CourtSide side;

  /// The player's current stamina in raw units ([kStaminaMax] = full).
  final double stamina;

  /// Stamina normalised to `[0, 1]` (`stamina / kStaminaMax`, clamped).
  ///
  /// Use this for stamina-bar rendering; avoids a divide every render frame.
  final double staminaFraction;

  /// Whether the player is currently stunned (cannot act).
  final bool isStunned;

  /// Whether the player is currently mid-air (not grounded).
  final bool isAirborne;
}

/// A read-only view of the shuttle for the renderer.
///
/// Created by [ShuttleView.from]; all fields are plain scalars.
@immutable
final class ShuttleView {
  /// Creates a shuttle view from explicit field values.
  const ShuttleView({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
  });

  /// Snapshots a [Shuttle] into a [ShuttleView].
  ///
  /// Converts [Fix] scalars to [double] at capture time.
  factory ShuttleView.from(Shuttle s) => ShuttleView(
    x: s.position.x.toDouble(),
    y: s.position.y.toDouble(),
    vx: s.velocity.x.toDouble(),
    vy: s.velocity.y.toDouble(),
  );

  /// Horizontal position of the shuttle centre, in game units.
  final double x;

  /// Vertical position of the shuttle centre, in game units (+y is downward).
  final double y;

  /// Horizontal velocity, in game units per tick.
  final double vx;

  /// Vertical velocity, in game units per tick (+vy is downward).
  final double vy;
}

// ---------------------------------------------------------------------------
// RenderEvent hierarchy
// ---------------------------------------------------------------------------

/// A transient event that occurred during a single simulation tick.
///
/// Events are captured once by [RenderState.capture] from the tick's swing
/// and collision lists, stored in [RenderState.events], and consumed exactly
/// once by the audio/VFX layer. They must never appear in a lerped
/// [RenderState] (see [RenderState.lerp] docs for the reason).
@immutable
sealed class RenderEvent {
  /// Const base constructor for the sealed hierarchy.
  const RenderEvent();
}

/// A player connected with a swing this tick.
///
/// Produced from a [SwingResult] in [RenderState.capture].
@immutable
final class SwingEvent extends RenderEvent {
  /// Creates a swing event for a connected shot.
  const SwingEvent({
    required this.side,
    required this.shotType,
    required this.wasAirborne,
  });

  /// The court side of the player who hit the shuttle.
  final CourtSide side;

  /// The kind of shot that was played.
  final ShotType shotType;

  /// Whether the hitter was airborne at the moment of contact.
  final bool wasAirborne;
}

/// A defender blocked an incoming smash this tick (M2-030).
///
/// Produced from a `BlockResult` in [RenderState.capture]. Accompanies the
/// defender's [SwingEvent]; it carries the block *quality* so the presentation
/// layer can distinguish a satisfying perfect block from a fumbled one
/// (haptics, screen flash, stun stars).
@immutable
final class BlockEvent extends RenderEvent {
  /// Creates a block event for [side]'s defender.
  const BlockEvent({required this.side, required this.isPerfect});

  /// The court side of the defender who blocked.
  final CourtSide side;

  /// Whether the block was perfectly timed (clean full-power counter) versus
  /// imperfect (weak pop-up; the defender is stunned).
  final bool isPerfect;
}

/// The shuttle reached the ground this tick.
///
/// Produced from a [GroundHit] in [RenderState.capture].
@immutable
final class ShuttleLandedEvent extends RenderEvent {
  /// Creates a shuttle-landed event.
  const ShuttleLandedEvent({
    required this.x,
    required this.side,
    required this.isInBounds,
  });

  /// The x coordinate of the landing point, in game units.
  final double x;

  /// Which half of the court the shuttle landed on.
  final CourtSide side;

  /// Whether the landing point was within the court bounds.
  final bool isInBounds;
}

/// The shuttle clipped the net cord (tape) this tick.
///
/// Produced from a [NetCordHit] in [RenderState.capture]. The shuttle
/// continues but with damped velocity; this event lets the audio layer
/// play the cord-clip sound.
@immutable
final class NetCordEvent extends RenderEvent {
  /// Creates a net-cord event at the given crossing point.
  const NetCordEvent({required this.x, required this.y});

  /// The x coordinate of the net crossing (equals the net X).
  final double x;

  /// The y coordinate of the net crossing.
  final double y;
}

/// The shuttle hit the body of the net this tick.
///
/// Produced from a [NetBodyHit] in [RenderState.capture]. The shuttle stops
/// dead at the net; this event lets the audio layer play the net-hit sound.
@immutable
final class NetBodyEvent extends RenderEvent {
  /// Creates a net-body event at the given crossing point.
  const NetBodyEvent({required this.x, required this.y});

  /// The x coordinate of the net crossing (equals the net X).
  final double x;

  /// The y coordinate of the net crossing.
  final double y;
}

// ---------------------------------------------------------------------------
// RenderState
// ---------------------------------------------------------------------------

/// A complete, immutable snapshot of the simulation state for one tick.
///
/// ## Engine → renderer contract
///
/// [RenderState] is the single data surface between the engine and the Flame
/// layer. The renderer reads `BadmintonGame.view` (a lerped snapshot) every
/// frame and must **never** reach into `GameState` or `Simulation` directly.
/// This separation guarantees that:
///
/// * The engine can advance at a fixed 60 Hz independent of the display rate.
/// * The renderer interpolates smoothly at any refresh rate via [RenderState.lerp].
/// * Replay and rollback (Milestone 3) can snapshot and restore the entire
///   render-visible state through this type without touching Flame.
///
/// ## Lerp / event interaction
///
/// [RenderState.lerp] always returns an empty [events] list.
/// [RenderState.events] on a *captured* snapshot contains the tick's transient
/// events (sounds, VFX triggers). Lerped states are views into the space
/// between two real ticks; delivering events on every render frame would cause
/// audio to fire once per frame (~60-120×) instead of once per tick. Consumers
/// must drain events from captured snapshots via `BadmintonGame.takeEvents`,
/// not from `view`.
@immutable
final class RenderState {
  /// Creates a render state from explicit field values.
  const RenderState({
    required this.frame,
    required this.phase,
    required this.leftPlayer,
    required this.rightPlayer,
    required this.shuttle,
    required this.leftScore,
    required this.rightScore,
    required this.targetScore,
    required this.isDeuce,
    required this.server,
    required this.pointWinner,
    required this.lastPointReason,
    required this.serveCharge,
    required this.events,
  });

  /// Captures the current [Simulation] state into an immutable [RenderState].
  ///
  /// Swings from [Simulation.lastTickSwings] are mapped to [SwingEvent]s
  /// first (in order), then collision events from
  /// [Simulation.lastTickCollisions] are mapped to the appropriate
  /// [RenderEvent] subclass (in order). This preserves the tick-order
  /// causality: swings first, then physics responses.
  factory RenderState.capture(Simulation sim) {
    final state = sim.state;
    final fsm = state.fsm;
    final sb = fsm.scoreboard;

    // Map swings → SwingEvent (in order), then blocks → BlockEvent. A block's
    // SwingEvent comes first (the defender's swing), then the BlockEvent that
    // qualifies it — the presentation layer reads both.
    final events = <RenderEvent>[
      for (final sw in sim.lastTickSwings)
        SwingEvent(
          side: sw.side,
          shotType: sw.shotType,
          wasAirborne: sw.wasAirborne,
        ),
      for (final block in sim.lastTickBlocks)
        BlockEvent(side: block.side, isPerfect: block.isPerfect),
      // Map collision events → the appropriate RenderEvent subclass (in order).
      for (final col in sim.lastTickCollisions)
        switch (col) {
          GroundHit(:final landingX, :final side, :final isInBounds) =>
            ShuttleLandedEvent(
              x: landingX.toDouble(),
              side: side,
              isInBounds: isInBounds,
            ),
          NetCordHit(:final crossing) => NetCordEvent(
            x: crossing.x.toDouble(),
            y: crossing.y.toDouble(),
          ),
          NetBodyHit(:final crossing) => NetBodyEvent(
            x: crossing.x.toDouble(),
            y: crossing.y.toDouble(),
          ),
        },
    ];

    return RenderState(
      frame: state.frame,
      phase: fsm.phase,
      leftPlayer: PlayerView.from(state.leftPlayer),
      rightPlayer: PlayerView.from(state.rightPlayer),
      shuttle: ShuttleView.from(state.shuttle),
      leftScore: sb.leftScore,
      rightScore: sb.rightScore,
      targetScore: sb.targetScore,
      isDeuce: sb.isDeuce,
      server: fsm.server,
      pointWinner: fsm.pointWinner,
      lastPointReason: fsm.lastPointReason,
      serveCharge: (state.serveChargeTicks / kServeChargeMaxTicks).clamp(
        0.0,
        1.0,
      ),
      events: List.unmodifiable(events),
    );
  }

  /// Linearly interpolates between two consecutive render states at fraction
  /// [t] (clamped to `[0, 1]`).
  ///
  /// ## What is interpolated
  ///
  /// Continuous fields — player `x`/`feetY`/`stamina`/`staminaFraction` and
  /// shuttle `x`/`y`/`vx`/`vy` — are lerped. All discrete fields
  /// (`frame`, `phase`, `*Score`, `isDeuce`, `server`, `pointWinner`,
  /// `lastPointReason`) are taken from [b].
  ///
  /// ## Events are always empty
  ///
  /// [events] in the returned state is always `const []`. A lerped state is a
  /// synthetic view between two real ticks; re-delivering events on every
  /// render frame would fire audio and VFX tens of times per tick instead of
  /// once. Consumers must drain events from the captured snapshots via
  /// `BadmintonGame.takeEvents`.
  ///
  /// ## Snap rule
  ///
  /// If `a.frame + 1 != b.frame` OR `a.phase != b.phase`, the method returns
  /// [b] with [events] stripped rather than interpolating. A phase change
  /// (e.g. `servePending` → `inPlay`) or a frame gap (missed tick, rollback)
  /// teleports entities to their correct positions; interpolating across such
  /// a boundary would produce a visible ghost-swoosh.
  RenderState.lerp(RenderState a, RenderState b, double t)
    : this._lerp(a, b, t.clamp(0.0, 1.0));

  /// Internal delegate used by [RenderState.lerp] after clamping.
  ///
  /// Discrete fields taken from [b]: `frame`, `phase`, `*Score`, `isDeuce`,
  /// `server`, `pointWinner`, `lastPointReason`, `serveCharge` (UI meter —
  /// no smoothing needed; always snap to the latest simulation value).
  RenderState._lerp(RenderState a, RenderState b, double t)
    : frame = b.frame,
      phase = b.phase,
      leftScore = b.leftScore,
      rightScore = b.rightScore,
      targetScore = b.targetScore,
      isDeuce = b.isDeuce,
      server = b.server,
      pointWinner = b.pointWinner,
      lastPointReason = b.lastPointReason,
      // serveCharge is a UI meter — taken from b (no lerp needed).
      serveCharge = b.serveCharge,
      // Events always empty in a lerped state (see docs).
      events = const [],
      // Continuous fields: snap if non-consecutive or phase changed.
      leftPlayer = (a.frame + 1 != b.frame || a.phase != b.phase)
          ? b.leftPlayer
          : _lerpPlayer(a.leftPlayer, b.leftPlayer, t),
      rightPlayer = (a.frame + 1 != b.frame || a.phase != b.phase)
          ? b.rightPlayer
          : _lerpPlayer(a.rightPlayer, b.rightPlayer, t),
      shuttle = (a.frame + 1 != b.frame || a.phase != b.phase)
          ? b.shuttle
          : _lerpShuttle(a.shuttle, b.shuttle, t);

  // -- Fields ----------------------------------------------------------------

  /// The simulation frame this snapshot was captured from.
  final int frame;

  /// The match phase at the time of capture.
  final MatchPhase phase;

  /// View of the left player.
  final PlayerView leftPlayer;

  /// View of the right player.
  final PlayerView rightPlayer;

  /// View of the shuttle.
  final ShuttleView shuttle;

  /// Left player's current score.
  final int leftScore;

  /// Right player's current score.
  final int rightScore;

  /// The score needed to win (the match's target score).
  final int targetScore;

  /// Whether the match is currently in deuce.
  final bool isDeuce;

  /// The side currently serving (or due to serve in [MatchPhase.servePending]).
  final CourtSide server;

  /// The winner of the most recently scored point, or `null` before the first
  /// point.
  final CourtSide? pointWinner;

  /// The reason the last point was awarded, or `null` before the first point.
  final PointReason? lastPointReason;

  /// The server's current charge fraction in `[0, 1]`.
  ///
  /// 0 = no charge (button not yet held); 1 = full charge
  /// ([kServeChargeMaxTicks] ticks held). Only meaningful during
  /// [MatchPhase.servePending] when the local player is serving; the game
  /// layer uses this to render the radial charge meter on the TOSS button.
  /// Computed from `GameState.serveChargeTicks / kServeChargeMaxTicks`,
  /// clamped to `[0, 1]`.
  final double serveCharge;

  /// The transient events that occurred during this tick.
  ///
  /// Always `const []` for lerped states (see [RenderState.lerp] docs).
  /// Captured states contain the tick's swing and collision events in tick
  /// order (swings first, then collisions). Drain via
  /// `BadmintonGame.takeEvents`.
  final List<RenderEvent> events;

  // -- Lerp helpers ----------------------------------------------------------

  static PlayerView _lerpPlayer(PlayerView a, PlayerView b, double t) =>
      PlayerView(
        x: _d(a.x, b.x, t),
        feetY: _d(a.feetY, b.feetY, t),
        facing: b.facing,
        side: b.side,
        stamina: _d(a.stamina, b.stamina, t),
        staminaFraction: _d(a.staminaFraction, b.staminaFraction, t),
        isStunned: b.isStunned,
        isAirborne: b.isAirborne,
      );

  static ShuttleView _lerpShuttle(ShuttleView a, ShuttleView b, double t) =>
      ShuttleView(
        x: _d(a.x, b.x, t),
        y: _d(a.y, b.y, t),
        vx: _d(a.vx, b.vx, t),
        vy: _d(a.vy, b.vy, t),
      );

  static double _d(double a, double b, double t) => a + (b - a) * t;
}
