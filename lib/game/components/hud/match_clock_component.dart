import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/game/badminton_game.dart';
import 'package:smash_bros/ui/theme/app_colors.dart';

// ---------------------------------------------------------------------------
// MatchClockComponent — M2-021 (Point Rush countdown)
//
// Top-centre m:ss countdown shown only for timed matches. Reads
// game.view.remainingTicks (engine-owned, deterministic) and renders nothing
// for untimed Classic matches. Lives in the viewport (HUD space).
// ---------------------------------------------------------------------------

/// A top-centre `m:ss` countdown for timed (Point Rush) matches.
///
/// Renders only when `game.view.isTimed`; the time comes from the engine's
/// match clock via `RenderState.remainingTicks`, so it freezes on pause and is
/// identical across machines. Turns to the warning colour in the final 10 s.
class MatchClockComponent extends PositionComponent
    with HasGameReference<BadmintonGame> {
  /// Creates the clock HUD. [safeArea] (game units) keeps it clear of a notch.
  MatchClockComponent({required this.safeArea});

  /// Safe-area insets in game units (top is used).
  EdgeInsets safeArea;

  /// Seconds left below which the clock turns to the warning colour.
  static const int _kWarnSeconds = 10;
  static const double _kTopMargin = 8;

  final TextPaint _normalPaint = TextPaint(
    style: const TextStyle(
      color: AppColors.textPrimary,
      fontSize: 34,
      fontWeight: FontWeight.bold,
      letterSpacing: 2,
    ),
  );
  final TextPaint _warnPaint = TextPaint(
    style: const TextStyle(
      color: AppColors.warning,
      fontSize: 34,
      fontWeight: FontWeight.bold,
      letterSpacing: 2,
    ),
  );

  /// Formats [remainingTicks] as a `m:ss` clock label (rounding up so the last
  /// second shows "0:01", not "0:00", until the clock truly hits zero).
  static String format(int remainingTicks) {
    final totalSeconds = (remainingTicks / kTickRate).ceil();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void render(Canvas canvas) {
    final view = game.view;
    if (!view.isTimed) return;

    final secondsLeft = (view.remainingTicks / kTickRate).ceil();
    final paint = secondsLeft <= _kWarnSeconds ? _warnPaint : _normalPaint;
    final position = Vector2(kCourtWidth / 2, _kTopMargin + safeArea.top);
    paint.render(
      canvas,
      format(view.remainingTicks),
      position,
      anchor: Anchor.topCenter,
    );
  }
}
