import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/sim/game_state.dart';

// ---------------------------------------------------------------------------
// AIController — M1-027
//
// ## Architecture: AI as an artificial thumb (NOT an engine system)
//
// The AI lives OUTSIDE the deterministic core. Each tick, the game layer asks
// the AI for an input bitmask and writes it into the right player's InputBuffer
// BEFORE Simulation.tick() — the AI is an artificial thumb on a gamepad, not
// an engine system. Consequences:
//
//   (1) Rollback/replay (M3) replays the RECORDED buffered inputs and never
//       re-runs the AI, so the AI may keep private mutable state without being
//       part of GameState.copy().
//
//   (2) The AI must NOT draw from GameState.random — tick() owns that stream
//       exclusively, and extra draws outside tick() would desync a rollback
//       re-execution from the original timeline. The AI owns a private seeded
//       GameRandom instead.
//
// Determinism still holds end-to-end: same match seed + same AI seed →
// bit-identical match. An AI-vs-AI test validates this.
//
// NOTE: docs/PLAN.md line for M1-027 previously said "randomness only via
// GameState.random" — this PR supersedes that with the safer design above
// (rollback-stream safety). The plan has been updated accordingly.
// ---------------------------------------------------------------------------

/// The contract every AI controller must satisfy.
///
/// ## Contract
///
/// `decide` is called exactly once per simulation tick, before that tick runs.
/// The implementation must:
///
/// * Be deterministic given (construction arguments, sequence of observed
///   `GameState`s) — same inputs must always produce the same bitmask.
/// * Read `state` but **never mutate it**: the game state is owned by the
///   Simulation.
/// * Own its randomness via a private `GameRandom` seeded at construction time,
///   never via `GameState.random` (see file-level architecture note).
/// * Return an `InputAction` bitmask for `side`'s player this frame. Returning
///   `InputAction.none` is always valid.
abstract interface class AIController {
  /// The half of the court this controller is playing for.
  CourtSide get side;

  /// Returns an `InputAction` bitmask representing the buttons the AI "presses"
  /// this frame.
  ///
  /// Called once per simulation tick, immediately before `Simulation.tick` runs.
  /// The returned bitmask is written into the appropriate player's `InputBuffer`
  /// and will be sanitised by `InputValidator` as part of the tick — invalid
  /// combinations (e.g. toss outside serving phase) are filtered out
  /// automatically, so the AI need not guard against them.
  ///
  /// Must read `state` without mutating it.
  int decide(GameState state);
}
