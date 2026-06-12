import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smash_bros/engine/ai/basic_ai.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/game/badminton_game.dart';
import 'package:smash_bros/ui/theme/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Landscape-only (ADR-3): the native configs (Info.plist, AndroidManifest)
  // enforce this at the OS level; this call covers desktop dev targets and
  // any platform where the native config is not consulted.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  // Android immersive-sticky full-screen mode (M1-025). Hides status bar and
  // navigation bar; they reappear on swipe and auto-hide again. Harmless on
  // iOS and macOS dev targets.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arcade Badminton',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const GameScreen(),
    );
  }
}

/// Host widget for [BadmintonGame].
///
/// Creates the game ONCE in `initState` (never recreated on rebuild) and
/// wraps it in an edge-to-edge [GameWidget] so the Flame viewport fills the
/// physical screen — touch controls handle their own safe-area insets and
/// should NOT be letterboxed by a Flutter [SafeArea] widget (that would push
/// the court away from the notch).
///
/// Each `build` reads `MediaQuery.paddingOf` (the safe-area insets in logical
/// pixels) and converts them to game units using:
///
///   game_units = logical_pixels * (kGameHeight / screenLogicalHeight)
///
/// where kGameHeight = 720 and screenLogicalHeight comes from
/// `MediaQuery.sizeOf`. This keeps the inset conversion consistent with how
/// the Flame camera letterboxes the 1280×720 viewport onto the screen.
class GameScreen extends StatefulWidget {
  /// Creates the game screen.
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // The game is created once in initState so it is never torn down and
  // recreated on widget rebuilds. Recreating the game would reset simulation
  // state mid-match.
  late final BadmintonGame _game;

  @override
  void initState() {
    super.initState();
    // Wall-clock seeds: fine here — this is the presentation layer, outside the
    // engine. The engine never calls dart:math directly (see CLAUDE.md).
    // Both seeds are derived from the same millisecond base; XOR offset ensures
    // they differ so the AI PRNG stream is independent of the match PRNG stream.
    final base = DateTime.now().millisecondsSinceEpoch;
    _game = BadmintonGame(
      seed: base,
      rightAi: BasicAI(side: CourtSide.right, seed: base ^ 0xDEADBEEF),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Convert safe-area insets from logical pixels to game units.
    //
    // The camera fixes the game resolution at 1280×720. In landscape the
    // letterboxing is height-limited (the viewport height matches the screen
    // height in logical pixels, then the width is clamped). We therefore use
    // the screen's logical height as the denominator:
    //
    //   scale = kGameHeight / screenLogicalHeight
    //           = 720 / screenLogicalHeight
    //
    // Multiplying a logical-pixel inset by this scale gives the equivalent
    // distance in game units. This is an approximation that holds exactly
    // when the viewport fills the full screen height; it is conservative
    // (slightly over-estimates insets) when letterboxing is present, which
    // means controls are offset slightly more than needed — safe for the
    // notch-avoidance use case.
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    // Avoid division by zero on degenerate layouts.
    final scale = size.height > 0 ? 720.0 / size.height : 1.0;

    final safeArea = EdgeInsets.fromLTRB(
      padding.left * scale,
      padding.top * scale,
      padding.right * scale,
      padding.bottom * scale,
    );

    // Forward the converted insets to the game; the control components pick
    // them up on their next update() call.
    _game.safeArea = safeArea;

    // Do NOT wrap GameWidget in SafeArea — that would letterbox the court away
    // from the notch. Touch controls handle their own safe-area insets.
    return GameWidget(game: _game);
  }
}
