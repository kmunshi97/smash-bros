import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/game/badminton_game.dart';
import 'package:smash_bros/game/palette.dart';

// ---------------------------------------------------------------------------
// ScoreHudComponent — M1-026 (reskinned M1-027)
//
// Top-centre viewport overlay displaying:
//   • A dark rounded scoreboard panel with 'YOU' / 'CPU' labels and the two
//     scores as large LED-green bold digits in dark-inset slots.
//   • A small serve-indicator triangle on the serving side of the score.
//   • A 'DEUCE' tag underneath when the match is in deuce.
//
// Behaviour / game logic are UNCHANGED from M1-026.
// Position in tick order: reads only from game.view (RenderState snapshot);
// never touches the simulation. Re-renders each frame.
// ---------------------------------------------------------------------------

const double _kScoreFontSize = 58;
const double _kLabelFontSize = 16;
const double _kDeuceTagFontSize = 22;
const double _kServeIndicatorSize = 12; // half-base of the triangle
const double _kTopMargin = 8;

// Panel geometry.
const double _kPanelW = 320;
const double _kPanelH = 68;
const double _kPanelCorner = 12;
const double _kWingW = 20; // side wings on panel
// Inset slot for each score digit (left and right halves of the panel).
const double _kSlotW = 90;
const double _kSlotH = 46;
const double _kSlotCorner = 6;
const double _kSlotVertPad = 10; // from panel top
const double _kSlotHorizPad = 18; // inward from left/right panel edges
// Serve indicator: horizontal distance from panel centre to indicator tip.
const double _kServeIndicatorHorizOffset = 158;

