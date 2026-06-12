import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/entities/player.dart';
import 'package:smash_bros/engine/render/render_state.dart';
import 'package:smash_bros/engine/systems/shot_system.dart';
import 'package:smash_bros/game/badminton_game.dart';
import 'package:smash_bros/game/palette.dart';

// ---------------------------------------------------------------------------
// PlayerComponent — M1-player-amongus
//   (based on M1-023, M1-027, depth + swing pass M1-035v)
//
// Draws one player as an Among Us crewmate bean character (side view).
// Painter's order inside render():
//   0. Drop shadow ellipse at kGroundY (fades/shrinks with jump height).
//   1. Backpack — rounded rect on the back side of the body.
//   2. Bean body — tall capsule/rounded-rect (team colour) with shade band and
//      dark outline. Legs are two stubby rounded-bottom rects with a gap notch.
//   3. Visor — rounded oval on the upper body facing side, cyan-grey glass with
//      a white specular band and dark outline.
//   4. Racquet — animated through a swing arc (12 render frames) when a
//      SwingEvent is received. Static rest position otherwise. Pivot at the
//      visor-side mid-body (shoulder).
//   5. Impact flash (white starburst, 5 lines) on the first 3 swing frames.
//   6. Stun flash overlay — white blink covers the bean body while stunned.
//   7. Dizzy stars — 3 stars arc above the bean's domed top while stunned.
//
// Tick-order position: rendered after CourtComponent, before ShuttleComponent.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Bean body geometry (game units, relative to feetY / centreX).
// ---------------------------------------------------------------------------

// Overall bean dimensions. Wider than the 60-unit hitbox for a chunkier look.
// Body is 78 wide; with the backpack extending ~22 units to the back and the
// visor overhang of ~16 units, the visual footprint is ~95 wide (_kBeanH = 150).
const double _kBeanH = 150; // total bean height (== kPlayerHitboxHeight)

// Body rect is drawn as a tall rounded rectangle; the dome top is captured by
// the large corner radius. Legs are drawn separately below the body rect.
const double _kBodyW = 78; // width of the main body rounded rect
const double _kBodyH =
    118; // height of the body rect (from leg-top to head dome)
const double _kBodyCornerR = 36; // large radius gives the domed-top bean shape

// Body rect top = feetY − _kLegH − _kBodyH
const double _kLegH = 26; // height of the stubby leg protrusions
const double _kLegW =
    28; // width of each leg (slightly narrower than half body)
const double _kLegCornerR = 8; // rounded corners on legs
const double _kLegGap = 8; // horizontal gap between legs
const double _kLegOffset = _kBodyW / 2 - _kLegW / 2 - _kLegGap / 2;
// leg centres: centreX ± _kLegOffset

// Outline stroke width (essential for the Among Us look).
const double _kOutlineW = 3;

// Shade band: covers the lower portion of the body with a darker tint.
// Drawn as a clipped rect inside the body path.
const double _kShadeBandFraction = 0.38; // fraction of body height from bottom

// ---------------------------------------------------------------------------
// Visor geometry.
// ---------------------------------------------------------------------------
const double _kVisorW = 50; // width of the visor ellipse
const double _kVisorH = 30; // height of the visor ellipse
// Visor centre: vertically at 87% of the body from feet (just inside the dome)
//   = feetY − _kLegH − _kBodyH * 0.87
const double _kVisorFromFeet = _kLegH + _kBodyH * 0.87;
// Horizontal: visor is shifted toward the facing side so it overhangs the body.
const double _kVisorFacingShift = 16; // shift toward facing direction
// Specular highlight: upper band inside visor
const double _kVisorHighlightH = 10;

// ---------------------------------------------------------------------------
// Backpack geometry.
// ---------------------------------------------------------------------------
const double _kBackpackW = 22; // backpack width
// Backpack runs from 35%–70% of body height above feet.
const double _kBackpackTop = _kLegH + _kBodyH * 0.35;
const double _kBackpackBottom = _kLegH + _kBodyH * 0.70;
const double _kBackpackH = _kBackpackBottom - _kBackpackTop;
// Backpack X: hugs the back edge of the body.
const double _kBackpackCornerR = 5;

