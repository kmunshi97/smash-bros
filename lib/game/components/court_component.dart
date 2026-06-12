import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/game/badminton_game.dart';
import 'package:smash_bros/game/palette.dart';

// ---------------------------------------------------------------------------
// CourtComponent — M1-022 (reskinned M1-027, depth pass M1-035v,
//                           stadium restyle)
//
// Draws the full stadium scenery in painter's order:
//   1. Sky strip (bright daylight blue behind the roof)
//   2. Roof (fascia band + underside shadow)
//   3. Grandstand tiers (upper + lower) with corner wedge sections
//      and alternating seat-block colour banks
//   4. Crowd dots (layered on top of stands)
//   5. Ad wall (cream perimeter board with dark nav text blocks +
//      base shadow line)
//   6. Grass pitch — full viewport width from the wall base (y≈385) to
//      the screen bottom (y=720); alternating light/dark mow bands that
//      COMPRESS WITH DISTANCE via a geometric perspective progression
//   7. Perspective pitch-boundary lines (back boundary + side rails
//      converging to a vanishing point; short-service ticks; centre line)
//   8. Net (posts + mesh body + bright red/white tape band)
//
// dart:math is used here for Random crowd generation — the engine-purity rule
// covers lib/engine/ only; lib/game/ may use dart:math (CLAUDE.md § Architecture).
//
// Tick-order position: rendered first (lowest z-order) so all dynamic
// entities appear on top.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Vertical layout constants (game-unit y coordinates).
// ---------------------------------------------------------------------------

/// Bottom y of the sky strip and top of the roof fascia visible region.
const double _kSkyBottom = 70;

/// Top y of the roof fascia face.
const double _kRoofFasciaTop = 55;

/// Bottom y of the roof fascia face / top of the underside shadow.
const double _kRoofFasciaBottom = 95;

/// Bottom y of the roof underside shadow.
const double _kRoofUndersideBottom = 115;

/// Top of the grandstand tiers (just below the roof underside).
const double _kStandTop = 105;

/// Divider between upper and lower grandstand tiers.
const double _kStandMid = 215;

/// Bottom of the grandstand / top of the ad wall.
const double _kStandBottom = 330;

/// Top and bottom of the perimeter ad wall.
const double _kAdWallTop = 330;
const double _kAdWallBottom = 385;

/// Y coordinate where the grass begins (top of the pitch area).
const double _kGrassTop = _kAdWallBottom;

// Ground is at kGroundY (600). Viewport bottom is kCourtHeight (720).

// ---------------------------------------------------------------------------
// Perspective / vanishing-point geometry.
//
// The pitch side lines MUST pass through:
//   left corner:  (kCourtLeftBound,  kGroundY) = (40,  600)
//   right corner: (kCourtRightBound, kGroundY) = (1240, 600)
//
// Vanishing point chosen at (kNetX, _kVanishY) = (640, 250).
// The back-boundary x positions at y=_kAdWallBottom are derived by
// projecting the side-line rays backward from ground-corners to the wall.
// ---------------------------------------------------------------------------

/// Y coordinate of the vanishing point behind the ad wall.
const double _kVanishY = 250;

// The side-line rays: left ray through (kNetX/_kVanishY, leftGround) and
// right ray through (kNetX/_kVanishY, rightGround).
//
// At any y, the x on the left ray:
//   xLeft(y)  = kNetX + (kCourtLeftBound  - kNetX) * (y - _kVanishY)
//                                                    / (kGroundY   - _kVanishY)
//
// Back-boundary x at y = _kAdWallBottom (= 385):
const double _kBackBoundaryLeft =
    kNetX +
    (kCourtLeftBound - kNetX) *
        (_kAdWallBottom - _kVanishY) /
        (kGroundY - _kVanishY);

const double _kBackBoundaryRight =
    kNetX +
    (kCourtRightBound - kNetX) *
        (_kAdWallBottom - _kVanishY) /
        (kGroundY - _kVanishY);

// Side lines also continue below kGroundY to the screen bottom (720).
const double _kFrontBoundaryLeft =
    kNetX +
    (kCourtLeftBound - kNetX) *
        (kCourtHeight - _kVanishY) /
        (kGroundY - _kVanishY);

const double _kFrontBoundaryRight =
    kNetX +
    (kCourtRightBound - kNetX) *
        (kCourtHeight - _kVanishY) /
        (kGroundY - _kVanishY);

