import 'package:flutter/material.dart';
import 'package:smash_bros/engine/balance/balance.dart';
import 'package:smash_bros/engine/entities/tunables.dart';
import 'package:smash_bros/ui/theme/app_colors.dart';

/// One tunable feel parameter exposed as a slider in the [TuningOverlay].
@immutable
class _Knob {
  const _Knob({
    required this.label,
    required this.group,
    required this.min,
    required this.max,
    required this.read,
    required this.write,
  });

  /// Human-readable name shown next to the slider.
  final String label;

  /// Section heading this knob is grouped under.
  final String group;

  /// Slider bounds.
  final double min;
  final double max;

  /// Reads the field's current value from a [BalanceConfig].
  final double Function(BalanceConfig) read;

  /// Returns a copy of the config with this field set to the given value.
  final BalanceConfig Function(BalanceConfig config, double value) write;
}

/// Every feel knob, in display order, grouped by subsystem.
final List<_Knob> _knobs = [
  _Knob(
    label: 'Gravity',
    group: 'Shuttle physics',
    min: 0.02,
    max: 0.4,
    read: (c) => c.shuttleGravity,
    write: (c, v) => c.copyWith(shuttleGravity: v),
  ),
  _Knob(
    label: 'Drag',
    group: 'Shuttle physics',
    min: 0,
    max: 0.005,
    read: (c) => c.shuttleDragCoefficient,
    write: (c, v) => c.copyWith(shuttleDragCoefficient: v),
  ),
  _Knob(
    label: 'Drop drag',
    group: 'Shuttle physics',
    min: 0,
    max: 0.005,
    read: (c) => c.shuttleDropShotDrag,
    write: (c, v) => c.copyWith(shuttleDropShotDrag: v),
  ),
  _Knob(
    label: 'Max velocity',
    group: 'Shuttle physics',
    min: 10,
    max: 30,
    read: (c) => c.shuttleMaxVelocity,
    write: (c, v) => c.copyWith(shuttleMaxVelocity: v),
  ),
  _Knob(
    label: 'Net-cord damping',
    group: 'Shuttle physics',
    min: 0,
    max: 1,
    read: (c) => c.netCordDamping,
    write: (c, v) => c.copyWith(netCordDamping: v),
  ),
  _Knob(
    label: 'Normal speed',
    group: 'Shots',
    min: 4,
    max: 20,
    read: (c) => c.normalShotSpeed,
    write: (c, v) => c.copyWith(normalShotSpeed: v),
  ),
  _Knob(
    label: 'Smash speed',
    group: 'Shots',
    min: 8,
    max: 24,
    read: (c) => c.smashSpeed,
    write: (c, v) => c.copyWith(smashSpeed: v),
  ),
  _Knob(
    label: 'Drop speed',
    group: 'Shots',
    min: 4,
    max: 16,
    read: (c) => c.dropShotSpeed,
    write: (c, v) => c.copyWith(dropShotSpeed: v),
  ),
  _Knob(
    label: 'Jump-smash bonus',
    group: 'Shots',
    min: 1,
    max: 1.5,
    read: (c) => c.jumpSmashBonus,
    write: (c, v) => c.copyWith(jumpSmashBonus: v),
  ),
  _Knob(
    label: 'Toss speed min',
    group: 'Serve',
    min: 6,
    max: 20,
    read: (c) => c.tossSpeedMin,
    write: (c, v) => c.copyWith(tossSpeedMin: v),
  ),
  _Knob(
    label: 'Toss speed max',
    group: 'Serve',
    min: 8,
    max: 24,
    read: (c) => c.tossSpeedMax,
    write: (c, v) => c.copyWith(tossSpeedMax: v),
  ),
  _Knob(
    label: 'Player speed',
    group: 'Player',
    min: 2,
    max: 12,
    read: (c) => c.playerSpeed,
    write: (c, v) => c.copyWith(playerSpeed: v),
  ),
  _Knob(
    label: 'Drain: normal',
    group: 'Stamina',
    min: 0,
    max: 20,
    read: (c) => c.staminaDrainNormal,
    write: (c, v) => c.copyWith(staminaDrainNormal: v),
  ),
  _Knob(
    label: 'Drain: smash',
    group: 'Stamina',
    min: 0,
    max: 30,
    read: (c) => c.staminaDrainSmash,
    write: (c, v) => c.copyWith(staminaDrainSmash: v),
  ),
  _Knob(
    label: 'Drain: jump',
    group: 'Stamina',
    min: 0,
    max: 20,
    read: (c) => c.staminaDrainJump,
    write: (c, v) => c.copyWith(staminaDrainJump: v),
  ),
  _Knob(
    label: 'Drain: move',
    group: 'Stamina',
    min: 0,
    max: 2,
    read: (c) => c.staminaDrainMove,
    write: (c, v) => c.copyWith(staminaDrainMove: v),
  ),
  _Knob(
    label: 'Regen',
    group: 'Stamina',
    min: 0,
    max: 2,
    read: (c) => c.staminaRegen,
    write: (c, v) => c.copyWith(staminaRegen: v),
  ),
];

