import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/game/badminton_game.dart';
import 'package:smash_bros/game/palette.dart';

// ---------------------------------------------------------------------------
// ScoreHudComponent — M1-026 (reskinned M1-027, sprite scoreboard M1-023c)
//
// The scoreboard panel is now part of the stadium_bg.png background asset;
// this component only paints INTO the asset's scoreboard displays:
//   • The two score digits, positioned over the asset's display windows.
//   • A small serve-indicator triangle on the serving side of the score.
//   • A 'DEUCE' tag underneath the scoreboard when the match is in deuce.
//
// The digit anchor coordinates below are measured from stadium_bg.png at its
// native 1280×720 layout — if the asset is redrawn, re-measure them.
//
// Behaviour / game logic are UNCHANGED from M1-026.
// Position in tick order: reads only from game.view (RenderState snapshot);
// never touches the simulation. Re-renders each frame.
// ---------------------------------------------------------------------------

const double _kDeuceTagFontSize = 22;
const double _kServeIndicatorSize = 12; // half-base of the triangle

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

  static final _scoreLeftPaint = TextPaint(
    style: const TextStyle(
      fontSize: 54,
      fontWeight: FontWeight.bold,
      color: GamePalette.scoreDigit,
    ),
  );

  static final _scoreRightPaint = TextPaint(
    style: const TextStyle(
      fontSize: 54,
      fontWeight: FontWeight.bold,
      color: GamePalette.buttonPressed,
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

    // Centre coordinates measured from the scoreboard displays baked into
    // stadium_bg.png at its native 1280×720 layout.
    const leftX = 522.25;
    const rightX = 755.9;
    const scoreY = 124.79;

    // Render left score digit (green)
    _scoreLeftPaint.render(
      canvas,
      '${v.leftScore}',
      Vector2(leftX, scoreY),
      anchor: Anchor.center,
    );

    // Render right score digit (orange/gold)
    _scoreRightPaint.render(
      canvas,
      '${v.rightScore}',
      Vector2(rightX, scoreY),
      anchor: Anchor.center,
    );

    // Render serve indicator next to the active server's score digit
    if (v.server == CourtSide.left) {
      _drawServeTriangle(
        canvas,
        cx: leftX - 38,
        cy: scoreY,
        pointingRight: true,
      );
    } else {
      _drawServeTriangle(
        canvas,
        cx: rightX + 38,
        cy: scoreY,
        pointingRight: false,
      );
    }

    // Render DEUCE tag centered below the scoreboard
    if (v.isDeuce) {
      const deuceX = 640.0;
      const deuceY = 185.0;
      _deucePaint.render(
        canvas,
        'DEUCE',
        Vector2(deuceX, deuceY),
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