// ---------------------------------------------------------------------------
// Mow band geometry — geometric progression so bands compress with distance.
//
// We lay bands from _kGrassTop (far) down to kCourtHeight (near).
// The ratio r between successive band heights produces the perspective effect.
// Total height = _kGrassTop .. kCourtHeight = 335 units (720 - 385).
// We use 12 bands with a common ratio so the first band (at the top, farthest
// from viewer) is ~12 units and the last (nearest) is ~50 units.
// ---------------------------------------------------------------------------

/// Number of mow bands across the full pitch height.
const int _kMowBandCount = 12;

/// Geometric ratio between adjacent mow-band heights (>1 = gets taller near viewer).
const double _kMowBandRatio = 1.185;

// ---------------------------------------------------------------------------
// Court line geometry.
// ---------------------------------------------------------------------------

const double _kLineThickness = 2;

/// Short-service tick height rising from kGroundY toward the sky.
const double _kLineTickH = 18;

// ---------------------------------------------------------------------------
// Crowd geometry.
// ---------------------------------------------------------------------------
const double _kCrowdRadius = 5;
const int _kCrowdSeed = 42;

/// Fraction of seats left empty so the seat-bank colours show through and the
/// crowd reads as people-in-seats rather than a solid confetti field.
const double _kCrowdEmptySeatChance = 0.38;

/// Horizontal/vertical packing factor between crowd dots (× dot diameter).
const double _kCrowdSpacing = 3.1;

// ---------------------------------------------------------------------------
// Net geometry — unchanged from previous version.
// ---------------------------------------------------------------------------
const double _kNetPostW = 6;
const double _kNetPostH = kGroundY - kNetTopY;
const double _kNetPostCapR = 5;
const double _kLeftPostCX = kNetX - _kNetPostW;
const double _kRightPostCX = kNetX + _kNetPostW;
const double _kMeshLeft = _kLeftPostCX + _kNetPostW / 2;
const double _kMeshRight = _kRightPostCX - _kNetPostW / 2;
const double _kMeshWidth = _kMeshRight - _kMeshLeft;
const double _kTapeLeft = _kLeftPostCX - _kNetPostW / 2;
const double _kTapeRight = _kRightPostCX + _kNetPostW / 2;
const double _kTapeWidth = _kTapeRight - _kTapeLeft;
const int _kNetMeshLines = 5;

// ---------------------------------------------------------------------------
// Ad wall text geometry.
// ---------------------------------------------------------------------------

/// Fictional sponsor copy repeated along the perimeter ad wall.
const String _kAdText = 'SMASH BROS';

/// Horizontal spacing between the centres of repeated ad-text instances.
const double _kAdTextSpacing = 320;

// ---------------------------------------------------------------------------
// Corner wedge geometry.
// ---------------------------------------------------------------------------

/// Width of the diagonal corner section on each side of the stands.
const double _kCornerWedgeW = 140;

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
///  * All scenery layers in painter's order (sky, roof, stands, crowd, ad
///    wall, grass pitch with perspective bands, perspective boundary lines,
///    net).
///  * Grass uses a geometric progression of mow-band heights that
///    compress with distance, creating a realistic top-down perspective.
///  * Perspective side lines pass exactly through [kCourtLeftBound]/
///    [kCourtRightBound] at [kGroundY] and converge to a vanishing point
///    at ([kNetX], [_kVanishY]).
///  * Crowd dots are generated once in [onLoad] with a fixed-seed
///    [math.Random] and cached; [render] only reads the cache.
///  * Net is drawn with dark posts + round caps + translucent mesh body +
///    BRIGHT red/white tape band so it is always readable.
class CourtComponent extends Component with HasGameReference<BadmintonGame> {
  // Cached crowd dots — generated once in onLoad.
  final List<_CrowdDot> _crowdDots = [];

  // -- Paints (built once) ---------------------------------------------------

