import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/game/badminton_game.dart';
import 'package:smash_bros/game/palette.dart';

// ---------------------------------------------------------------------------
// StaminaBarComponent — M1-026
//
// A 220×18 game-unit stamina bar anchored to the top-left (CourtSide.left)
// or top-right (CourtSide.right) of the viewport, with a 2-unit border.
//
// Fill colour:
//   • Green (GamePalette.staminaFill) when stamina ≥ kStaminaDebuffThreshold.
//   • Alert red (GamePalette.staminaLow) when below the threshold.
//
// Position in tick order: reads only from game.view (RenderState snapshot);
// never touches the simulation.
// ---------------------------------------------------------------------------

const double _kBarWidth = 220;
const double _kBarHeight = 18;
const double _kBorder = 2;
const double _kEdgeMargin = 12;
const double _kTopMargin = 12;

/// A per-side stamina bar rendered in the top-left or top-right corner of the
/// HUD viewport.
///
/// Added to `camera.viewport` in [BadmintonGame.onLoad]; reads only
/// `game.view` each frame.
///
/// [safeArea] is in game units; the top and left/right insets clear the device
/// status bar and notch. Updated via `BadmintonGame.safeArea` setter each
/// frame.
class StaminaBarComponent extends PositionComponent
    with HasGameReference<BadmintonGame> {
  /// Creates a stamina bar for [side], offset by [safeArea].
  StaminaBarComponent({required this.side, required this.safeArea});

  /// The court side this bar tracks.
  final CourtSide side;

  /// Safe-area padding in game units.
  ///
  /// Updated by [BadmintonGame] whenever the device insets change.
  EdgeInsets safeArea;

  @override
  void render(Canvas canvas) {
    final v = game.view;
    final viewportSize = game.camera.viewport.size;

    final topY = _kTopMargin + safeArea.top;
    final leftX = side == CourtSide.left
        ? _kEdgeMargin + safeArea.left
        : viewportSize.x - _kEdgeMargin - safeArea.right - _kBarWidth;

    const outerWidth = _kBarWidth;
    const outerHeight = _kBarHeight;
    final outerRect = Rect.fromLTWH(leftX, topY, outerWidth, outerHeight);

    // -- Border / background --------------------------------------------------
    final bgPaint = Paint()..color = GamePalette.staminaBarBackground;
    canvas.drawRect(outerRect, bgPaint);

    final borderPaint = Paint()
      ..color = GamePalette.staminaBarBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = _kBorder;
    canvas.drawRect(outerRect, borderPaint);

    // -- Fill -----------------------------------------------------------------
    const innerWidth = _kBarWidth - _kBorder * 2;
    const innerHeight = _kBarHeight - _kBorder * 2;
    final innerLeft = leftX + _kBorder;
    final innerTop = topY + _kBorder;

    final fraction = side == CourtSide.left
        ? v.leftPlayer.staminaFraction
        : v.rightPlayer.staminaFraction;

    // Alert fill when stamina fraction is below the debuff threshold fraction.
    final isLow = fraction < kStaminaDebuffThreshold / kStaminaMax;

    final fillColor = isLow ? GamePalette.staminaLow : GamePalette.staminaFill;

    final fillWidth = (innerWidth * fraction).clamp(0.0, innerWidth);
    if (fillWidth > 0) {
      final fillRect = Rect.fromLTWH(
        innerLeft,
        innerTop,
        fillWidth,
        innerHeight,
      );
      final fillPaint = Paint()..color = fillColor;
      canvas.drawRect(fillRect, fillPaint);
    }
  }
}
