import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/game/badminton_game.dart';
import 'package:smash_bros/game/palette.dart';

// ---------------------------------------------------------------------------
// CourtComponent — M1-022 (reskinned M1-027)
//
// Draws the full stadium scenery in painter's order:
//   1. Sky gradient
//   2. Floodlight banks (top corners)
//   3. Grandstand tiers with crowd
//   4. Advertising strip
//   5. Arena field (play-space above ground)
//   6. Ground band (pitch with mowing stripes)
//   7. Court markings on the ground band
//   8. Dirt apron (controls zone)
//   9. Net (posts + mesh body + tape)
//
// dart:math is used here for Random crowd generation — the engine-purity rule
// covers lib/engine/ only; lib/game/ may use dart:math (CLAUDE.md § Architecture).
//
// Tick-order position: rendered first (lowest z-order) so all dynamic
// entities appear on top.
// ---------------------------------------------------------------------------

// Vertical layout constants (game-unit y coordinates).
// Ground is at kGroundY (600). Viewport height is kCourtHeight (720).
const double _kStandTop = 60; // top of grandstand area
const double _kStandMid = 180; // divider between upper/lower tier
const double _kStandBottom = 330; // bottom of grandstand (top of ad strip)
const double _kAdStripTop = 330;
const double _kAdStripBottom = 360;
const double _kArenaTop = 360; // top of play-air zone (below ad strip)
const double _kPitchBottom = kGroundY + 60; // bottom of pitch/ground band
// Dirt apron: _kPitchBottom → kCourtHeight (720)

// Crowd circle geometry.
const double _kCrowdRadius = 9;
const int _kCrowdSeed = 42; // fixed seed — crowd generated once in onLoad

// Floodlight geometry (game units).
const double _kFloodPanelW = 100;
const double _kFloodPanelH = 55;
const double _kFloodPanelTop = 5;
const double _kFloodLeftX = kCourtLeftBound;
const double _kFloodRightX = kCourtRightBound - _kFloodPanelW;
const int _kFloodCols = 4;
const int _kFloodRows = 3;

// Ad strip tile width.
const double _kAdTileW = 120;

// Mowing stripes on the ground band.
const int _kMowStripes = 8;

// Net geometry.
const double _kNetHalfWidth = 2;
const double _kNetPostW = 8;
const double _kNetPostH = kGroundY - kNetTopY;
const int _kNetMeshLines = 6; // faint horizontal lines across the mesh body

// Court line geometry on the ground band.
const double _kLineThickness = 2;
const double _kLineTickH = 16; // tick height above ground

/// A cached crowd dot: position + colour index.
class _CrowdDot {
  const _CrowdDot(this.x, this.y, this.colorIndex);
  final double x;
  final double y;
  final int colorIndex;
}

/// Static scenery component that draws the full cartoon stadium each frame.
///
/// Responsibilities (pure presentation — no game logic):
///  * All scenery layers in painter's order (sky, floodlights, stands, crowd,
///    ad strip, arena field, pitch, court lines, dirt apron, net).
///  * Crowd dots are generated once in [onLoad] with a fixed-seed
///    [math.Random] and cached; [render] only reads the cache.
///  * Net is drawn at the exact engine geometry ([kNetX], [kNetTopY],
///    [kNetTapeHeight]) restyled as dark posts + mesh + red/white tape.
class CourtComponent extends Component with HasGameReference<BadmintonGame> {
  // Cached crowd dots — generated once in onLoad.
  final List<_CrowdDot> _crowdDots = [];

  // -- Paints (built once) ---------------------------------------------------