  // Sky gradient paint is rebuilt in _drawSky() because ui.Gradient.linear
  // requires concrete Offset values.
  static final _roofFasciaPaint = Paint()..color = GamePalette.roofFascia;
  static final _roofShadowPaint = Paint()
    ..color = GamePalette.roofUndersideShadow;
  static final _standUpperPaint = Paint()..color = GamePalette.standUpperFill;
  static final _standLowerPaint = Paint()..color = GamePalette.standLowerFill;
  static final _standDividerPaint = Paint()..color = GamePalette.standDivider;
  static final _standCornerPaint = Paint()
    ..color = GamePalette.standCornerWedge;
  static final _seatRedPaint = Paint()..color = GamePalette.seatBlockRed;
  static final _seatBluePaint = Paint()..color = GamePalette.seatBlockBlue;
  static final _adBasePaint = Paint()..color = GamePalette.adStripBase;
  static final _adAltPaint = Paint()..color = GamePalette.adStripAlt;
  static final _adTextPainter = TextPaint(
    style: const TextStyle(
      fontSize: 26,
      color: GamePalette.adTextColor,
      fontWeight: FontWeight.w900,
      letterSpacing: 3,
    ),
  );
  static final _adShadowPaint = Paint()..color = GamePalette.adWallBaseShadow;
  static final _pitchBasePaint = Paint()..color = GamePalette.pitchBase;
  static final _pitchStripePaint = Paint()..color = GamePalette.pitchStripe;
  static final _linePaint = Paint()..color = GamePalette.courtLines;
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

