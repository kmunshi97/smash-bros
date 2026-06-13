import 'package:flutter/material.dart';
import 'package:smash_bros/game/court_projection.dart';
import 'package:smash_bros/ui/theme/app_colors.dart';

/// A debug-only panel for calibrating the [CourtProjection] live against the
/// stadium art (M2 POC).
///
/// The perspective floor's exact pixel geometry is easiest to align by eye, so
/// this exposes the four projection parameters as sliders that mutate the live
/// projection. Stripped from release builds (mounted only under `kDebugMode`
/// in `main.dart`). Collapsible so it stays out of the way.
class CourtAlignOverlay extends StatefulWidget {
  /// Creates the overlay bound to [projection].
  const CourtAlignOverlay({required this.projection, super.key});

  /// The live projection this panel mutates.
  final CourtProjection projection;

  @override
  State<CourtAlignOverlay> createState() => _CourtAlignOverlayState();
}

class _CourtAlignOverlayState extends State<CourtAlignOverlay> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 8,
      left: 64, // clear the in-game pause button at the top-left
      child: _expanded ? _panel() : _toggle(),
    );
  }

  Widget _toggle() => Material(
    color: AppColors.background.withValues(alpha: 0.85),
    shape: const CircleBorder(),
    child: IconButton(
      icon: const Icon(Icons.crop_free, color: AppColors.accent),
      tooltip: 'Court alignment',
      onPressed: () => setState(() => _expanded = true),
    ),
  );

  Widget _panel() {
    final p = widget.projection;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 280,
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
            Row(
              children: [
                const Icon(Icons.crop_free, size: 18, color: AppColors.accent),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Court alignment',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
            ),
            _slider('offsetX', p.offsetX, -200, 500, (v) => p.offsetX = v),
            _slider('offsetY', p.offsetY, -300, 300, (v) => p.offsetY = v),
            _slider('scaleX', p.scaleX, 0.3, 1.2, (v) => p.scaleX = v),
            _slider('scaleY', p.scaleY, 0.3, 1.2, (v) => p.scaleY = v),
          ],
        ),
      ),
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    void Function(double) write,
  ) {
    final clamped = value.clamp(min, max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                ),
              ),
            ),
            Text(
              clamped.toStringAsFixed(clamped.abs() < 2 ? 3 : 1),
              style: const TextStyle(color: AppColors.accent, fontSize: 12),
            ),
          ],
        ),
        Slider(
          value: clamped,
          min: min,
          max: max,
          activeColor: AppColors.accent,
          inactiveColor: AppColors.divider,
          onChanged: (v) => setState(() => write(v)),
        ),
      ],
    );
  }
}