  // Sky gradient paint is rebuilt in render() because ui.Gradient.linear
  // requires concrete Offset values; the rect is always the same for us.
  static final _floodPanelPaint = Paint()..color = GamePalette.floodlightPanel;
  static final _floodBulbPaint = Paint()..color = GamePalette.floodlightBulb;
  static final _standUpperPaint = Paint()..color = GamePalette.standUpperFill;
  static final _standLowerPaint = Paint()..color = GamePalette.standLowerFill;
  static final _standDividerPaint = Paint()..color = GamePalette.standDivider;
  static final _adBasePaint = Paint()..color = GamePalette.adStripBase;
  static final _adAltPaint = Paint()..color = GamePalette.adStripAlt;
  static final _arenaFieldPaint = Paint()..color = GamePalette.arenaField;
  static final _pitchBasePaint = Paint()..color = GamePalette.pitchBase;
  static final _pitchStripePaint = Paint()..color = GamePalette.pitchStripe;
  static final _linePaint = Paint()..color = GamePalette.courtLines;
  static final _dirtBasePaint = Paint()..color = GamePalette.dirtApronBase;
  static final _dirtDarkPaint = Paint()..color = GamePalette.dirtApronDark;
  static final _netPostPaint = Paint()..color = GamePalette.netPost;
  static final _netBodyPaint = Paint()..color = GamePalette.netBody;
  static final _netMeshPaint = Paint()
    ..color = GamePalette.netMesh
    ..strokeWidth = 0.7
    ..style = PaintingStyle.stroke;
  static final _netTapePaint = Paint()..color = GamePalette.netTape;

  // Crowd paints — one per crowdColors entry, built once.
  static final List<Paint> _crowdPaints = GamePalette.crowdColors
      .map((c) => Paint()..color = c)
      .toList();

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Generate crowd dots once with a FIXED seed so they are deterministic.
    // dart:math is allowed in lib/game/ — the engine-purity rule covers
    // lib/engine/ only (CLAUDE.md § Architecture rules).
    final rng = math.Random(_kCrowdSeed);

