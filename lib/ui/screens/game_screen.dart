import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:smash_bros/engine/ai/ai.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/entities/tunables.dart';
import 'package:smash_bros/game/badminton_game.dart';
import 'package:smash_bros/game/components/hud/tuning_overlay.dart';
import 'package:smash_bros/game/match_result.dart';
import 'package:smash_bros/game/modes/modes.dart';
import 'package:smash_bros/game/ui/court_align_overlay.dart';
import 'package:smash_bros/ui/screens/post_match_screen.dart';

/// Host widget for [BadmintonGame] for a chosen [mode] (M2-2C).
///
/// Creates the game ONCE in `initState` (never recreated on rebuild) and wraps
/// it in an edge-to-edge [GameWidget] so the Flame viewport fills the physical
/// screen — touch controls handle their own safe-area insets and should NOT be
/// letterboxed by a Flutter [SafeArea] widget (that would push the court away
/// from the notch).
///
/// Each `build` reads `MediaQuery.paddingOf` (the safe-area insets in logical
/// pixels) and converts them to game units using
/// `game_units = logical_pixels * (720 / screenLogicalHeight)`, matching how
/// the Flame camera letterboxes the 1280×720 viewport onto the screen.
class GameScreen extends StatefulWidget {
  /// Creates the game screen for [mode] against [difficulty] (null = a random
  /// tier rolled per match).
  const GameScreen({required this.mode, this.difficulty, super.key});

  /// The selected game mode (rules: target score + optional time limit).
  final GameMode mode;

  /// The chosen opponent difficulty, or null to roll a random tier each match.
  final AiDifficulty? difficulty;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // The game is created once in initState so it is never torn down and
  // recreated on widget rebuilds. Recreating the game would reset state.
  late final BadmintonGame _game;

  @override
  void initState() {
    super.initState();
    // Wall-clock seeds: fine here — presentation layer, outside the engine.
    // XOR offset ensures the AI PRNG stream is independent of the match stream.
    final base = DateTime.now().millisecondsSinceEpoch;
    final aiSeed = base ^ 0xDEADBEEF;
    // Resolve the initial AI: the chosen tier, or a rolled one for "random".
    final initial = widget.difficulty ?? AiDifficulty.roll(aiSeed);
    _game =
        BadmintonGame(
            seed: base,
            mode: widget.mode,
            rightAi: initial.build(side: CourtSide.right, seed: aiSeed),
            // null keeps restarts rolling a fresh tier (random); a chosen tier
            // is kept across restarts.
            fixedDifficulty: widget.difficulty,
          )
          ..onExitToMenu = _exitToMenu
          ..onMatchOver = _showPostMatch;
  }

  void _exitToMenu() {
    // Pop to the first route (Home), past Mode Select and the game.
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _showPostMatch(MatchResult result) async {
    if (!mounted) return;
    // Full-screen summary over the (finished) match.
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PostMatchScreen(
          result: result,
          mode: widget.mode,
          onPlayAgain: () {
            Navigator.of(context).pop(); // close the summary
            final base = DateTime.now().millisecondsSinceEpoch;
            _game.restartMatch(seed: base, aiSeed: base ^ 0xDEADBEEF);
          },
          onMainMenu: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Convert safe-area insets from logical pixels to game units (see the class
    // doc for the scale derivation).
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final scale = size.height > 0 ? 720.0 / size.height : 1.0;
    _game.safeArea = EdgeInsets.fromLTRB(
      padding.left * scale,
      padding.top * scale,
      padding.right * scale,
      padding.bottom * scale,
    );

    // The full-screen pause menu (M2-016) is a Flame overlay registered on the
    // game itself; the pause button opens it (Resume / Restart / Main Menu).
    final gameWidget = GameWidget(game: _game);

    // Android back button (M2-033): never pop the route mid-match — route it to
    // the pause menu so a stray back-gesture can't drop the player out.
    final guarded = PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _game.openPauseMenu();
      },
      child: gameWidget,
    );

    // Debug-only feel-tuning + court-alignment overlays (stripped from release).
    if (!kDebugMode) return guarded;
    return Stack(
      children: [
        guarded,
        TuningOverlay(
          onApply: (config) {
            Tunables.apply(config);
            final base = DateTime.now().millisecondsSinceEpoch;
            _game.restartMatch(seed: base, aiSeed: base ^ 0xDEADBEEF);
          },
        ),
        CourtAlignOverlay(projection: _game.courtProjection),
      ],
    );
  }
}
