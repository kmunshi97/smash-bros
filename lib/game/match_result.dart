import 'package:meta/meta.dart';
import 'package:smash_bros/engine/entities/court.dart';

/// The outcome of a finished match, handed to the post-match screen (M2-015).
///
/// Pure value type built from the final `RenderState` when the match reaches
/// `MatchPhase.matchOver`. The local human player is always the left side, so
/// `winner == CourtSide.left` means the player won.
@immutable
class MatchResult {
  /// Creates a result with the [winner] and the final [leftScore]/[rightScore].
  const MatchResult({
    required this.winner,
    required this.leftScore,
    required this.rightScore,
  });

  /// The side that won (a finished match is never tied).
  final CourtSide winner;

  /// Final left-side score.
  final int leftScore;

  /// Final right-side score.
  final int rightScore;

  /// Whether the local player (left side) won.
  bool get playerWon => winner == CourtSide.left;
}
