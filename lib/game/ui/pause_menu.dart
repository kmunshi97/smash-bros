import 'package:flutter/material.dart';
import 'package:smash_bros/ui/theme/app_colors.dart';

/// The full-screen pause menu (M2-016).
///
/// Shown as a Flame overlay over the (paused) game. Per the design rule there
/// are **no popups** — this covers the whole screen with a dimming scrim. It
/// offers Resume and Restart; both are passed in so this widget stays free of
/// game references and is trivially testable.
class PauseMenu extends StatelessWidget {
  /// Creates the pause menu with [onResume] / [onRestart] callbacks and an
  /// optional [onMainMenu] (the button is hidden when null).
  const PauseMenu({
    required this.onResume,
    required this.onRestart,
    this.onMainMenu,
    super.key,
  });

  /// Called when the player resumes the match.
  final VoidCallback onResume;

  /// Called when the player restarts the match.
  final VoidCallback onRestart;

  /// Called when the player leaves to the main menu, or null to hide the button.
  final VoidCallback? onMainMenu;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background.withValues(alpha: 0.82),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'PAUSED',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 44,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 32),
            _MenuButton(
              label: 'RESUME',
              filled: true,
              onPressed: onResume,
            ),
            const SizedBox(height: 16),
            _MenuButton(
              label: 'RESTART',
              filled: false,
              onPressed: onRestart,
            ),
            if (onMainMenu != null) ...[
              const SizedBox(height: 16),
              _MenuButton(
                label: 'MAIN MENU',
                filled: false,
                onPressed: onMainMenu!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  final String label;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
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
              child: _label(),
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
              child: _label(),
            ),
    );
  }

  Widget _label() => Text(
    label,
    style: const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      letterSpacing: 2,
    ),
  );
}