    // Upper tier — exclude the corner wedge zones.
    _generateCrowdTier(
      rng,
      topY: _kStandTop + 6,
      bottomY: _kStandMid - 6,
      leftX: _kCornerWedgeW + 10,
      rightX: kCourtWidth - _kCornerWedgeW - 10,
    );
    // Lower tier — exclude the corner wedge zones.
    _generateCrowdTier(
      rng,
      topY: _kStandMid + 6,
      bottomY: _kStandBottom - 6,
      leftX: _kCornerWedgeW + 10,
      rightX: kCourtWidth - _kCornerWedgeW - 10,
    );
  }

  void _generateCrowdTier(
    math.Random rng, {
    required double topY,
    required double bottomY,
    required double leftX,
    required double rightX,
  }) {
    final rowCount = ((bottomY - topY) / (_kCrowdRadius * _kCrowdSpacing))
        .floor();
    for (var row = 0; row < rowCount; row++) {
      final baseY = topY + row * (bottomY - topY) / rowCount + _kCrowdRadius;
      final y = baseY + rng.nextDouble() * 4 - 2;
      final colCount = ((rightX - leftX) / (_kCrowdRadius * _kCrowdSpacing))
          .floor();
      for (var col = 0; col < colCount; col++) {
        final x =
            leftX +
            col * (rightX - leftX) / colCount +
            _kCrowdRadius +
            rng.nextDouble() * 4 -
            2;
        // Leave a fraction of seats empty so the seat banks show through.
        // The RNG draw happens unconditionally to keep dot positions stable
        // if the chance constant is tuned.
        final empty = rng.nextDouble() < _kCrowdEmptySeatChance;
        final colorIdx = rng.nextInt(GamePalette.crowdColors.length);
        if (empty) continue;
        _crowdDots.add(_CrowdDot(x, y, colorIdx));
      }
    }
  }

  @override
  void render(Canvas canvas) {
    _drawSky(canvas);
    _drawRoof(canvas);
    _drawStands(canvas);
    _drawCrowd(canvas);
    _drawAdWall(canvas);
    _drawGrass(canvas);
    _drawPerspectiveLines(canvas);
    _drawNet(canvas);
  }

  // 1. Sky strip — bright daylight blue above the roof fascia.
  void _drawSky(Canvas canvas) {
    const rect = Rect.fromLTWH(0, 0, kCourtWidth, _kSkyBottom);
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        const Offset(0, _kSkyBottom),
        [GamePalette.skyTop, GamePalette.skyBottom],
      );
    canvas.drawRect(rect, paint);
  }

  // 2. Roof — fascia face + underside shadow band.
  void _drawRoof(Canvas canvas) {
    // Fascia face: light grey/white horizontal band spanning full width.
    canvas
      ..drawRect(
        const Rect.fromLTWH(
          0,
          _kRoofFasciaTop,
          kCourtWidth,
          _kRoofFasciaBottom - _kRoofFasciaTop,
        ),
        _roofFasciaPaint,
      )
      // Underside shadow: slightly darker band below the fascia.
      ..drawRect(
        const Rect.fromLTWH(
          0,
          _kRoofFasciaBottom,
          kCourtWidth,
          _kRoofUndersideBottom - _kRoofFasciaBottom,
        ),
        _roofShadowPaint,
      );
  }

  // 3. Grandstand tiers — two tiers with corner wedge geometry.
  void _drawStands(Canvas canvas) {
    // ---- Upper tier fill (full width) ----
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
      // Divider strip between tiers.
      ..drawRect(
        const Rect.fromLTWH(0, _kStandMid - 2, kCourtWidth, 4),
        _standDividerPaint,
      )
      // ---- Lower tier fill (full width) ----
      ..drawRect(
        const Rect.fromLTWH(
          0,
          _kStandMid,
          kCourtWidth,
          _kStandBottom - _kStandMid,
        ),
        _standLowerPaint,
      );

    // ---- Alternating seat block colour banks in the middle section ----
    // Two bands of coloured seats (red / blue) in the lower tier centre,
    // behind where the crowd dots will be drawn.
    const seatBankH = (_kStandBottom - _kStandMid) / 3;
    // Red seats: top third of lower tier.
    canvas
      ..drawRect(
        const Rect.fromLTWH(
          _kCornerWedgeW,
          _kStandMid,
          kCourtWidth - _kCornerWedgeW * 2,
          seatBankH,
        ),
        _seatRedPaint,
      )
      // Blue seats: bottom third of lower tier.
      ..drawRect(
        const Rect.fromLTWH(
          _kCornerWedgeW,
          _kStandMid + seatBankH * 2,
          kCourtWidth - _kCornerWedgeW * 2,
          seatBankH,
        ),
        _seatBluePaint,
      );

    // ---- Corner wedge sections (left and right) ----
    // Left corner: diagonal wedge from stand top-left to stand bottom-left.
    final leftWedgePath = Path()
      ..moveTo(0, _kStandTop) // top-left corner
      ..lineTo(_kCornerWedgeW, _kStandTop) // top-right of wedge
      ..lineTo(0, _kStandBottom) // bottom-left corner
      ..close();
    canvas.drawPath(leftWedgePath, _standCornerPaint);

    // Right corner: mirror of left wedge.
    final rightWedgePath = Path()
      ..moveTo(kCourtWidth, _kStandTop)
      ..lineTo(kCourtWidth - _kCornerWedgeW, _kStandTop)
      ..lineTo(kCourtWidth, _kStandBottom)
      ..close();
    canvas.drawPath(rightWedgePath, _standCornerPaint);

    // Stepped diagonal blocks within the left wedge (3 steps).
    _drawCornerSteps(canvas, leftSide: true);
    _drawCornerSteps(canvas, leftSide: false);
  }

  /// Draws 3 stepped diagonal blocks inside the corner wedge on one side,
  /// creating the illusion of the bowl geometry curving toward the viewer.
  void _drawCornerSteps(Canvas canvas, {required bool leftSide}) {
    const steps = 3;
    const tierH = (_kStandBottom - _kStandTop) / steps;
    for (var i = 0; i < steps; i++) {
      final topY = _kStandTop + i * tierH;
      final bottomY = topY + tierH;
      final stepInset = _kCornerWedgeW * (i + 1) / steps;
      final paint = i.isEven ? _standCornerPaint : _standDividerPaint;
      if (leftSide) {
        final path = Path()
          ..moveTo(0, topY)
          ..lineTo(stepInset, topY)
          ..lineTo(stepInset * (steps - i) / steps, bottomY)
          ..lineTo(0, bottomY)
          ..close();
        canvas.drawPath(path, paint);
      } else {
        final path = Path()
          ..moveTo(kCourtWidth, topY)
          ..lineTo(kCourtWidth - stepInset, topY)
          ..lineTo(kCourtWidth - stepInset * (steps - i) / steps, bottomY)
          ..lineTo(kCourtWidth, bottomY)
          ..close();
        canvas.drawPath(path, paint);
      }
    }
  }

  // 3b. Crowd dots — drawn on top of stands.
  void _drawCrowd(Canvas canvas) {
    for (final dot in _crowdDots) {
      canvas.drawCircle(
        Offset(dot.x, dot.y),
        _kCrowdRadius,
        _crowdPaints[dot.colorIndex],
      );
    }
  }

  // 4. Ad wall — cream perimeter board with dark text blocks and base shadow.
  void _drawAdWall(Canvas canvas) {
    const wallH = _kAdWallBottom - _kAdWallTop;
    // Alternate cream tiles across full width for tiling depth effect.
    const tileW = 200.0;
    final tileCount = (kCourtWidth / tileW).ceil();
    for (var i = 0; i < tileCount; i++) {
      final paint = i.isEven ? _adBasePaint : _adAltPaint;
      canvas.drawRect(
        Rect.fromLTWH(i * tileW, _kAdWallTop, tileW, wallH),
        paint,
      );
    }

    // Dark block-letter sponsor copy repeated along the wall, centred
    // vertically in the band (matches the reference's perimeter-board text).
    const textY = _kAdWallTop + wallH / 2;
    for (
      var cx = _kAdTextSpacing / 2;
      cx < kCourtWidth;
      cx += _kAdTextSpacing
    ) {
      _adTextPainter.render(
        canvas,
        _kAdText,
        Vector2(cx, textY),
        anchor: Anchor.center,
      );
    }

    // Thin shadow line at the wall base.
    canvas.drawRect(
      const Rect.fromLTWH(0, _kAdWallBottom - 4, kCourtWidth, 4),
      _adShadowPaint,
    );
  }

  // 5. Grass pitch — full viewport width, geometric perspective mow bands.
  //
  // Band heights grow from the far end (_kGrassTop) toward the near end
  // (kCourtHeight) using a geometric progression with ratio _kMowBandRatio.
  // This makes distant bands narrow (compressed) and near bands wide,
  // producing a convincing top-down perspective effect.
  void _drawGrass(Canvas canvas) {
    // Compute band heights using geometric series:
    //   h_0 * (1 + r + r^2 + ... + r^(n-1)) = totalH
    //   h_0 = totalH * (r - 1) / (r^n - 1)
    const totalH = kCourtHeight - _kGrassTop;
    final rN = math.pow(_kMowBandRatio, _kMowBandCount);
    final h0 = totalH * (_kMowBandRatio - 1) / (rN - 1);

    var y = _kGrassTop;
    for (var i = 0; i < _kMowBandCount; i++) {
      final bandH = h0 * math.pow(_kMowBandRatio, i);
      final paint = i.isEven ? _pitchBasePaint : _pitchStripePaint;
      canvas.drawRect(
        Rect.fromLTWH(0, y, kCourtWidth, bandH),
        paint,
      );
      y += bandH;
    }
  }

  // 6. Perspective pitch boundary lines.
  //
  // Back boundary: horizontal line at y = _kAdWallBottom between the back
  //   corner x positions (_kBackBoundaryLeft.._kBackBoundaryRight).
  // Side lines: rays from back corners through ground corners and continuing
  //   to the screen bottom.
  // Short-service tick lines: vertical ticks at kShortServeLineLeft/Right,
  //   scaled proportionally in perspective.
  // Centre line: vertical from back boundary to screen bottom at kNetX.
  void _drawPerspectiveLines(Canvas canvas) {
    final sidePaint = Paint()
      ..color = GamePalette.courtLines
      ..strokeWidth = _kLineThickness
      ..style = PaintingStyle.stroke;

    // Back boundary, side lines, gameplay baseline, ticks, and centre line —
    // all drawn in a single cascade for efficient canvas usage.
    canvas
      // Back boundary line (narrower than screen, follows back perspective edge).
      ..drawLine(
        const Offset(_kBackBoundaryLeft, _kAdWallBottom),
        const Offset(_kBackBoundaryRight, _kAdWallBottom),
        sidePaint,
      )
      // Left side line: from back-boundary left corner to screen bottom.
      ..drawLine(
        const Offset(_kBackBoundaryLeft, _kAdWallBottom),
        const Offset(_kFrontBoundaryLeft, kCourtHeight),
        sidePaint,
      )
      // Right side line: from back-boundary right corner to screen bottom.
      ..drawLine(
        const Offset(_kBackBoundaryRight, _kAdWallBottom),
        const Offset(_kFrontBoundaryRight, kCourtHeight),
        sidePaint,
      )
      // Horizontal baseline at kGroundY — gameplay ground line.
      ..drawLine(
        const Offset(kCourtLeftBound, kGroundY),
        const Offset(kCourtRightBound, kGroundY),
        sidePaint,
      )
      // Short-service line ticks — vertical, rising from kGroundY.
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
      // Centre line — from back boundary down to screen bottom at kNetX.
      // Stays at x=kNetX because the vanishing point is on x=kNetX.
      ..drawLine(
        const Offset(kNetX, _kAdWallBottom),
        const Offset(kNetX, kCourtHeight),
        sidePaint,
      );
  }

  // 7. Net — dark posts with round caps + translucent mesh body + bright tape.
  //
  // Posts reach from kGroundY up to kNetTopY (sitting ON the grass floor).
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
