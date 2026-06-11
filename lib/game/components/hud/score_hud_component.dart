import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/game/badminton_game.dart';
import 'package:smash_bros/game/palette.dart';

// ---------------------------------------------------------------------------
// ScoreHudComponent — M1-026
//
// Top-centre viewport overlay displaying:
//   • The current score as '<left> – <right>' in large arcade text.
//   • A small serve-indicator triangle on the serving side of the score.
//   • A 'DEUCE' tag underneath when the match is in deuce.
//
// Position in tick order: reads only from game.view (RenderState snapshot);
// never touches the simulation. Re-renders each frame.
// ---------------------------------------------------------------------------

const double _kScoreFontSize = 72;
const double _kDeuceTagFontSize = 24;
const double _kServeIndicatorSize = 14; // half-base of the triangle
const double _kTopMargin = 12;

// Fixed horizontal offset from the score text centre to place the serve
// indicator. Approximates the half-width of two-digit score text plus margin.
const double _kServeIndicatorOffset = 90;

/// Top-centre HUD component that renders the current score, a serve indicator,
/// and a DEUCE tag.
///
/// Added to `camera.viewport` in [BadmintonGame.onLoad]; reads only
/// `game.view` each frame — never reaches into the simulation.
///
/// [safeArea] is in game units; the top inset is applied so the score clears
/// the device status bar. Updated via `BadmintonGame.safeArea` setter each
/// frame.
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
      color: GamePalette.courtLines,
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

    // -- Score text -----------------------------------------------------------
    final scoreText = '${v.leftScore}  –  ${v.rightScore}';
    _scorePaint.render(
      canvas,
      scoreText,
      Vector2(centreX, topY),
      anchor: Anchor.topCenter,
    );

    // -- Serve indicator (triangle) -------------------------------------------
    // The indicator is placed a fixed horizontal distance from the score
    // centre, on the serving side. This avoids per-frame text measurement
    // while clearly signalling which side is serving.
    final scoreTextMidY = topY + _kScoreFontSize / 2;

    if (v.server == CourtSide.left) {
      // Triangle tip points right (→), sitting to the left of the score.
      _drawServeTriangle(
        canvas,
        cx: centreX - _kServeIndicatorOffset,
        cy: scoreTextMidY,
        pointingRight: true,
      );
    } else {
      // Triangle tip points left (←), sitting to the right of the score.
      _drawServeTriangle(
        canvas,
        cx: centreX + _kServeIndicatorOffset,
        cy: scoreTextMidY,
        pointingRight: false,
      );
    }

    // -- DEUCE tag ------------------------------------------------------------
    if (v.isDeuce) {
      final deuceY = topY + _kScoreFontSize + 4;
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
      // Tip on the right side.
      path
        ..moveTo(cx + s, cy)
        ..lineTo(cx, cy - s)
        ..lineTo(cx, cy + s);
    } else {
      // Tip on the left side.
      path
        ..moveTo(cx - s, cy)
        ..lineTo(cx, cy - s)
        ..lineTo(cx, cy + s);
    }
    path.close();
    canvas.drawPath(path, paint);
  }
}
