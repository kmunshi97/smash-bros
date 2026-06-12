import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/game/badminton_game.dart';
import 'package:smash_bros/game/palette.dart';

// ---------------------------------------------------------------------------
// CourtComponent — M1-022
//
// Draws all static scenery: background, ground band, boundary lines, short-
// service line ticks, net body, and net tape. This component carries NO game
// logic and reads NO simulation state — it is pure presentation.
//
// Tick-order position: rendered first (lowest z-order) so all dynamic
// entities appear on top.
// ---------------------------------------------------------------------------

/// Static scenery component that draws the badminton court each frame.
///
/// Responsibilities (pure presentation — no game logic):
///  * Background fill behind the play area.
///  * Ground band from [kGroundY] to the bottom of the viewport.
///  * Vertical boundary ticks at [kCourtLeftBound] and [kCourtRightBound].
///  * Short-service line ticks at [kShortServeLineLeft] and
///    [kShortServeLineRight].
///  * Net body rectangle from ([kNetX] − 2, [kNetTopY] + [kNetTapeHeight])
///    down to [kGroundY].
///  * Net tape rectangle from ([kNetX] − 2, [kNetTopY]) spanning
///    [kNetTapeHeight] units tall.
///
/// [CourtComponent] holds no per-frame mutable state; its [render] override
/// is a sequence of [Canvas.drawRect] calls using compile-time [Paint]
/// objects derived from [GamePalette].
class CourtComponent extends Component with HasGameReference<BadmintonGame> {
  // Pre-built Paint objects — constructed once, reused every frame.
  static final _bgPaint = Paint()..color = GamePalette.background;
  static final _floorPaint = Paint()..color = GamePalette.courtFloor;
  static final _linePaint = Paint()..color = GamePalette.courtLines;
  static final _netBodyPaint = Paint()..color = GamePalette.netBody;
  static final _netTapePaint = Paint()..color = GamePalette.netTape;

  // Geometry constants derived from engine constants — resolved once.
  static const double _netHalfWidth = 2;
  static const double _lineTickHeight = 16;
  static const double _lineThickness = 2;

  @override
  void render(Canvas canvas) {
    // Draw all scenery layers in painter's order: background first, net last.
    canvas
      // 1. Background — full court rectangle.
      ..drawRect(
        const Rect.fromLTWH(0, 0, kCourtWidth, kCourtHeight),
        _bgPaint,
      )
      // 2. Ground band — from kGroundY to the bottom of the viewport.
      ..drawRect(
        const Rect.fromLTWH(
          0,
          kGroundY,
          kCourtWidth,
          kCourtHeight - kGroundY,
        ),
        _floorPaint,
      )
      // 3a. Left court boundary tick.
      ..drawRect(
        const Rect.fromLTWH(
          kCourtLeftBound - _lineThickness / 2,
          kGroundY - _lineTickHeight,
          _lineThickness,
          _lineTickHeight,
        ),
        _linePaint,
      )
      // 3b. Right court boundary tick.
      ..drawRect(
        const Rect.fromLTWH(
          kCourtRightBound - _lineThickness / 2,
          kGroundY - _lineTickHeight,
          _lineThickness,
          _lineTickHeight,
        ),
        _linePaint,
      )
      // 4a. Left short-service line tick.
      ..drawRect(
        const Rect.fromLTWH(
          kShortServeLineLeft - _lineThickness / 2,
          kGroundY - _lineTickHeight,
          _lineThickness,
          _lineTickHeight,
        ),
        _linePaint,
      )
      // 4b. Right short-service line tick.
      ..drawRect(
        const Rect.fromLTWH(
          kShortServeLineRight - _lineThickness / 2,
          kGroundY - _lineTickHeight,
          _lineThickness,
          _lineTickHeight,
        ),
        _linePaint,
      )
      // 5. Net body — from tape bottom to the ground.
      ..drawRect(
        const Rect.fromLTWH(
          kNetX - _netHalfWidth,
          kNetTopY + kNetTapeHeight,
          _netHalfWidth * 2,
          kGroundY - (kNetTopY + kNetTapeHeight),
        ),
        _netBodyPaint,
      )
      // 6. Net tape band — the bright strip at the top of the net.
      ..drawRect(
        const Rect.fromLTWH(
          kNetX - _netHalfWidth,
          kNetTopY,
          _netHalfWidth * 2,
          kNetTapeHeight,
        ),
        _netTapePaint,
      );
  }
}
