// Shared hero-UI building blocks for the menu screens (CoC-inspired).
//
// Pure presentation widgets — a space-gradient backdrop, currency chips, a
// segmented toggle, a gold primary button, and a glowing panel. Kept together
// so the home and mode-setup screens share one visual language.
import 'package:flutter/material.dart';
import 'package:smash_bros/ui/theme/app_colors.dart';

/// A full-bleed deep-space gradient with a faint radial energy glow behind
/// [child] — the common backdrop for every menu screen.
class SpaceBackground extends StatelessWidget {
  /// Wraps [child] over the space backdrop.
  const SpaceBackground({required this.child, super.key});

  /// Foreground content drawn over the backdrop.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.spaceTop, AppColors.spaceBottom],
        ),
      ),
      child: DecoratedBox(
        // A soft cyan glow rising from the centre, like the splash key art.
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.1),
            radius: 1.1,
            colors: [Color(0x3336C5F0), Color(0x00000000)],
          ),
        ),
        child: child,
      ),
    );
  }
}

/// A small rounded pill showing a resource [icon] + [value] (energy, coins…).
class CurrencyChip extends StatelessWidget {
  /// Creates a chip with [icon], [value] and an accent [color].
  const CurrencyChip({
    required this.icon,
    required this.value,
    required this.color,
    super.key,
  });

  /// Leading glyph.
  final IconData icon;

  /// The value text (e.g. "70/70", "1,000").
  final String value;

  /// Accent colour for the icon.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// A horizontal segmented control: one pill per option, the selected one gold.
class SegmentedToggle<T> extends StatelessWidget {
  /// Creates a toggle over [options]; [selected] is highlighted and taps fire
  /// [onChanged]. [labelOf] renders each option's caption.
  const SegmentedToggle({
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    super.key,
  });

  /// The choices, in display order.
  final List<T> options;

  /// The currently selected choice.
  final T selected;

  /// Maps an option to its short caption.
  final String Function(T) labelOf;

  /// Called with the tapped option.
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: _Segment(
                label: labelOf(option),
                isSelected: option == selected,
                onTap: () => onChanged(option),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.gold, AppColors.goldDeep],
                )
              : null,
          borderRadius: BorderRadius.circular(9),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: TextStyle(
              color: isSelected ? Colors.black : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// The big gold primary CTA (PLAY / FIGHT!) with a glow.
class PrimaryCta extends StatelessWidget {
  /// Creates the CTA with [label] and [onPressed].
  const PrimaryCta({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  });

  /// Button caption.
  final String label;

  /// Tap handler.
  final VoidCallback onPressed;

  /// Optional leading icon.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.gold, AppColors.goldDeep],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.45),
              blurRadius: 22,
              spreadRadius: -2,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.black, size: 26),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A glowing translucent panel used to frame menu content.
class GlowPanel extends StatelessWidget {
  /// Wraps [child] in a bordered, faintly-glowing panel with [padding].
  const GlowPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  /// Panel content.
  final Widget child;

  /// Inner padding.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.energy.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: AppColors.energy.withValues(alpha: 0.10),
            blurRadius: 18,
            spreadRadius: -4,
          ),
        ],
      ),
      child: child,
    );
  }
}