/// Top-centre HUD component that renders the scoreboard with dark panel,
/// LED-green digits, serve indicator, and optional DEUCE tag.
///
/// Added to `camera.viewport` in [BadmintonGame.onLoad]; reads only
/// `game.view` each frame — never reaches into the simulation.
///
/// [safeArea] is in game units; the top inset is applied so the score clears
/// the device status bar.
class ScoreHudComponent extends PositionComponent
    with HasGameReference<BadmintonGame> {
  /// Creates the score HUD, initially offset by [safeArea].
  ScoreHudComponent({required this.safeArea});

  /// Safe-area padding in game units; top inset clears the device status bar.
  ///
  /// Updated by [BadmintonGame] whenever the device insets change.
  EdgeInsets safeArea;

  static final _scorePaint = TextPaint(
    style: const TextStyle(
      fontSize: _kScoreFontSize,
      fontWeight: FontWeight.bold,
      color: GamePalette.scoreDigit,
    ),
  );

  static final _labelPaint = TextPaint(
    style: const TextStyle(
      fontSize: _kLabelFontSize,
      fontWeight: FontWeight.w600,
      color: GamePalette.scoreLabel,
      letterSpacing: 1,
    ),
  );

  static final _deucePaint = TextPaint(
    style: const TextStyle(
      fontSize: _kDeuceTagFontSize,
      fontWeight: FontWeight.bold,
      color: GamePalette.serveAccent,
      letterSpacing: 3,
    ),
  );

  @override
  void render(Canvas canvas) {
    final v = game.view;
    final viewportSize = game.camera.viewport.size;
    final topY = _kTopMargin + safeArea.top;
    final centreX = viewportSize.x / 2;

    // -- Panel background -----------------------------------------------------
    final panelLeft = centreX - _kPanelW / 2;
    final panelRect = Rect.fromLTWH(panelLeft, topY, _kPanelW, _kPanelH);

    // Wing extensions on left and right.
    final wingPaint = Paint()..color = GamePalette.scorePanelAccent;
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            panelLeft - _kWingW,
            topY + 12,
            _kWingW,
            _kPanelH - 24,
          ),
          const Radius.circular(4),
        ),
        wingPaint,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            panelLeft + _kPanelW,
            topY + 12,
            _kWingW,
            _kPanelH - 24,
          ),
          const Radius.circular(4),
        ),
        wingPaint,
      );

    // Main panel.
    final panelPaint = Paint()..color = GamePalette.scoreboardPanel;
    canvas.drawRRect(
      RRect.fromRectAndRadius(panelRect, const Radius.circular(_kPanelCorner)),
      panelPaint,
    );

    // -- Digit inset slots ----------------------------------------------------
    final slotTop = topY + _kSlotVertPad;
    final leftSlotRect = Rect.fromLTWH(
      panelLeft + _kSlotHorizPad,
      slotTop,
      _kSlotW,
      _kSlotH,
    );
    final rightSlotRect = Rect.fromLTWH(
      panelLeft + _kPanelW - _kSlotHorizPad - _kSlotW,
      slotTop,
      _kSlotW,
      _kSlotH,
    );
    final slotPaint = Paint()..color = GamePalette.scoreDigitInset;
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          leftSlotRect,
          const Radius.circular(_kSlotCorner),
        ),
        slotPaint,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          rightSlotRect,
          const Radius.circular(_kSlotCorner),
        ),
        slotPaint,
      );

    // -- 'YOU' / 'CPU' labels (above digit slots) ----------------------------
    _labelPaint
      ..render(
        canvas,
        'YOU',
        Vector2(leftSlotRect.center.dx, topY + 3),
        anchor: Anchor.topCenter,
      )
      ..render(
        canvas,
        'CPU',
        Vector2(rightSlotRect.center.dx, topY + 3),
        anchor: Anchor.topCenter,
      );

    // -- Score digits ---------------------------------------------------------
    final scoreY = slotTop + _kSlotH / 2 - 4;
    _scorePaint
      ..render(
        canvas,
        '${v.leftScore}',
        Vector2(leftSlotRect.center.dx, scoreY),
        anchor: Anchor.center,
      )
      ..render(
        canvas,
        '${v.rightScore}',
        Vector2(rightSlotRect.center.dx, scoreY),
        anchor: Anchor.center,
      );

    // -- Separator dash -------------------------------------------------------
    final dashPaint = Paint()
      ..color = GamePalette.scoreLabel
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(centreX - 6, topY + _kPanelH / 2),
      Offset(centreX + 6, topY + _kPanelH / 2),
      dashPaint,
    );

    // -- Serve indicator (triangle) -------------------------------------------
    final scoreTextMidY = topY + _kPanelH / 2;

    if (v.server == CourtSide.left) {
      _drawServeTriangle(
        canvas,
        cx: centreX - _kServeIndicatorHorizOffset,
        cy: scoreTextMidY,
        pointingRight: true,
      );
    } else {
      _drawServeTriangle(
        canvas,
        cx: centreX + _kServeIndicatorHorizOffset,
        cy: scoreTextMidY,
        pointingRight: false,
      );
    }

    // -- DEUCE tag ------------------------------------------------------------
    if (v.isDeuce) {
      final deuceY = topY + _kPanelH + 4;
      _deucePaint.render(
        canvas,
        'DEUCE',
        Vector2(centreX, deuceY),
        anchor: Anchor.topCenter,
      );
    }
  }

  /// Draws a filled triangle serving as the serve indicator.
  ///
  /// [cx] and [cy] are the tip coordinates. [pointingRight] means the tip
  /// points right (left server); otherwise the tip points left (right server).
  void _drawServeTriangle(
    Canvas canvas, {
    required double cx,
    required double cy,
    required bool pointingRight,
  }) {
    final paint = Paint()..color = GamePalette.serveAccent;
    final path = Path();
    const s = _kServeIndicatorSize;
    if (pointingRight) {
      path
        ..moveTo(cx + s, cy)
        ..lineTo(cx, cy - s)
        ..lineTo(cx, cy + s);
    } else {
      path
        ..moveTo(cx - s, cy)
        ..lineTo(cx, cy - s)
        ..lineTo(cx, cy + s);
    }
    path.close();
    canvas.drawPath(path, paint);
  }
}