// ---------------------------------------------------------------------------
// Racquet geometry (unchanged from previous version).
// ---------------------------------------------------------------------------
const double _kRacquetOvalW = 20;
const double _kRacquetOvalH = 30;
const double _kRacquetHandleLen = 22;
const double _kRacquetHandleW = 4;
// Shoulder pivot at visor-side mid-body, ~80 units above feet.
const double _kRacquetFromFeet = 80;

// ---------------------------------------------------------------------------
// Swing animation (angles in radians; 0 = arm pointing straight up).
// ---------------------------------------------------------------------------
const double _kSwingBackNormal = -60 * math.pi / 180;
const double _kSwingFollowNormal = 75 * math.pi / 180;
const double _kSwingBackSmash = -90 * math.pi / 180;
const double _kSwingFollowSmash = 80 * math.pi / 180;
const double _kSwingBackDrop = -40 * math.pi / 180;
const double _kSwingFollowDrop = 55 * math.pi / 180;

// Swing animation duration in render frames.
const int _kSwingDuration = 12;
// Impact flash duration (frames from swing start).
const int _kFlashDuration = 3;
const int _kFlashLineCount = 5;
const double _kFlashLineLen = 10;

// ---------------------------------------------------------------------------
// Drop shadow geometry.
// ---------------------------------------------------------------------------
const double _kShadowW = 56;
const double _kShadowH = 14;

// ---------------------------------------------------------------------------
// Dizzy star geometry (stun effect). Stars orbit above the bean dome.
// ---------------------------------------------------------------------------
const double _kStarRadius = 7;
const int _kStarCount = 3;
const double _kStarOrbitRadius = 30;
// Orbit centre: above the dome top = feetY − _kBeanH − 20
const double _kStarOrbitAboveFeet = _kBeanH + 20;

/// Renders one player avatar as an Among Us crewmate bean character.
///
/// Responsibilities (pure presentation — no game logic):
///  * Each [update] reads the matching [PlayerView] from [BadmintonGame.view]
///    and sets [position] so the hitbox rect (60 × 150) is anchored at the
///    player's feet (top-left = (x − 30, feetY − 150)).
///  * [update] also scans [BadmintonGame.frameEvents] for a [SwingEvent]
///    matching this component's [side] and starts a 12-frame swing animation.
///  * [render] draws the crewmate in painter's order: shadow, backpack, bean
///    body (with shade band and leg notch), visor, racquet, stun FX.
///  * Drop shadow fades/shrinks as the player rises (scale by 1 − jumpFraction).
///  * When [PlayerView.isStunned], a stun-flash blinks every 8 render frames
///    AND 3 dizzy stars arc above the bean's dome.
///
/// One [PlayerComponent] instance is created per [CourtSide].
class PlayerComponent extends Component with HasGameReference<BadmintonGame> {
  /// Creates a component that tracks the player on [side].
  PlayerComponent(this.side);

  /// Which court side this component tracks.
  final CourtSide side;

  // Suit fill — team colour.
  late final Paint _suitPaint = Paint()
    ..color = side == CourtSide.left
        ? GamePalette.leftPlayer
        : GamePalette.rightPlayer;

  // Suit shade — darker tint for the lower body band.
  late final Paint _suitShadePaint = Paint()
    ..color = side == CourtSide.left
        ? GamePalette.leftPlayerShade
        : GamePalette.rightPlayerShade;

  // Backpack fill — slightly darker suit colour.
  late final Paint _backpackPaint = Paint()
    ..color = side == CourtSide.left
        ? GamePalette.leftPlayerBackpack
        : GamePalette.rightPlayerBackpack;

  // Dark outline paint shared by body, visor, backpack.
  static final _outlinePaint = Paint()
    ..color = GamePalette.crewmateOutline
    ..style = PaintingStyle.stroke
    ..strokeWidth = _kOutlineW;