    // Upper tier crowd (rows within _kStandTop.._kStandMid).
    _generateCrowdTier(
      rng,
      topY: _kStandTop + 8,
      bottomY: _kStandMid - 8,
      leftX: kCourtLeftBound,
      rightX: kCourtRightBound,
    );
    // Lower tier crowd (rows within _kStandMid.._kStandBottom).
    _generateCrowdTier(
      rng,
      topY: _kStandMid + 8,
      bottomY: _kStandBottom - 8,
      leftX: kCourtLeftBound,
      rightX: kCourtRightBound,
    );
  }

  void _generateCrowdTier(
    math.Random rng, {
    required double topY,
    required double bottomY,
    required double leftX,
    required double rightX,
  }) {
    // Pack rows of crowd circles.
    final rowCount = ((bottomY - topY) / (_kCrowdRadius * 2.2)).floor();
    for (var row = 0; row < rowCount; row++) {
      final baseY = topY + row * (bottomY - topY) / rowCount + _kCrowdRadius;
      final y = baseY + rng.nextDouble() * 4 - 2; // slight y-jitter
      final colCount = ((rightX - leftX) / (_kCrowdRadius * 2.2)).floor();
      for (var col = 0; col < colCount; col++) {
        final x =
            leftX +
            col * (rightX - leftX) / colCount +
            _kCrowdRadius +
            rng.nextDouble() * 4 -
            2;
        final colorIdx = rng.nextInt(GamePalette.crowdColors.length);
        _crowdDots.add(_CrowdDot(x, y, colorIdx));
      }
    }
  }

  @override
  void render(Canvas canvas) {
    _drawSky(canvas);
    _drawFloodlights(canvas);
    _drawStands(canvas);
    _drawCrowd(canvas);
    _drawAdStrip(canvas);
    _drawArenaField(canvas);
    _drawPitch(canvas);
    _drawCourtLines(canvas);
    _drawDirtApron(canvas);
    _drawNet(canvas);
  }

  // 1. Sky — vertical linear gradient.
  void _drawSky(Canvas canvas) {
    const rect = Rect.fromLTWH(0, 0, kCourtWidth, _kStandTop);
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        const Offset(0, _kStandTop),
        [GamePalette.skyTop, GamePalette.skyBottom],
      );
    canvas.drawRect(rect, paint);
  }

  // 2. Floodlight banks — top corners.
  void _drawFloodlights(Canvas canvas) {
    _drawFloodPanel(canvas, _kFloodLeftX, _kFloodPanelTop);
    _drawFloodPanel(canvas, _kFloodRightX, _kFloodPanelTop);
  }

  void _drawFloodPanel(Canvas canvas, double panelX, double panelY) {
    // Dark rounded panel.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(panelX, panelY, _kFloodPanelW, _kFloodPanelH),
        const Radius.circular(6),
      ),
      _floodPanelPaint,
    );
    // 4×3 grid of bulb circles.
    const padX = 10;
    const padY = 8;
    const cellW = (_kFloodPanelW - 2 * padX) / _kFloodCols;
    const cellH = (_kFloodPanelH - 2 * padY) / _kFloodRows;
    for (var row = 0; row < _kFloodRows; row++) {
      for (var col = 0; col < _kFloodCols; col++) {
        final cx = panelX + padX + col * cellW + cellW / 2;
        final cy = panelY + padY + row * cellH + cellH / 2;
        canvas.drawCircle(Offset(cx, cy), 5.5, _floodBulbPaint);
      }
    }
  }

  // 3. Grandstand tiers.
  void _drawStands(Canvas canvas) {
    // Upper tier.
    canvas
      ..drawRect(
        const Rect.fromLTWH(
          0,
          _kStandTop,
          kCourtWidth,
          _kStandMid - _kStandTop,
        ),
        _standUpperPaint,
      )
      // Divider strip.
      ..drawRect(
        const Rect.fromLTWH(0, _kStandMid - 2, kCourtWidth, 4),
        _standDividerPaint,
      )
      // Lower tier.
      ..drawRect(
        const Rect.fromLTWH(
          0,
          _kStandMid,
          kCourtWidth,
          _kStandBottom - _kStandMid,
        ),
        _standLowerPaint,
      );
  }

  // 3b. Crowd — cached dots drawn on top of stands.
  void _drawCrowd(Canvas canvas) {
    for (final dot in _crowdDots) {
      canvas.drawCircle(
        Offset(dot.x, dot.y),
        _kCrowdRadius,
        _crowdPaints[dot.colorIndex],
      );
    }
  }

  // 4. Advertising strip.
  void _drawAdStrip(Canvas canvas) {
    const stripH = _kAdStripBottom - _kAdStripTop;
    final tileCount = (kCourtWidth / _kAdTileW).ceil();
    for (var i = 0; i < tileCount; i++) {
      final paint = i.isEven ? _adBasePaint : _adAltPaint;
      canvas.drawRect(
        Rect.fromLTWH(i * _kAdTileW, _kAdStripTop, _kAdTileW, stripH),
        paint,
      );
    }
  }

  // 5. Arena field — play-space above the ground band (keeps air readable).
  void _drawArenaField(Canvas canvas) {
    canvas.drawRect(
      const Rect.fromLTWH(0, _kArenaTop, kCourtWidth, kGroundY - _kArenaTop),
      _arenaFieldPaint,
    );
  }

  // 6. Ground band (pitch) — mowing stripes.
  void _drawPitch(Canvas canvas) {
    const pitchH = _kPitchBottom - kGroundY;
    const stripeW = kCourtWidth / _kMowStripes;
    for (var i = 0; i < _kMowStripes; i++) {
      final paint = i.isEven ? _pitchBasePaint : _pitchStripePaint;
      canvas.drawRect(
        Rect.fromLTWH(i * stripeW, kGroundY, stripeW, pitchH),
        paint,
      );
    }
  }

  // 7. Court markings (white lines on the ground band).
  void _drawCourtLines(Canvas canvas) {
    // Horizontal baseline at kGroundY — the ground boundary line.
    canvas
      ..drawRect(
        const Rect.fromLTWH(
          kCourtLeftBound,
          kGroundY,
          kCourtRightBound - kCourtLeftBound,
          _kLineThickness,
        ),
        _linePaint,
      )
      // Left boundary tick.
      ..drawRect(
        const Rect.fromLTWH(
          kCourtLeftBound - _kLineThickness / 2,
          kGroundY - _kLineTickH,
          _kLineThickness,
          _kLineTickH,
        ),
        _linePaint,
      )
      // Right boundary tick.
      ..drawRect(
        const Rect.fromLTWH(
          kCourtRightBound - _kLineThickness / 2,
          kGroundY - _kLineTickH,
          _kLineThickness,
          _kLineTickH,
        ),
        _linePaint,
      )
      // Left short-service line tick.
      ..drawRect(
        const Rect.fromLTWH(
          kShortServeLineLeft - _kLineThickness / 2,
          kGroundY - _kLineTickH,
          _kLineThickness,
          _kLineTickH,
        ),
        _linePaint,
      )
      // Right short-service line tick.
      ..drawRect(
        const Rect.fromLTWH(
          kShortServeLineRight - _kLineThickness / 2,
          kGroundY - _kLineTickH,
          _kLineThickness,
          _kLineTickH,
        ),
        _linePaint,
      )
      // Centre line tick (net position) on pitch.
      ..drawRect(
        const Rect.fromLTWH(
          kNetX - _kLineThickness / 2,
          kGroundY,
          _kLineThickness,
          _kPitchBottom - kGroundY,
        ),
        _linePaint,
      );
  }

  // 8. Dirt apron — below the pitch, controls zone.
  void _drawDirtApron(Canvas canvas) {
    const apronH = kCourtHeight - _kPitchBottom;
    canvas
      ..drawRect(
        const Rect.fromLTWH(0, _kPitchBottom, kCourtWidth, apronH),
        _dirtBasePaint,
      )
      // Darker strip at the very bottom for depth.
      ..drawRect(
        const Rect.fromLTWH(0, kCourtHeight - 12, kCourtWidth, 12),
        _dirtDarkPaint,
      );
  }

  // 9. Net — posts + mesh body + tape.
  void _drawNet(Canvas canvas) {
    // Net body (between tape bottom and ground).
    const bodyTop = kNetTopY + kNetTapeHeight;
    const bodyH = kGroundY - bodyTop;

    // Left post, right post, and body in one cascade.
    canvas
      ..drawRect(
        const Rect.fromLTWH(
          kNetX - _kNetHalfWidth - _kNetPostW,
          kNetTopY,
          _kNetPostW,
          _kNetPostH,
        ),
        _netPostPaint,
      )
      ..drawRect(
        const Rect.fromLTWH(
          kNetX + _kNetHalfWidth,
          kNetTopY,
          _kNetPostW,
          _kNetPostH,
        ),
        _netPostPaint,
      )
      ..drawRect(
        const Rect.fromLTWH(
          kNetX - _kNetHalfWidth,
          bodyTop,
          _kNetHalfWidth * 2,
          bodyH,
        ),
        _netBodyPaint,
      );

    // Faint horizontal mesh lines across the body.
    const lineSpacing = bodyH / (_kNetMeshLines + 1);
    for (var i = 1; i <= _kNetMeshLines; i++) {
      final y = bodyTop + i * lineSpacing;
      canvas.drawLine(
        Offset(kNetX - _kNetHalfWidth, y),
        Offset(kNetX + _kNetHalfWidth, y),
        _netMeshPaint,
      );
    }

    // Net tape (bright red band at the top — spans posts + body).
    canvas.drawRect(
      const Rect.fromLTWH(
        kNetX - _kNetHalfWidth - _kNetPostW,
        kNetTopY,
        _kNetHalfWidth * 2 + _kNetPostW * 2,
        kNetTapeHeight,
      ),
      _netTapePaint,
    );
  }
}
