import 'package:flutter/material.dart';
import 'package:smash_bros/engine/ai/ai.dart';
import 'package:smash_bros/game/modes/modes.dart';
import 'package:smash_bros/ui/screens/game_screen.dart';
import 'package:smash_bros/ui/theme/app_colors.dart';

/// Difficulty-select screen (M2-024): pick the opponent tier for [mode].
///
/// Full-screen (no popups). Each [AiDifficulty] is a row, plus a "Random"
/// option that lets the game roll a fresh tier per match. Selecting pushes the
/// [GameScreen]; null difficulty means random.
class DifficultySelectScreen extends StatelessWidget {
  /// Creates the difficulty-select screen for [mode].
  const DifficultySelectScreen({required this.mode, super.key});

  /// The mode chosen on the previous screen.
  final GameMode mode;

  /// One-line flavour per tier, shown under the name.
  static String _blurb(AiDifficulty d) => switch (d) {
    AiDifficulty.easy => 'Relaxed — slow to react, gentle shots.',
    AiDifficulty.intermediate => 'Reads the rally; a fair contest.',
    AiDifficulty.hard => 'Predictive and aggressive.',
    AiDifficulty.challenging => 'Near-instant; punishes loose shots.',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text(
          'SELECT DIFFICULTY',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 3),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                for (final d in AiDifficulty.values) ...[
                  _Row(
                    title: d.displayName,
                    subtitle: _blurb(d),
                    icon: Icons.smart_toy,
                    onTap: () => _start(context, d),
                  ),
                  const SizedBox(height: 14),
                ],
                _Row(
                  title: 'Random',
                  subtitle: 'A fresh, secret tier every match.',
                  icon: Icons.casino,
                  onTap: () => _start(context, null),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _start(BuildContext context, AiDifficulty? difficulty) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(mode: mode, difficulty: difficulty),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: AppColors.accent, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
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
