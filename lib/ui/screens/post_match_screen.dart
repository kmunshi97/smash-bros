import 'package:flutter/material.dart';
import 'package:smash_bros/game/match_result.dart';
import 'package:smash_bros/game/modes/modes.dart';
import 'package:smash_bros/ui/theme/app_colors.dart';

/// Full-screen post-match summary (M2-015).
///
/// Shown when the match ends. No popups — it covers the whole screen with the
/// result, the final score, and the mode, plus Play Again / Main Menu. The
/// callbacks keep this widget free of game/navigation references so it is
/// trivially testable.
class PostMatchScreen extends StatelessWidget {
  /// Creates the summary for [result] played in [mode].
  const PostMatchScreen({
    required this.result,
    required this.mode,
    required this.onPlayAgain,
    required this.onMainMenu,
    super.key,
  });

  /// The finished match's outcome.
  final MatchResult result;

  /// The mode that was played (for the label).
  final GameMode mode;

  /// Called to replay the same mode.
  final VoidCallback onPlayAgain;

  /// Called to return to the main menu.
  final VoidCallback onMainMenu;

  @override
  Widget build(BuildContext context) {
    final won = result.playerWon;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                won ? 'YOU WIN' : 'YOU LOSE',
                style: TextStyle(
                  color: won ? AppColors.success : AppColors.player2,
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                mode.displayName.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                  letterSpacing: 6,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '${result.leftScore}  –  ${result.rightScore}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 40),
              _Button(
                label: 'PLAY AGAIN',
                filled: true,
                onPressed: onPlayAgain,
              ),
              const SizedBox(height: 16),
              _Button(label: 'MAIN MENU', filled: false, onPressed: onMainMenu),
            ],
          ),
        ),
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  final String label;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final child = Text(
      label,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
      ),
    );
    return SizedBox(
      width: 280,
      height: 56,
      child: filled
          ? ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: child,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.divider, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: child,
            ),
    );
  }
}
