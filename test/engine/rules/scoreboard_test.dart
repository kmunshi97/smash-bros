import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/rules/scoreboard.dart';

/// Drives a scoreboard to an exact (left, right) score by awarding points.
Scoreboard _board(int left, int right, {int targetScore = 11}) {
  final board = Scoreboard(targetScore: targetScore);
  for (var i = 0; i < left; i++) {
    board.award(CourtSide.left);
  }
  for (var i = 0; i < right; i++) {
    board.award(CourtSide.right);
  }
  return board;
}

void main() {
  group('Scoreboard.cap', () {
    test('default target 11 caps at 15', () {
      expect(Scoreboard().cap, 15);
    });

    test('generalises: target 5 caps at 9, target 21 caps at 25', () {
      expect(Scoreboard(targetScore: 5).cap, 9);
      expect(Scoreboard(targetScore: 21).cap, 25);
    });
  });

  group('Scoreboard.winner', () {
    test('11-9 is a win for left (two-point lead at target)', () {
      expect(_board(11, 9).winner, CourtSide.left);
    });

    test('11-10 is NOT a win (only a one-point lead) -> play continues', () {
      expect(_board(11, 10).winner, isNull);
    });

    test('extended deuce 13-11 wins', () {
      expect(_board(13, 11).winner, CourtSide.left);
    });

    test('golden point: 15-14 wins at the cap', () {
      expect(_board(15, 14).winner, CourtSide.left);
    });

    test('14-14 has no winner yet (next point is golden)', () {
      final board = _board(14, 14);
      expect(board.winner, isNull);
      board.award(CourtSide.right);
      expect(board.winner, CourtSide.right);
    });

    test('right side can win too', () {
      expect(_board(5, 11).winner, CourtSide.right);
    });

    test('cap win for a lower target (5 -> cap 9): 9-8 wins', () {
      expect(_board(9, 8, targetScore: 5).winner, CourtSide.left);
    });
  });

  group('Scoreboard.isDeuce', () {
    test('10-10 with target 11 is deuce', () {
      expect(_board(10, 10).isDeuce, isTrue);
    });

    test('11-10 is deuce (both at target-1 or above, no winner)', () {
      expect(_board(11, 10).isDeuce, isTrue);
    });

    test('9-10 is not deuce (left below target-1)', () {
      expect(_board(9, 10).isDeuce, isFalse);
    });

    test('a won board is not deuce', () {
      expect(_board(11, 9).isDeuce, isFalse);
    });
  });

  group('Scoreboard.copy', () {
    test('produces an independent snapshot', () {
      final original = _board(8, 6);
      final snapshot = original.copy();

      original
        ..award(CourtSide.left)
        ..award(CourtSide.right);

      expect(snapshot.leftScore, 8);
      expect(snapshot.rightScore, 6);
      expect(snapshot.targetScore, original.targetScore);
    });
  });
}
