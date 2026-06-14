// Widget tests for the post-match summary screen (M2-015).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/game/match_result.dart';
import 'package:smash_bros/game/modes/modes.dart';
import 'package:smash_bros/ui/screens/post_match_screen.dart';

void main() {
  Widget host(
    MatchResult result, {
    VoidCallback? onPlay,
    VoidCallback? onMenu,
  }) {
    return MaterialApp(
      home: PostMatchScreen(
        result: result,
        mode: const ClassicMode(),
        onPlayAgain: onPlay ?? () {},
        onMainMenu: onMenu ?? () {},
      ),
    );
  }

  testWidgets('shows YOU WIN and the score when the player (left) wins', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const MatchResult(
          winner: CourtSide.left,
          leftScore: 11,
          rightScore: 7,
        ),
      ),
    );
    expect(find.text('YOU WIN'), findsOneWidget);
    expect(find.text('YOU LOSE'), findsNothing);
    expect(find.textContaining('11'), findsOneWidget);
    expect(find.text('CLASSIC'), findsOneWidget);
  });

  testWidgets('shows YOU LOSE when the opponent (right) wins', (tester) async {
    await tester.pumpWidget(
      host(
        const MatchResult(
          winner: CourtSide.right,
          leftScore: 9,
          rightScore: 11,
        ),
      ),
    );
    expect(find.text('YOU LOSE'), findsOneWidget);
  });

  testWidgets('fires Play Again and Main Menu', (tester) async {
    var play = 0;
    var menu = 0;
    await tester.pumpWidget(
      host(
        const MatchResult(
          winner: CourtSide.left,
          leftScore: 11,
          rightScore: 0,
        ),
        onPlay: () => play++,
        onMenu: () => menu++,
      ),
    );
    await tester.tap(find.text('PLAY AGAIN'));
    await tester.tap(find.text('MAIN MENU'));
    expect(play, 1);
    expect(menu, 1);
  });
}