  // Visor fills.
  static final _visorPaint = Paint()..color = GamePalette.crewmateVisor;
  static final _visorHighlightPaint = Paint()
    ..color = GamePalette.crewmateVisorHighlight;

  // Stun / dizzy.
  static final _stunPaint = Paint()..color = GamePalette.stunFlash;
  static final _dizzyStarPaint = Paint()..color = GamePalette.dizzyStarColor;

  // Impact flash.
  static final _flashPaint = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..strokeWidth = 2.5
    ..style = PaintingStyle.stroke;

  // Racquet head — light string-bed fill + dark outline so the racquet stays
  // readable against the same-coloured suit body it overlaps at rest.
  static final _racquetBedPaint = Paint()
    ..color = const Color(0xD9FFFFFF); // white, ~85% alpha
  static final _racquetOutlinePaint = Paint()
    ..color = GamePalette.crewmateOutline
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5;

  // Stun-blink state: purely cosmetic frame counter.
  int _blinkCounter = 0;

  // Swing animation state.
  int _swingFrame = _kSwingDuration; // >= _kSwingDuration means not swinging
  double _swingBackAngle = _kSwingBackNormal;
  double _swingFollowAngle = _kSwingFollowNormal;

  /// Whether this component is currently playing a swing animation.
  ///
  /// Exposed for testing via `@visibleForTesting`.
  @visibleForTesting
  bool get isSwinging => _swingFrame < _kSwingDuration;

  /// The current swing frame counter (0 = just started, _kSwingDuration = done).
  ///
  /// Exposed for testing.
  @visibleForTesting
  int get swingFrame => _swingFrame;

  // Cached view snapshot used by render (set in update, used in render).
  PlayerView? _playerView;

  /// Current position of this component in game-unit world space.
  ///
  /// Top-left of the hitbox rect: (x − 30, feetY − 150).
  Vector2 position = Vector2.zero();

  @override
  void update(double dt) {
    final pv = _playerViewFromGame();
    _playerView = pv;
    // Anchor: top-left of the 60×150 hitbox.
    position = Vector2(
      pv.x - kPlayerHitboxWidth / 2,
      pv.feetY - kPlayerHitboxHeight,
    );
    _blinkCounter++;

    // Advance swing animation.
    if (_swingFrame < _kSwingDuration) {
      _swingFrame++;
    }

    // Check for a SwingEvent matching this side in frameEvents.
    for (final event in game.frameEvents) {
      if (event is SwingEvent && event.side == side) {
        _startSwing(event.shotType, event.wasAirborne);
        break; // only one swing per frame
      }
    }
  }

  void _startSwing(ShotType shotType, bool wasAirborne) {
    _swingFrame = 0;
    if (wasAirborne || shotType == ShotType.smash) {
      _swingBackAngle = _kSwingBackSmash;
      _swingFollowAngle = _kSwingFollowSmash;
    } else if (shotType == ShotType.drop) {
      _swingBackAngle = _kSwingBackDrop;
      _swingFollowAngle = _kSwingFollowDrop;
    } else {
      _swingBackAngle = _kSwingBackNormal;
      _swingFollowAngle = _kSwingFollowNormal;
    }
  }

