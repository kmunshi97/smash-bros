/// The high-level lifecycle state of a single game (match) under the rules FSM.
///
/// The `MatchFsm` is always in exactly one of these phases; every transition
/// between them is logged with the frame number it happened on (M1-013).
enum MatchPhase {
  /// Before the match has started. Nothing is in motion; the FSM waits for a
  /// `startMatch` call to move to [servePending].
  preMatch,

  /// A serve is owed. The server has the shuttle and must toss it within
  /// `kServeTimeoutFrames`; failing to do so is a serve-timeout fault. A toss
  /// moves the FSM to [inPlay].
  servePending,

  /// A rally is live: the shuttle is in flight and collision events drive the
  /// outcome. Ends when a point is decided, moving the FSM to [pointScored].
  inPlay,

  /// A point has just been awarded. The FSM pauses here for
  /// `kPointPauseTicks` of "point!" presentation time, then advances to
  /// [servePending] for the next serve (or [matchOver] if the game is won).
  pointScored,

  /// The match is decided. A side has reached the target score with the
  /// required lead (or hit the deuce cap). Terminal: no further transitions.
  matchOver,
}
