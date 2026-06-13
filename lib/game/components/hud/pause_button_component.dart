import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';
import 'package:smash_bros/game/badminton_game.dart';
import 'package:smash_bros/ui/theme/app_colors.dart';

// ---------------------------------------------------------------------------
// PauseButtonComponent — M2-016
//
// A small round "‖" button in the top-left of the HUD. Tapping it opens the
// full-screen pause menu (BadmintonGame.openPauseMenu). Lives in the viewport
// (HUD space) like the score and stamina bars; reads no simulation state.
// ---------------------------------------------------------------------------

/// Top-left pause button that opens the full-screen pause menu.
class PauseButtonComponent extends PositionComponent
    with HasGameReference<BadmintonGame>, TapCallbacks {
  /// Creates the pause button. [safeArea] (game units) offsets it clear of the
  /// notch on the leading (left/top) edge.
  PauseButtonComponent({required this.safeArea})
    : super(size: Vector2.all(_kRadius * 2));

  /// Safe-area insets in game units (left + top are used).
  EdgeInsets safeArea;

  static const double _kRadius = 26;
  static const double _kEdgeMargin = 12;

  static final Paint _facePaint = Paint()
    ..color = AppColors.surface.withValues(alpha: 0.85);
  static final Paint _outlinePaint = Paint()
    ..color = AppColors.divider
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  static final Paint _glyphPaint = Paint()..color = AppColors.textPrimary;

  @override
  void update(double dt) {
    position = Vector2(
      _kEdgeMargin + safeArea.left,
      _kEdgeMargin + safeArea.top,
    );
  }

  @override
  void onTapDown(TapDownEvent event) => game.openPauseMenu();

  @override
  void render(Canvas canvas) {
    const c = Offset(_kRadius, _kRadius);
    canvas
      ..drawCircle(c, _kRadius, _facePaint)
      ..drawCircle(c, _kRadius - 1, _outlinePaint);
    // Two pause bars.
    const barW = 5.0;
    const barH = 20.0;
    const gap = 5.0;
    for (final dx in [-(gap + barW) / 2, (gap + barW) / 2]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: c.translate(dx, 0),
            width: barW,
            height: barH,
          ),
          const Radius.circular(2),
        ),
        _glyphPaint,
      );
    }
  }

  /// Whether [point] (local) is inside the round button — keeps the tap target
  /// circular rather than the bounding square.
  @override
  bool containsLocalPoint(Vector2 point) {
    final dx = point.x - _kRadius;
    final dy = point.y - _kRadius;
    return dx * dx + dy * dy <= _kRadius * _kRadius;
  }
}
