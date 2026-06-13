import 'package:meta/meta.dart';
import 'package:smash_bros/engine/constants.dart';

/// A selectable way to play a match (M2-019).
///
/// A [GameMode] is pure configuration that the game layer turns into a
/// `Simulation` (target score + optional time limit) — it carries no mutable
/// state and never touches the engine internals, so modes stay trivially
/// testable and swappable from the mode-select screen.
///
/// ## Timer-expiry semantics (the M2-019 contract)
///
/// A timed mode sets [timeLimitTicks]; the engine's match clock
/// (`MatchFsm.tickMatchClock`) is checked **after** each tick's points are
/// scored, so:
///
/// * a countdown hitting zero mid-rally lets the rally play out and its point
///   count — the match only ends at the following point boundary;
/// * expiry and a point on the same tick resolve in favour of the point;
/// * if the score is tied when the clock expires, play continues (golden
///   point) until the next point breaks the tie.
@immutable
sealed class GameMode {
  /// Const base constructor for the sealed hierarchy.
  const GameMode();

  /// Stable identifier (analytics, prefs, deep links).
  String get id;

  /// Short name shown on the mode-select screen.
  String get displayName;

  /// One-line description of how the mode plays.
  String get description;

  /// Points a side must reach to win (with the standard 2-point lead / golden
  /// point cap). For purely timed modes this is set high enough that the clock,
  /// not the scoreboard, ends the match.
  int get targetScore;

  /// Total match length in simulation ticks for a timed mode, or `null` for an
  /// untimed mode that ends only by the scoreboard.
  int? get timeLimitTicks;

  /// Whether this mode is timed.
  bool get isTimed => timeLimitTicks != null;
}

/// Standard badminton: first to [targetScore] (with a 2-point lead, golden
/// point at target+4), no clock (M2-020).
final class ClassicMode extends GameMode {
  /// Creates a classic match to [targetScore] (default [kDefaultTargetScore]).
  const ClassicMode({this.targetScore = kDefaultTargetScore});

  @override
  final int targetScore;

  @override
  String get id => 'classic_$targetScore';

  @override
  String get displayName => 'Classic';

  @override
  String get description => 'First to $targetScore, win by 2.';

  @override
  int? get timeLimitTicks => null;
}

/// Point Rush: score as many points as possible before the clock runs out;
/// the leader when time expires wins, ties go to a golden point (M2-021).
final class PointRushMode extends GameMode {
  /// Creates a Point Rush match lasting [durationSeconds] (default 90 s).
  const PointRushMode({this.durationSeconds = 90});

  /// Match length in seconds.
  final int durationSeconds;

  /// A target the scoreboard can never reach, so only the clock ends the match.
  static const int _unreachableTarget = 100000;

  @override
  int get targetScore => _unreachableTarget;

  @override
  int get timeLimitTicks => durationSeconds * kTickRate;

  @override
  String get id => 'point_rush_$durationSeconds';

  @override
  String get displayName => 'Point Rush';

  @override
  String get description => 'Most points in ${durationSeconds}s wins.';
}
