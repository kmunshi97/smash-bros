import 'package:flutter/material.dart';
import 'package:smash_bros/game/modes/modes.dart';
import 'package:smash_bros/ui/screens/difficulty_select_screen.dart';
import 'package:smash_bros/ui/theme/app_colors.dart';

/// Mode-select screen (M2-013): pick a [GameMode] to play.
///
/// Full-screen (no popups). Selecting a mode pushes the difficulty-select
/// screen for it; the list is built from the available modes so adding a mode
/// is a one-line change.
class ModeSelectScreen extends StatelessWidget {
  /// Creates the mode-select screen.
  const ModeSelectScreen({super.key});

  /// The modes offered, in display order.
  static const List<GameMode> _modes = [
    ClassicMode(),
    PointRushMode(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text(
          'SELECT MODE',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 3),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              itemCount: _modes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, i) => _ModeCard(mode: _modes[i]),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.mode});

  final GameMode mode;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => DifficultySelectScreen(mode: mode),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Icon(
                mode.isTimed ? Icons.timer : Icons.sports_tennis,
                color: AppColors.accent,
                size: 36,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.displayName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mode.description,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
