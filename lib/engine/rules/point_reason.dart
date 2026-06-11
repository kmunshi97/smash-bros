/// Why the most recent point was awarded.
///
/// Surfaced to the HUD alongside the point winner so the presentation layer
/// can explain *how* the point ended. The `MatchFsm` records the reason on
/// every point award; the badminton semantics are documented per value.
enum PointReason {
  /// The shuttle landed in bounds on a side's floor. In badminton a shuttle
  /// that lands IN on your side is the *opponent's* point regardless of who
  /// hit it, so the point goes to the side opposite the landing side.
  groundedIn,

  /// The shuttle landed out of bounds. The side that hit it last sent it out,
  /// so the point goes to the side that did NOT hit it last.
  groundedOut,

  /// A mid-rally net-body hit: the shuttle failed to clear the net. The point
  /// goes to the side opposite the last hitter (the one who hit into the net).
  netFault,

  /// A serve fell short — it landed in bounds on the receiver's side but did
  /// not reach the receiver's short-service line. The point goes to the
  /// receiver.
  shortServeFault,

  /// The server failed to toss within `kServeTimeoutFrames`. The point goes to
  /// the receiver.
  serveTimeoutFault,

  /// The serve hit the solid body of the net. The point goes to the receiver.
  ///
  /// Note a serve that clips the net *cord* (tape) is a LET, not a fault: the
  /// point is replayed with the same server and no score change.
  serveNetFault,
}
