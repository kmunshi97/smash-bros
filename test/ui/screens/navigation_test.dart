// Widget tests for the menu flow (M2 V1/V2): Home → Mode Setup, the mode
// cards, and the setup toggles. The full GameScreen (Flame) is not pumped here
// — that needs the game loop/asset bundle.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/ai/ai.dart';
import 'package:smash_bros/game/modes/modes.dart';
import 'package:smash_bros/ui/screens/home_screen.dart';
import 'package:smash_bros/ui/screens/mode_setup_screen.dart';
import 'package:smash_bros/ui/widgets/arcade_widgets.dart';

void main() {
  group('Home', () {
    testWidgets('shows the title and the three mode cards', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      expect(find.text('SMASH BROS'), findsOneWidget);
      expect(find.text('CLASSIC'), findsOneWidget);
      expect(find.text('POINT RUSH'), findsOneWidget);
      expect(find.text('COMPETITIVE'), findsOneWidget); // locked
    });

    testWidgets('tapping Classic opens its mode-setup screen', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.tap(find.text('CLASSIC'));
      await tester.pumpAndSettle();
      expect(find.byType(ModeSetupScreen), findsOneWidget);
      expect(find.text('TARGET SCORE'), findsOneWidget);
      expect(find.text('FIGHT!'), findsOneWidget);
    });

    testWidgets('Competitive is locked (no setup screen)', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.tap(find.text('COMPETITIVE'));
      await tester.pumpAndSettle();
      expect(find.byType(ModeSetupScreen), findsNothing);
    });
  });

  group('Mode setup', () {
    testWidgets('Classic shows target-score + difficulty toggles', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: ModeSetupScreen(mode: ClassicMode())),
      );
      expect(find.text('TARGET SCORE'), findsOneWidget);
      expect(find.text('DIFFICULTY'), findsOneWidget);
      expect(find.text('21'), findsOneWidget);
      expect(find.text('Random'), findsOneWidget);
      // Not a timed mode → no duration row.
      expect(find.text('DURATION'), findsNothing);
    });

    testWidgets('Point Rush shows a duration toggle instead of target', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: ModeSetupScreen(mode: PointRushMode())),
      );
      expect(find.text('DURATION'), findsOneWidget);
      expect(find.text('TARGET SCORE'), findsNothing);
      expect(find.text('120s'), findsOneWidget);
    });

    testWidgets('difficulty toggle lists every tier plus Random', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: ModeSetupScreen(mode: ClassicMode())),
      );
      for (final d in AiDifficulty.values) {
        expect(find.text(d.displayName), findsOneWidget);
      }
      await tester.tap(find.text('Hard'));
      await tester.pump();
      expect(find.byType(SegmentedToggle<AiDifficulty?>), findsOneWidget);
    });
  });
}
