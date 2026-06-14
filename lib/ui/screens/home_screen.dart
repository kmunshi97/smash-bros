import 'package:flutter/material.dart';
import 'package:smash_bros/game/modes/modes.dart';
import 'package:smash_bros/ui/models/player_profile.dart';
import 'package:smash_bros/ui/screens/mode_setup_screen.dart';
import 'package:smash_bros/ui/theme/app_colors.dart';
import 'package:smash_bros/ui/widgets/arcade_widgets.dart';

/// The home hub (M2-012, V1) — CoC-inspired: a status bar, a hero VS diorama,
/// and the game-mode cards.
///
/// Full-screen (no popups). Tapping a playable mode opens its setup screen;
/// Competitive is shown locked (ranked arrives with the Milestone-3 backend).
class HomeScreen extends StatelessWidget {
  /// Creates the home screen.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              const _StatusBar(profile: PlayerProfile.demo),
              const Expanded(child: _RosterShowcase()),
              _ModeRail(
                onPlay: (mode) => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ModeSetupScreen(mode: mode),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const _BottomNav(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status bar — avatar + level, name, currency chips.
// ---------------------------------------------------------------------------

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.profile});

  final PlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          _Avatar(level: profile.level),
          const SizedBox(width: 10),
          Text(
            profile.name,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          CurrencyChip(
            icon: Icons.bolt,
            value: '${profile.energy}/${profile.maxEnergy}',
            color: AppColors.gold,
          ),
          const SizedBox(width: 8),
          CurrencyChip(
            icon: Icons.monetization_on,
            value: '${profile.coins}',
            color: AppColors.gold,
          ),
          const SizedBox(width: 8),
          CurrencyChip(
            icon: Icons.diamond,
            value: '${profile.gems}',
            color: AppColors.energy,
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 2),
              image: const DecorationImage(
                image: AssetImage('assets/images/player_red_astronaut.png'),
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
          ),
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.spaceBottom, width: 1.5),
              ),
              child: Text(
                '$level',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Roster showcase — the home hub's hero art: the champion line-up (NOT a 1v1
// VS — that belongs to the fight/mode-setup screen). The player's champion is
// featured centre, larger and lit; rivals flank it, smaller and dimmer.
// ---------------------------------------------------------------------------

class _RosterShowcase extends StatelessWidget {
  const _RosterShowcase();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'SMASH BROS',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 40,
            fontWeight: FontWeight.w900,
            letterSpacing: 5,
            shadows: [Shadow(color: AppColors.energy, blurRadius: 18)],
          ),
        ),
        Text(
          'ARCADE BADMINTON',
          style: TextStyle(
            color: AppColors.gold,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 7,
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Rivals flank the hero, facing inward, smaller + dimmer.
                _RosterMember(
                  asset: 'assets/images/opponent_mukesh.png',
                  flex: 3,
                  heightFactor: 0.68,
                  opacity: 0.65,
                  flip: true, // mukesh faces left by default → face the hero
                  glow: AppColors.player2,
                ),
                _RosterMember(
                  asset: 'assets/images/player_red_astronaut.png',
                  flex: 4,
                  glow: AppColors.energy,
                ),
                _RosterMember(
                  asset: 'assets/images/opponent_elon.png',
                  flex: 3,
                  heightFactor: 0.68,
                  opacity: 0.65,
                  flip: true, // elon faces right by default → face the hero
                  glow: AppColors.player2,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RosterMember extends StatelessWidget {
  const _RosterMember({
    required this.asset,
    required this.flex,
    required this.glow,
    this.heightFactor = 1,
    this.opacity = 1,
    this.flip = false,
  });

  final String asset;
  final int flex;
  final Color glow;
  final double heightFactor;
  final double opacity;
  final bool flip;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      flex: flex,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: heightFactor,
          child: Opacity(
            opacity: opacity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: glow.withValues(alpha: 0.30),
                    blurRadius: 38,
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
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mode rail — one card per game mode + a locked Competitive card.
// ---------------------------------------------------------------------------

class _ModeRail extends StatelessWidget {
  const _ModeRail({required this.onPlay});

  final void Function(GameMode mode) onPlay;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _ModeCard(
            title: 'Classic',
            subtitle: 'First to 11, win by 2.',
            icon: Icons.sports_tennis,
            accent: AppColors.energy,
            onTap: () => onPlay(const ClassicMode()),
          ),
          _ModeCard(
            title: 'Point Rush',
            subtitle: 'Most points before time runs out.',
            icon: Icons.timer,
            accent: AppColors.gold,
            onTap: () => onPlay(const PointRushMode()),
          ),
          const _ModeCard(
            title: 'Competitive',
            subtitle: 'Ranked ladder — coming soon.',
            icon: Icons.emoji_events,
            accent: AppColors.player2,
            locked: true,
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    this.onTap,
    this.locked = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: locked ? null : onTap,
          child: Opacity(
            opacity: locked ? 0.55 : 1,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [accent.withValues(alpha: 0.28), AppColors.panel],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: accent, size: 26),
                      const Spacer(),
                      Icon(
                        locked ? Icons.lock : Icons.play_circle_fill,
                        color: locked ? AppColors.textSecondary : accent,
                        size: 24,
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom nav — Home active; Store / Settings are placeholders for later M2.
// ---------------------------------------------------------------------------

class _BottomNav extends StatelessWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _NavIcon(icon: Icons.home, label: 'Home', active: true),
        _NavIcon(icon: Icons.storefront, label: 'Store'),
        _NavIcon(icon: Icons.settings, label: 'Settings'),
      ],
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    required this.label,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.gold : AppColors.textSecondary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