/// A debug-only feel-tuning panel (M1-032).
///
/// Renders a collapsible slider panel over the game. Each slider edits one
/// [BalanceConfig] field; releasing a slider (or pressing Reset) fires
/// [onApply] with the new config so the host can `Tunables.apply` it and
/// restart the match. This is a **dev tool** — `main.dart` only mounts it in
/// debug builds, so it is stripped from release.
///
/// Sliders move live ([Slider.onChanged] updates the displayed value), but the
/// expensive match restart only happens on [Slider.onChangeEnd] to avoid
/// rebuilding the simulation on every drag frame.
class TuningOverlay extends StatefulWidget {
  /// Creates the overlay. [onApply] receives the edited config when the user
  /// finishes a slider drag or resets to defaults.
  const TuningOverlay({required this.onApply, super.key});

  /// Called with the new config when a slider drag ends or Reset is pressed.
  final void Function(BalanceConfig config) onApply;

  @override
  State<TuningOverlay> createState() => _TuningOverlayState();
}

class _TuningOverlayState extends State<TuningOverlay> {
  bool _expanded = false;

  // The live working copy the sliders edit. Seeded from whatever config is
  // currently active (loaded from the asset at launch).
  late BalanceConfig _working = Tunables.config;

  void _onChanged(_Knob knob, double value) {
    setState(() => _working = knob.write(_working, value));
  }

  void _reset() {
    setState(() => _working = const BalanceConfig.defaults());
    widget.onApply(_working);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 8,
      right: 8,
      child: _expanded ? _buildPanel() : _buildToggle(),
    );
  }

  Widget _buildToggle() {
    return _PanelButton(
      icon: Icons.tune,
      tooltip: 'Feel tuning',
      onPressed: () => setState(() => _expanded = true),
    );
  }

  Widget _buildPanel() {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 300,
        constraints: const BoxConstraints(maxHeight: 460),
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const Divider(color: AppColors.divider, height: 12),
            Flexible(
              child: SingleChildScrollView(child: _buildKnobList()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.tune, size: 18, color: AppColors.accent),
        const SizedBox(width: 6),
        const Expanded(
          child: Text(
            'Feel tuning',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        TextButton(
          onPressed: _reset,
          child: const Text('Reset', style: TextStyle(color: AppColors.accent)),
        ),
        IconButton(
          icon: const Icon(
            Icons.close,
            size: 18,
            color: AppColors.textSecondary,
          ),
          onPressed: () => setState(() => _expanded = false),
        ),
      ],
    );
  }

  Widget _buildKnobList() {
    final children = <Widget>[];
    String? lastGroup;
    for (final knob in _knobs) {
      if (knob.group != lastGroup) {
        children.add(_buildGroupHeading(knob.group));
        lastGroup = knob.group;
      }
      children.add(_buildKnobRow(knob));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _buildGroupHeading(String group) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Text(
        group.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 10,
          letterSpacing: 1,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildKnobRow(_Knob knob) {
    final value = knob.read(_working).clamp(knob.min, knob.max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                knob.label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                ),
              ),
            ),
            Text(
              _format(value),
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 12,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: value,
            min: knob.min,
            max: knob.max,
            activeColor: AppColors.accent,
            inactiveColor: AppColors.divider,
            onChanged: (v) => _onChanged(knob, v),
            onChangeEnd: (_) => widget.onApply(_working),
          ),
        ),
      ],
    );
  }

  /// Compact value formatting: small coefficients get more decimals.
  static String _format(double value) {
    if (value.abs() < 1) return value.toStringAsFixed(4);
    if (value.abs() < 10) return value.toStringAsFixed(2);
    return value.toStringAsFixed(1);
  }
}

/// The collapsed floating toggle button.
class _PanelButton extends StatelessWidget {
  const _PanelButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background.withValues(alpha: 0.85),
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, color: AppColors.accent),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}
