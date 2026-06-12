import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/game/badminton_game.dart';
import 'package:smash_bros/game/palette.dart';

// ---------------------------------------------------------------------------
// StaminaBarComponent — M1-026 (reskinned M1-027)
//
// A 220×18 game-unit stamina bar anchored to the top-left (CourtSide.left)
// or top-right (CourtSide.right) of the viewport.
//
// Visual changes in M1-027:
//   • Dark panel background with thin gold outline (matching button style).
//   • Rounded rect border.
//
// Mechanics (fill fraction, colour thresholds) are UNCHANGED from M1-026.
// Position in tick order: reads only from game.view (RenderState snapshot);
// never touches the simulation.
// ---------------------------------------------------------------------------

const double _kBarWidth = 220;
const double _kBarHeight = 18;
const double _kBorder = 2;
const double _kEdgeMargin = 12;
const double _kTopMargin = 12;
const double _kBarCorner = 4;

/// A per-side stamina bar rendered in the top-left or top-right corner of the
/// HUD viewport.
///
/// Added to `camera.viewport` in [BadmintonGame.onLoad]; reads only
/// `game.view` each frame.
///
/// [safeArea] is in game units; the top and left/right insets clear the device
/// status bar and notch.
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

    // Anchored against the VIRTUAL resolution (kCourtWidth) — viewport
    // children render in virtual coordinates, not device coordinates.
    final topY = _kTopMargin + safeArea.top;
    final leftX = side == CourtSide.left
        ? _kEdgeMargin + safeArea.left
        : kCourtWidth - _kEdgeMargin - safeArea.right - _kBarWidth;

    const outerWidth = _kBarWidth;
    const outerHeight = _kBarHeight;
    final outerRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(leftX, topY, outerWidth, outerHeight),
      const Radius.circular(_kBarCorner),
    );

    // -- Background (dark recessed panel) -------------------------------------
    final bgPaint = Paint()..color = GamePalette.staminaBarBackground;
    canvas.drawRRect(outerRRect, bgPaint);

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
      final fillRRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(innerLeft, innerTop, fillWidth, innerHeight),
        const Radius.circular(_kBarCorner - _kBorder),
      );
      final fillPaint = Paint()..color = fillColor;
      canvas.drawRRect(fillRRect, fillPaint);
    }

    // -- Gold outline (thin border) -------------------------------------------
    final borderPaint = Paint()
      ..color = GamePalette.staminaBarBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = _kBorder;
    canvas.drawRRect(outerRRect, borderPaint);
  }
}
