import 'package:flutter/material.dart';
import 'package:smash_bros/engine/ai/ai.dart';
import 'package:smash_bros/game/modes/modes.dart';
import 'package:smash_bros/ui/screens/game_screen.dart';
import 'package:smash_bros/ui/theme/app_colors.dart';
import 'package:smash_bros/ui/widgets/arcade_widgets.dart';

/// Mode setup (M2-024, V2) — the CoC "select your champion" beat: a VS preview,
/// rule toggles (target score / duration + AI difficulty), and a big FIGHT.
///
/// Replaces the old separate mode-select + difficulty-select screens. Picks are
/// resolved into a concrete [GameMode] and an optional [AiDifficulty] (null =
/// Random) and handed to the [GameScreen]. Full-screen (no popups).
class ModeSetupScreen extends StatefulWidget {
  /// Creates the setup screen for [mode] (its kind drives which toggles show).
  const ModeSetupScreen({required this.mode, super.key});

  /// The mode chosen on the home screen (Classic / Point Rush).
  final GameMode mode;

  @override
  State<ModeSetupScreen> createState() => _ModeSetupScreenState();
}

class _ModeSetupScreenState extends State<ModeSetupScreen> {
  // Classic target-score options and Point Rush durations.
  static const List<int> _targets = [5, 11, 21];
  static const List<int> _durations = [60, 90, 120];

  // null in the difficulty list = "Random" (roll a fresh tier each match).
  static const List<AiDifficulty?> _difficulties = [
    AiDifficulty.easy,
    AiDifficulty.intermediate,
    AiDifficulty.hard,
    AiDifficulty.challenging,
    null,
  ];

  late int _target = 11;
  late int _duration = 90;
  AiDifficulty? _difficulty = AiDifficulty.intermediate;

  bool get _isTimed => widget.mode is PointRushMode;

  GameMode _buildMode() => _isTimed
      ? PointRushMode(durationSeconds: _duration)
      : ClassicMode(targetScore: _target);

  void _fight() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(mode: _buildMode(), difficulty: _difficulty),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(title: widget.mode.displayName),
              const Expanded(child: _VsPreview()),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: GlowPanel(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isTimed)
                          _ToggleRow(
                            label: 'DURATION',
                            child: SegmentedToggle<int>(
                              options: _durations,
                              selected: _duration,
                              labelOf: (s) => '${s}s',
                              onChanged: (s) => setState(() => _duration = s),
                            ),
                          )
                        else
                          _ToggleRow(
                            label: 'TARGET SCORE',
                            child: SegmentedToggle<int>(
                              options: _targets,
                              selected: _target,
                              labelOf: (s) => '$s',
                              onChanged: (s) => setState(() => _target = s),
                            ),
                          ),
                        const SizedBox(height: 14),
                        _ToggleRow(
                          label: 'DIFFICULTY',
                          child: SegmentedToggle<AiDifficulty?>(
                            options: _difficulties,
                            selected: _difficulty,
                            labelOf: (d) => d?.displayName ?? 'Random',
                            onChanged: (d) => setState(() => _difficulty = d),
                          ),
                        ),
                        const SizedBox(height: 18),
                        PrimaryCta(
                          label: 'FIGHT!',
                          icon: Icons.sports_mma,
                          onPressed: _fight,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// The player-vs-opponent splash above the rule panel.
class _VsPreview extends StatelessWidget {
  const _VsPreview();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _Portrait(
            asset: 'assets/images/player_red_astronaut.png',
            name: 'YOU',
            color: AppColors.player1,
          ),
          Text(
            'VS',
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(color: AppColors.goldDeep, blurRadius: 12)],
            ),
          ),
          _Portrait(
            asset: 'assets/images/opponent_elon.png',
            name: 'RIVAL',
            color: AppColors.player2,
            flip: true,
          ),
        ],
      ),
    );
  }
}

class _Portrait extends StatelessWidget {
  const _Portrait({
    required this.asset,
    required this.name,
    required this.color,
    this.flip = false,
  });

  final String asset;
  final String name;
  final Color color;
  final bool flip;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 40,
                    spreadRadius: -12,
                  ),
                ],
              ),
              child: Transform.flip(
                flipX: flip,
                child: Image.asset(asset, fit: BoxFit.contain),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}
