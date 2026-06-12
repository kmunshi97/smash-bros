import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/game/badminton_game.dart';
import 'package:smash_bros/game/palette.dart';

// ---------------------------------------------------------------------------
// CourtComponent — M1-022 (reskinned M1-027, depth pass M1-035v)
//
// Draws the full stadium scenery in painter's order:
//   1. Sky gradient
//   2. Floodlight banks (top corners)
//   3. Grandstand tiers with crowd
//   4. Advertising strip
//   5. Arena field (play-space above ground)
//   6. Perspective trapezoid court surface with court markings
//   7. Dirt apron (controls zone) below the trapezoid
//   8. Net (visible posts + mesh body + bright red/white tape band)
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
const double _kPitchBottom = kGroundY + 60; // bottom of trapezoid court
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

// Perspective trapezoid: the top edge follows court bounds exactly; the bottom
// edge spreads outward by this amount on each side (vanishing-point illusion).
const double _kPerspectiveSpread = 70;

// Court line geometry on the trapezoid.
const double _kLineThickness = 2;
const double _kLineTickH = 16; // tick height above ground (on trapezoid)

// Net geometry — widened posts and clearer mesh for readability.
const double _kNetPostW = 6; // full post width (game units)
const double _kNetPostH = kGroundY - kNetTopY;
const double _kNetPostCapR = 5; // round cap radius on top of each post
// Post centre X positions — each post stands adjacent to net centre.
const double _kLeftPostCX = kNetX - _kNetPostW;
const double _kRightPostCX = kNetX + _kNetPostW;
// Mesh body spans between the inner post edges.
const double _kMeshLeft = _kLeftPostCX + _kNetPostW / 2;
const double _kMeshRight = _kRightPostCX - _kNetPostW / 2;
const double _kMeshWidth = _kMeshRight - _kMeshLeft;
// Tape band spans post outer edges.
const double _kTapeLeft = _kLeftPostCX - _kNetPostW / 2;
const double _kTapeRight = _kRightPostCX + _kNetPostW / 2;
const double _kTapeWidth = _kTapeRight - _kTapeLeft;
const int _kNetMeshLines = 5; // mesh lines in the body

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
///    ad strip, arena field, perspective court surface, dirt apron, net).
///  * Court surface is drawn as a perspective trapezoid whose top edge follows
///    the court bounds and bottom edge spreads outward (depth cue).
///  * Crowd dots are generated once in [onLoad] with a fixed-seed
///    [math.Random] and cached; [render] only reads the cache.
///  * Net is drawn with dark posts + round caps + translucent mesh body +
///    BRIGHT red/white tape band so it is always readable.
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
  static final _netBodyPaint = Paint()
    ..color = GamePalette.netBody.withValues(alpha: 0.55);
  static final _netMeshPaint = Paint()
    ..color = GamePalette.netMesh.withValues(alpha: 0.55)
    ..strokeWidth = 1
    ..style = PaintingStyle.stroke;
  static final _netTapeRedPaint = Paint()..color = GamePalette.netTape;
  static final _netTapeWhitePaint = Paint()..color = const Color(0xFFFFFFFF);

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
    _drawPerspectiveCourt(canvas);
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

  // 6. Perspective trapezoid court surface + court markings.
  //
  // Top edge: y=kGroundY, x from kCourtLeftBound to kCourtRightBound.
  // Bottom edge: y=_kPitchBottom, x spreads outward by _kPerspectiveSpread.
  // The slanted side edges create a vanishing-point illusion toward the top.
  void _drawPerspectiveCourt(Canvas canvas) {
    const topLeft = Offset(kCourtLeftBound, kGroundY);
    const topRight = Offset(kCourtRightBound, kGroundY);
    const bottomLeft = Offset(
      kCourtLeftBound - _kPerspectiveSpread,
      _kPitchBottom,
    );
    const bottomRight = Offset(
      kCourtRightBound + _kPerspectiveSpread,
      _kPitchBottom,
    );

    // --- Trapezoid fill with mowing stripes ---
    // Clip the canvas to the trapezoid path, paint the stripes, then restore.
    final trapPath = Path()
      ..moveTo(topLeft.dx, topLeft.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy)
      ..lineTo(bottomLeft.dx, bottomLeft.dy)
      ..close();

    canvas
      ..save()
      ..clipPath(trapPath);

    // Mowing stripes across the full extended bottom width.
    const stripeCount = 10;
    const totalBottom =
        (kCourtRightBound + _kPerspectiveSpread) -
        (kCourtLeftBound - _kPerspectiveSpread);
    const stripeW = totalBottom / stripeCount;
    const startX = kCourtLeftBound - _kPerspectiveSpread;
    for (var i = 0; i < stripeCount; i++) {
      final paint = i.isEven ? _pitchBasePaint : _pitchStripePaint;
      canvas.drawRect(
        Rect.fromLTWH(
          startX + i * stripeW,
          kGroundY,
          stripeW,
          _kPitchBottom - kGroundY,
        ),
        paint,
      );
    }

    canvas.restore();

    // --- Boundary lines: slanted side edges of the trapezoid ---
    final sidePaint = Paint()
      ..color = GamePalette.courtLines
      ..strokeWidth = _kLineThickness
      ..style = PaintingStyle.stroke;
    canvas
      ..drawLine(topLeft, bottomLeft, sidePaint)
      ..drawLine(topRight, bottomRight, sidePaint)
      // --- Horizontal baseline at kGroundY ---
      ..drawRect(
        const Rect.fromLTWH(
          kCourtLeftBound,
          kGroundY,
          kCourtRightBound - kCourtLeftBound,
          _kLineThickness,
        ),
        _linePaint,
      )
      // --- Short-service line ticks (vertical, rising from kGroundY) ---
      ..drawRect(
        const Rect.fromLTWH(
          kShortServeLineLeft - _kLineThickness / 2,
          kGroundY - _kLineTickH,
          _kLineThickness,
          _kLineTickH,
        ),
        _linePaint,
      )
      ..drawRect(
        const Rect.fromLTWH(
          kShortServeLineRight - _kLineThickness / 2,
          kGroundY - _kLineTickH,
          _kLineThickness,
          _kLineTickH,
        ),
        _linePaint,
      )
      // --- Centre line under the net (full trapezoid height) ---
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

  // 7. Dirt apron — below the trapezoid, controls zone.
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

  // 8. Net — dark posts with round caps + translucent mesh body + bright tape.
  //
  // Posts reach from kGroundY up to kNetTopY (sitting ON the trapezoid floor).
  // Tape is drawn across post outer edges in alternating red/white for pop.
  void _drawNet(Canvas canvas) {
    // --- Posts (left and right) ---
    canvas
      ..drawRect(
        const Rect.fromLTWH(
          _kLeftPostCX - _kNetPostW / 2,
          kNetTopY,
          _kNetPostW,
          _kNetPostH,
        ),
        _netPostPaint,
      )
      ..drawCircle(
        const Offset(_kLeftPostCX, kNetTopY),
        _kNetPostCapR,
        _netPostPaint,
      )
      ..drawRect(
        const Rect.fromLTWH(
          _kRightPostCX - _kNetPostW / 2,
          kNetTopY,
          _kNetPostW,
          _kNetPostH,
        ),
        _netPostPaint,
      )
      ..drawCircle(
        const Offset(_kRightPostCX, kNetTopY),
        _kNetPostCapR,
        _netPostPaint,
      );

    // --- Mesh body between inner post edges ---
    const meshBodyTop = kNetTopY + kNetTapeHeight;
    const meshBodyH = kGroundY - meshBodyTop;

    canvas.drawRect(
      const Rect.fromLTWH(_kMeshLeft, meshBodyTop, _kMeshWidth, meshBodyH),
      _netBodyPaint,
    );

    // Diagonal cross-hatch mesh lines.
    const lineSpacingX = _kMeshWidth / (_kNetMeshLines + 1);
    for (var i = 0; i <= _kNetMeshLines; i++) {
      final x0 = _kMeshLeft + i * lineSpacingX;
      canvas
        ..drawLine(
          Offset(x0, meshBodyTop),
          Offset(x0 + lineSpacingX, meshBodyTop + meshBodyH),
          _netMeshPaint,
        )
        ..drawLine(
          Offset(x0 + lineSpacingX, meshBodyTop),
          Offset(x0, meshBodyTop + meshBodyH),
          _netMeshPaint,
        );
    }

    // --- Bright tape band — alternating red/white for high visibility ---
    const sectionCount = 5;
    const sectionW = _kTapeWidth / sectionCount;
    for (var i = 0; i < sectionCount; i++) {
      final paint = i.isEven ? _netTapeRedPaint : _netTapeWhitePaint;
      canvas.drawRect(
        Rect.fromLTWH(
          _kTapeLeft + i * sectionW,
          kNetTopY,
          sectionW,
          kNetTapeHeight,
        ),
        paint,
      );
    }
  }
}