  @override
  void render(Canvas canvas) {
    final pv = _playerView;
    if (pv == null) return;

    final feetY = pv.feetY;
    final centreX = pv.x;
    final facingRight = pv.facing == Facing.right;

    // -- 0. Drop shadow at kGroundY (depth cue) --------------------------------
    final jumpFraction = ((kGroundY - feetY) / kPlayerJumpHeight).clamp(
      0.0,
      1.0,
    );
    final shadowScale = 1.0 - jumpFraction;
    if (shadowScale > 0.01) {
      final shadowW = _kShadowW * shadowScale;
      final shadowH = _kShadowH * shadowScale;
      final shadowPaint = Paint()
        ..color = const Color(0xFF000000).withValues(alpha: 0.35 * shadowScale);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(centreX, kGroundY - shadowH / 2),
          width: shadowW,
          height: shadowH,
        ),
        shadowPaint,
      );
    }

    // Bean body bottom sits at the leg tops; body rect spans _kBodyH above that.
    final legTopY = feetY - _kLegH;
    final bodyTopY = legTopY - _kBodyH;

    // Facing direction sign: +1 = right, -1 = left.
    final facingSign = facingRight ? 1.0 : -1.0;

    // Back edge of the body rect (for backpack attachment).
    final backEdgeX = centreX - facingSign * (_kBodyW / 2);

    // -- 1. Backpack (behind body — draw first) --------------------------------
    final backpackLeft = facingRight ? backEdgeX - _kBackpackW : backEdgeX;
    final backpackTop = feetY - _kBackpackBottom;
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(backpackLeft, backpackTop, _kBackpackW, _kBackpackH),
          const Radius.circular(_kBackpackCornerR),
        ),
        _backpackPaint,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(backpackLeft, backpackTop, _kBackpackW, _kBackpackH),
          const Radius.circular(_kBackpackCornerR),
        ),
        _outlinePaint,
      );

    // -- 2. Bean body (main suit shape) ----------------------------------------
    // 2a. Body rounded rect fill.
    final bodyRect = Rect.fromLTWH(
      centreX - _kBodyW / 2,
      bodyTopY,
      _kBodyW,
      _kBodyH,
    );
    final bodyRRect = RRect.fromRectAndRadius(
      bodyRect,
      const Radius.circular(_kBodyCornerR),
    );
    canvas.drawRRect(bodyRRect, _suitPaint);

    // 2b. Lower-body shade band — clipped to the body shape.
    // 2c. Body outline — drawn after restoring the clip.
    const shadeBandH = _kBodyH * _kShadeBandFraction;
    canvas
      ..save()
      ..clipRRect(bodyRRect)
      ..drawRect(
        Rect.fromLTWH(
          centreX - _kBodyW / 2,
          bodyTopY + _kBodyH - shadeBandH,
          _kBodyW,
          shadeBandH,
        ),
        _suitShadePaint,
      )
      ..restore()
      ..drawRRect(bodyRRect, _outlinePaint);

    // -- 3. Legs — two stubby rounded-bottom rects with a gap notch -----------
    // Left leg (relative to body, not facing): centreX − offset.
    final leftLegCX = centreX - _kLegOffset;
    final rightLegCX = centreX + _kLegOffset;
    for (final legCX in [leftLegCX, rightLegCX]) {
      final legRect = Rect.fromLTWH(
        legCX - _kLegW / 2,
        legTopY,
        _kLegW,
        _kLegH,
      );
      // Only bottom corners rounded (reads as the leg tip).
      final legRRect = RRect.fromRectAndCorners(
        legRect,
        bottomLeft: const Radius.circular(_kLegCornerR),
        bottomRight: const Radius.circular(_kLegCornerR),
      );
      canvas
        ..drawRRect(legRRect, _suitPaint)
        ..drawRRect(legRRect, _outlinePaint);
    }

    // -- 4. Visor (facing side) -----------------------------------------------
    final visorCX = centreX + facingSign * _kVisorFacingShift;
    final visorCY = feetY - _kVisorFromFeet;
    final visorRect = Rect.fromCenter(
      center: Offset(visorCX, visorCY),
      width: _kVisorW,
      height: _kVisorH,
    );
    // Visor fill, specular highlight (clipped), and outline.
    canvas
      ..drawOval(visorRect, _visorPaint)
      ..save()
      ..clipPath(Path()..addOval(visorRect))
      ..drawRect(
        Rect.fromLTWH(
          visorRect.left,
          visorRect.top,
          _kVisorW,
          _kVisorHighlightH,
        ),
        _visorHighlightPaint,
      )
      ..restore()
      ..drawOval(visorRect, _outlinePaint);

    // -- 5. Racquet (animated swing or static rest position) ------------------
    _drawRacquet(canvas, feetY, centreX, facingRight);

    // -- 6. Stun flash overlay (blink every 8 frames; covers body) ------------
    if (pv.isStunned && (_blinkCounter ~/ 8).isEven) {
      canvas
        ..save()
        ..clipRRect(bodyRRect)
        ..drawRect(bodyRect, _stunPaint)
        ..restore();
    }

    // -- 7. Dizzy stars (3 stars arcing above the dome while stunned) ---------
    if (pv.isStunned) {
      final angleOffset = _blinkCounter * 0.08;
      final orbitCX = centreX;
      final orbitCY = feetY - _kStarOrbitAboveFeet;
      for (var i = 0; i < _kStarCount; i++) {
        final angle = angleOffset + i * (2 * math.pi / _kStarCount);
        final starX = orbitCX + math.cos(angle) * _kStarOrbitRadius;
        final starY = orbitCY + math.sin(angle) * (_kStarOrbitRadius * 0.5);
        _drawStar(canvas, starX, starY, _kStarRadius, _dizzyStarPaint);
      }
    }
  }

  // Draws the racquet — animated through a swing arc if swinging, or at the
  // static rest position otherwise.
  //
  // Pivot is the "shoulder" at visor-side mid-body (~80 units above feet).
  // Angle 0 = arm pointing straight up from shoulder; positive = clockwise.
  void _drawRacquet(
    Canvas canvas,
    double feetY,
    double centreX,
    bool facingRight,
  ) {
    final shoulderX = facingRight
        ? centreX + _kBodyW / 2
        : centreX - _kBodyW / 2;
    final shoulderY = feetY - _kRacquetFromFeet;

    double racquetAngle;
    if (_swingFrame < _kSwingDuration) {
      final t = _swingFrame / _kSwingDuration;
      final eased = t * (2 - t);
      racquetAngle =
          _swingBackAngle + (_swingFollowAngle - _swingBackAngle) * eased;
    } else {
      racquetAngle = facingRight ? 15 * math.pi / 180 : -15 * math.pi / 180;
    }

    final signedAngle = facingRight ? racquetAngle : -racquetAngle;

    final handleEndX = shoulderX + math.sin(signedAngle) * _kRacquetHandleLen;
    final handleEndY = shoulderY - math.cos(signedAngle) * _kRacquetHandleLen;

    final handlePaint = Paint()
      ..color = GamePalette.racquetHandle
      ..strokeWidth = _kRacquetHandleW
      ..style = PaintingStyle.stroke;

    canvas
      ..save()
      ..drawLine(
        Offset(shoulderX, shoulderY),
        Offset(handleEndX, handleEndY),
        handlePaint,
      )
      ..translate(handleEndX, handleEndY)
      ..rotate(signedAngle)
      ..drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: _kRacquetOvalW,
          height: _kRacquetOvalH,
        ),
        _racquetBedPaint,
      )
      ..drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: _kRacquetOvalW,
          height: _kRacquetOvalH,
        ),
        _racquetOutlinePaint,
      )
      ..restore();

    // -- Impact flash on first _kFlashDuration frames of swing ----------------
    if (_swingFrame < _kFlashDuration) {
      for (var i = 0; i < _kFlashLineCount; i++) {
        final a = signedAngle + (i * 2 * math.pi / _kFlashLineCount);
        final fx1 = handleEndX + math.sin(a) * 4;
        final fy1 = handleEndY - math.cos(a) * 4;
        final fx2 = handleEndX + math.sin(a) * (4 + _kFlashLineLen);
        final fy2 = handleEndY - math.cos(a) * (4 + _kFlashLineLen);
        canvas.drawLine(Offset(fx1, fy1), Offset(fx2, fy2), _flashPaint);
      }
    }
  }

  /// Draws a 5-pointed star centred at ([cx],[cy]) with outer [radius].
  void _drawStar(
    Canvas canvas,
    double cx,
    double cy,
    double radius,
    Paint paint,
  ) {
    const points = 5;
    const innerRadiusFraction = 0.45;
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius : radius * innerRadiusFraction;
      final angle = (i * math.pi / points) - math.pi / 2;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  PlayerView _playerViewFromGame() {
    final v = game.view;
    return side == CourtSide.left ? v.leftPlayer : v.rightPlayer;
  }
}
