// Widget tests for the screen flow (M2-2C): Home → Mode Select, and the mode
// cards. The full GameScreen (Flame) is not pumped here — that needs the game
// loop/asset bundle; navigation up to mode select is what these cover.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/game/modes/modes.dart';
import 'package:smash_bros/ui/screens/difficulty_select_screen.dart';
import 'package:smash_bros/ui/screens/home_screen.dart';
import 'package:smash_bros/ui/screens/mode_select_screen.dart';

void main() {
  testWidgets('Home shows the title and a PLAY button', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    expect(find.text('SMASH BROS'), findsOneWidget);
    expect(find.text('PLAY'), findsOneWidget);
  });

  testWidgets('PLAY navigates to the mode-select screen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.tap(find.text('PLAY'));
    await tester.pumpAndSettle();

    expect(find.byType(ModeSelectScreen), findsOneWidget);
    expect(find.text('SELECT MODE'), findsOneWidget);
  });

  testWidgets('Mode select offers Classic and Point Rush', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ModeSelectScreen()));
    expect(find.text('Classic'), findsOneWidget);
    expect(find.text('Point Rush'), findsOneWidget);
    // Descriptions reflect the mode rules.
    expect(find.textContaining('First to 11'), findsOneWidget);
    expect(find.textContaining('Most points'), findsOneWidget);
  });

  testWidgets('selecting a mode navigates to difficulty select', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ModeSelectScreen()));
    await tester.tap(find.text('Classic'));
    await tester.pumpAndSettle();
    expect(find.byType(DifficultySelectScreen), findsOneWidget);
  });

  testWidgets('difficulty select lists every tier plus Random', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: DifficultySelectScreen(mode: ClassicMode())),
    );
    expect(find.text('Easy'), findsOneWidget);
    expect(find.text('Intermediate'), findsOneWidget);
    expect(find.text('Hard'), findsOneWidget);
    expect(find.text('Challenging'), findsOneWidget);
    expect(find.text('Random'), findsOneWidget);
  });
}
