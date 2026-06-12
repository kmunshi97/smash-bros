import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/rules/match_phase.dart';
import 'package:smash_bros/game/badminton_game.dart';
import 'package:smash_bros/game/palette.dart';

// ---------------------------------------------------------------------------
// PhaseBannerComponent — M1-026
//
// Centre-screen banner shown only in specific match phases:
//
//   pointScored  → 'POINT — LEFT' or 'POINT — RIGHT'
//                  + smaller second line: camelCase reason → spaced upper-case
//   matchOver    → 'MATCH OVER — LEFT WINS' or 'MATCH OVER — RIGHT WINS'
//
// In all other phases (preMatch, servePending, inPlay) the component renders
// nothing.
//
// Position in tick order: reads only from game.view (RenderState snapshot);
// never touches the simulation.
// ---------------------------------------------------------------------------

const double _kBannerFontSize = 60;
const double _kSublineFontSize = 26;
const double _kBannerBgAlpha = 0.55;

/// Centre-screen phase banner, visible only in [MatchPhase.pointScored] and
/// [MatchPhase.matchOver].
///
/// Added to `camera.viewport` in [BadmintonGame.onLoad]; reads only
/// `game.view` each frame. Renders nothing in all other phases.
class PhaseBannerComponent extends PositionComponent
    with HasGameReference<BadmintonGame> {
  static final _titlePaint = TextPaint(
    style: const TextStyle(
      fontSize: _kBannerFontSize,
      fontWeight: FontWeight.bold,
      color: GamePalette.courtLines,
      letterSpacing: 2,
    ),
  );

  static final _sublinePaint = TextPaint(
    style: const TextStyle(
      fontSize: _kSublineFontSize,
      fontWeight: FontWeight.w400,
      color: GamePalette.courtLines,
      letterSpacing: 1.5,
    ),
  );

  @override
  void render(Canvas canvas) {
    final v = game.view;

    final String? title;
    final String? subline;

    switch (v.phase) {
      case MatchPhase.pointScored:
        final side = v.pointWinner == CourtSide.left ? 'LEFT' : 'RIGHT';
        title = 'POINT — $side';
        final reason = v.lastPointReason;
        subline = reason != null ? _camelToUpperSpaced(reason.name) : null;

      case MatchPhase.matchOver:
        // pointWinner holds the last point scorer, who is also the match winner
        // because MatchFsm only transitions to matchOver after a winning point
        // (scoreboard.winner != null at that moment). Confirmed in match_fsm.dart
        // tickPointPause: if (gameWinner != null) _transition(matchOver).
        final side = v.pointWinner == CourtSide.left ? 'LEFT' : 'RIGHT';
        title = 'MATCH OVER — $side WINS';
        subline = 'TAP TO RESTART';

      case MatchPhase.preMatch:
      case MatchPhase.servePending:
      case MatchPhase.inPlay:
        // No banner in these phases.
        return;
    }

    final viewportSize = game.camera.viewport.size;
    final centreX = viewportSize.x / 2;
    final centreY = viewportSize.y / 2;

    // -- Semi-transparent backdrop --------------------------------------------
    // Use Flame's toTextPainter to measure the title string width so the
    // backdrop scales with the longest possible banner text.
    final titleWidth = _titlePaint.toTextPainter(title).width;
    final bgWidth = titleWidth + 40;
    final bgHeight = subline != null
        ? _kBannerFontSize + _kSublineFontSize + 28
        : _kBannerFontSize + 20;
    final bgLeft = centreX - bgWidth / 2;
    final bgTop = centreY - bgHeight / 2;

    final bgPaint = Paint()
      ..color = GamePalette.background.withAlpha(
        (_kBannerBgAlpha * 255).round(),
      );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bgLeft, bgTop, bgWidth, bgHeight),
        const Radius.circular(8),
      ),
      bgPaint,
    );

    // -- Title line -----------------------------------------------------------
    final titleY = subline != null
        ? centreY - _kSublineFontSize / 2 - 6
        : centreY;
    _titlePaint.render(
      canvas,
      title,
      Vector2(centreX, titleY),
      anchor: Anchor.center,
    );

    // -- Sub-line (point reason) ----------------------------------------------
    if (subline != null) {
      final subY = titleY + _kBannerFontSize / 2 + _kSublineFontSize / 2 + 4;
      _sublinePaint.render(
        canvas,
        subline,
        Vector2(centreX, subY),
        anchor: Anchor.center,
      );
    }
  }

  /// Converts a camelCase identifier to spaced upper-case.
  ///
  /// Examples:
  ///   'groundedIn'        → 'GROUNDED IN'
  ///   'serveTimeoutFault' → 'SERVE TIMEOUT FAULT'
  String _camelToUpperSpaced(String camel) {
    // Insert a space before each upper-case letter, then upper-case everything.
    final spaced = camel.replaceAllMapped(
      RegExp('(?<=[a-z])(?=[A-Z])'),
      (m) => ' ',
    );
    return spaced.toUpperCase();
  }
}
