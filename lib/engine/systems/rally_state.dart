import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/entities/shuttle.dart';
import 'package:smash_bros/engine/entities/tunables.dart';
import 'package:smash_bros/engine/math/fix.dart';
import 'package:smash_bros/engine/systems/shot_type.dart';

/// Per-point rally bookkeeping shared by the shot, collision and (later) match
/// systems.
///
/// ## Contract
///
/// [RallyState] holds the small amount of state that outlives a single tick but
/// not a whole match: who last touched the shuttle, who is currently barred
/// from swinging (carry / double-hit prevention), and which air-drag
/// coefficient the [Shuttle] should integrate with this tick. It is mutated in
/// place and is snapshot-friendly via [copy] for the rollback buffer.
///
/// ## Tick order
///
/// [observe] runs once per tick by the Simulation **after** shuttle
/// integration and collision resolution, lifting a stale hit-lockout once the
/// shuttle has left the hitter's side. The shot system reads and writes
/// [lastHitter] / [hitLockout] / [activeDragCoefficient] when a swing connects.
/// The match FSM (a later PR) calls [reset] at the start of each point.
final class RallyState {
  /// Creates a rally state, defaulting every field to its start-of-point value.
  RallyState({
    this.lastHitter,
    this.hitLockout,
    this.lastShotType,
    Fix? activeDragCoefficient,
  }) : activeDragCoefficient =
           activeDragCoefficient ?? Tunables.shuttleDragCoefficient;

  /// Which side last hit the shuttle, or `null` when it is untouched since the
  /// serve.
  CourtSide? lastHitter;

  /// The [ShotType] of the most recent connecting swing, or `null` when the
  /// shuttle is untouched since the serve.
  ///
  /// Set by `ShotSystem.trySwing` on a successful hit. The defence logic reads
  /// it (via `StunSystem.evaluateBlockTiming`) to know whether the incoming
  /// shot is a smash that can be perfect-blocked.
  ShotType? lastShotType;

  /// The side currently forbidden to swing, or `null` when neither side is
  /// locked out.
  ///
  /// Set to the hitter's side on every successful hit so a player cannot carry
  /// or double-hit the shuttle (M1-008). Lifted by [observe] once the shuttle
  /// leaves that side.
  CourtSide? hitLockout;

  /// The quadratic-drag coefficient the Simulation passes to
  /// [Shuttle.integrate] each tick.
  ///
  /// Defaults to [Tunables.shuttleDragCoefficient]; a drop shot switches it to
  /// [Tunables.shuttleDropShotDrag] and any other shot switches it back.
  Fix activeDragCoefficient;

  /// Lifts a stale hit-lockout once the shuttle has left the hitter's side.
  ///
  /// Called once per tick by the Simulation **after** shuttle integration. The
  /// lockout-lift rule is simply "the shuttle is no longer on the hitter's
  /// side": when [hitLockout] is set and `court.sideOfX(shuttle.position.x)`
  /// differs from it, the lockout clears. This single rule covers both clean
  /// crossings to the opponent's half and net-cord dribbles that fall back —
  /// in either case the shuttle is off the hitter's side, so they may legally
  /// play it again.
  void observe(Shuttle shuttle, Court court) {
    final lockout = hitLockout;
    if (lockout != null && court.sideOfX(shuttle.position.x) != lockout) {
      hitLockout = null;
    }
  }

  /// Resets every field to its start-of-point value (called by the match FSM
  /// at the start of each point).
  void reset() {
    lastHitter = null;
    hitLockout = null;
    lastShotType = null;
    activeDragCoefficient = Tunables.shuttleDragCoefficient;
  }

  /// A deep, independent copy for the rollback snapshot buffer.
  RallyState copy() => RallyState(
    lastHitter: lastHitter,
    hitLockout: hitLockout,
    lastShotType: lastShotType,
    activeDragCoefficient: activeDragCoefficient,
  );
}
