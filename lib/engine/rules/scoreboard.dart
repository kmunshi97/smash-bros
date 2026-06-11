import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/court.dart';

/// The running score of a single game and the win/deuce arithmetic (M1-016).
///
/// ## Contract
///
/// A [Scoreboard] is mutable in place (the `MatchFsm` calls [award] as points
/// land) and [copy]-able for the rollback snapshot buffer. It is pure score
/// bookkeeping: it knows nothing about phases, serves or entities.
///
/// ## Win and deuce rules (rally scoring, v3 ruleset)
///
/// A side wins when it reaches [targetScore] with a lead of at least two, e.g.
/// 11-9. At [targetScore] - 1 each, play enters deuce ([isDeuce]) and a side
/// must thereafter win by two — *until* the [cap]. The cap is the golden point:
/// reaching it wins outright regardless of lead (so the score can never exceed
/// it). For the default target of 11 the cap is 15, so 14-14 is golden point
/// (the next point wins). The same arithmetic generalises: target 5 caps at 9,
/// target 21 caps at 25.
final class Scoreboard {
  /// Creates a fresh 0-0 scoreboard playing to [targetScore].
  Scoreboard({this.targetScore = kDefaultTargetScore});

  /// The score a side must reach (with a two-point lead) to win the game.
  final int targetScore;

  /// The left side's score.
  int leftScore = 0;

  /// The right side's score.
  int rightScore = 0;

  /// The deuce hard cap: the score at which the next point wins outright.
  ///
  /// Defined as [targetScore] + 4, so a target of 11 caps at 15 (14-14 is
  /// golden point), a target of 5 caps at 9, and a target of 21 caps at 25.
  int get cap => targetScore + 4;

  /// Awards a point to [side], incrementing its score by one.
  void award(CourtSide side) {
    switch (side) {
      case CourtSide.left:
        leftScore += 1;
      case CourtSide.right:
        rightScore += 1;
    }
  }

  /// The side that has won the game, or `null` if play continues.
  ///
  /// A side wins when its score is at least [targetScore] with a lead of at
  /// least two, OR when its score equals the [cap] (golden point). Because the
  /// cap wins outright, a score never exceeds it under normal play.
  CourtSide? get winner {
    if (_sideWins(leftScore, rightScore)) return CourtSide.left;
    if (_sideWins(rightScore, leftScore)) return CourtSide.right;
    return null;
  }

  /// Whether the game is in deuce: both sides are at [targetScore] - 1 or above
  /// and no side has yet won. (At 10-10 with a target of 11, deuce begins.)
  bool get isDeuce =>
      leftScore >= targetScore - 1 &&
      rightScore >= targetScore - 1 &&
      winner == null;

  /// Whether [score] (against [opponent]) is a winning score.
  bool _sideWins(int score, int opponent) {
    if (score == cap) return true;
    return score >= targetScore && score - opponent >= 2;
  }

  /// A deep, independent copy for the rollback snapshot buffer.
  Scoreboard copy() => Scoreboard(targetScore: targetScore)
    ..leftScore = leftScore
    ..rightScore = rightScore;
}
