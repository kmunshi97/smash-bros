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
// PlayerComponent — M1-023 (reskinned M1-027, depth + swing pass M1-035v)
//
// Draws one player (left or right side) as a cartoon "big-head" character:
//   • Drop shadow ellipse at kGroundY, fading as the player rises (depth cue).
//   • Large head circle (≈52 diameter) centred near the top of the hitbox,
//     with skin tone, eyes (white + pupil), and a coloured headband strip.
//   • Short rounded torso (team colour) below the head.
//   • Two shoe ellipses at the feet (dark).
//   • Racquet animated through a swing arc over 12 render frames when a
//     SwingEvent is received for this component's side. While not swinging,
//     the racquet rests at the static shoulder position.
//   • Impact flash (white starburst, 4 lines) on the first 3 frames of swing.
//   • Stun flash overlay (white blink) + 3 dizzy stars arcing above the head.
//
// Tick-order position: rendered after CourtComponent, before ShuttleComponent.
// ---------------------------------------------------------------------------

// Geometry-rebalance: all proportions sized for the 150-unit-tall, 60-wide
// hitbox. The big-head look puts the head at ~53% of total height (the
// reference style is roughly head-half, body-half).

// Head geometry (game units).
const double _kHeadDiameter = 80;
const double _kHeadRadius = _kHeadDiameter / 2;
// Head centre is at feetY − _kHeadCentreFromFeet units above feet. The head
// occupies the top of the hitbox: top of head = 110 + 40 = 150 = hitbox top.
const double _kHeadCentreFromFeet = 110;

// Headband geometry.
const double _kHeadbandH = 14;
const double _kHeadbandOffsetFromHeadCentre = 10; // y offset from head centre

// Eye geometry.
const double _kEyeRadius = 10;
const double _kPupilRadius = 6;
const double _kEyeOffsetX = 15; // half-distance between the two eyes
const double _kEyeOffsetY = 6; // upward offset from head centre

// Torso geometry.
const double _kTorsoW = 40;
const double _kTorsoH = 60;
// Torso top = head bottom (feetY − 70).
const double _kTorsoTopFromFeet = _kHeadCentreFromFeet - _kHeadRadius;

// Shoe geometry.
const double _kShoeW = 24;
const double _kShoeH = 10;

// Racquet geometry — drawn at shoulder height, swings through an arc.
const double _kRacquetOvalW = 20;
const double _kRacquetOvalH = 30;
const double _kRacquetHandleLen = 22; // handle length from shoulder to frame
const double _kRacquetHandleW = 4;
const double _kRacquetFromFeet = 85; // shoulder vertical position above feet

// Swing animation geometry (in radians; 0 = pointing straight up from shoulder).
// Normal swing: back position −60°, follow-through +75°.
const double _kSwingBackNormal = -60 * math.pi / 180;
const double _kSwingFollowNormal = 75 * math.pi / 180;
// Smash/airborne: wider arc.
const double _kSwingBackSmash = -90 * math.pi / 180;
const double _kSwingFollowSmash = 80 * math.pi / 180;
// Drop shot: gentler arc.
const double _kSwingBackDrop = -40 * math.pi / 180;
const double _kSwingFollowDrop = 55 * math.pi / 180;

// Swing animation duration in render frames (~12 ticks at 60 Hz).
const int _kSwingDuration = 12;
// Impact flash duration (frames from swing start).
const int _kFlashDuration = 3;
// Impact flash geometry.
const int _kFlashLineCount = 5;
const double _kFlashLineLen = 10;

// Drop shadow geometry.
const double _kShadowW = 50; // full width of shadow ellipse at ground
const double _kShadowH = 12; // height of shadow ellipse at ground

// Dizzy star geometry (stun effect).
const double _kStarRadius = 7;
const int _kStarCount = 3;
const double _kStarOrbitRadius = 30;
const double _kStarOrbitOffsetY = 20; // above head centre

/// Renders one player avatar as a cartoon big-head character.
///
/// Responsibilities (pure presentation — no game logic):
///  * Each [update] reads the matching [PlayerView] from [BadmintonGame.view]
///    and sets [position] so the hitbox rect (60 x 150) is anchored at the
///    player's feet (top-left = (x - 30, feetY - 150)).
///  * [update] also scans [BadmintonGame.frameEvents] for a [SwingEvent]
///    matching this component's [side] and starts a 12-frame swing animation.
///  * [render] draws the cartoon character in painter's order: shadow, shoes,
///    torso, head, eyes, racquet (animated or static), stun FX.
///  * Drop shadow fades/shrinks as the player rises (scale by 1 − jumpFraction).
///  * When [PlayerView.isStunned], a stun-flash blinks every 8 render frames
///    AND 3 dizzy stars arc above the head.
///
/// One [PlayerComponent] instance is created per [CourtSide].
class PlayerComponent extends Component with HasGameReference<BadmintonGame> {
  /// Creates a component that tracks the player on [side].
  PlayerComponent(this.side);

  /// Which court side this component tracks.
  final CourtSide side;

  // Body paint — team colour.
  late final Paint _bodyPaint = Paint()
    ..color = side == CourtSide.left
        ? GamePalette.leftPlayer
        : GamePalette.rightPlayer;

  // Skin tone paint per side.
  late final Paint _skinPaint = Paint()
    ..color = side == CourtSide.left
        ? GamePalette.skinToneLeft
        : GamePalette.skinToneRight;

  // Headband paint per side.
  late final Paint _headbandPaint = Paint()
    ..color = side == CourtSide.left
        ? GamePalette.headbandLeft
        : GamePalette.headbandRight;

  static final _eyeWhitePaint = Paint()..color = GamePalette.eyeWhite;
  static final _pupilPaint = Paint()..color = GamePalette.eyePupil;
  static final _shoePaint = Paint()..color = GamePalette.shoeColor;
  static final _stunPaint = Paint()..color = GamePalette.stunFlash;
  static final _dizzyStarPaint = Paint()..color = GamePalette.dizzyStarColor;
  static final _flashPaint = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..strokeWidth = 2.5
    ..style = PaintingStyle.stroke;

  // Racquet outline — team colour stroke.
  late final Paint _racquetOutlinePaint = Paint()
    ..color = side == CourtSide.left
        ? GamePalette.leftPlayer
        : GamePalette.rightPlayer
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
  /// Top-left of the hitbox rect: (x - 30, feetY - 150).
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

    // Convenience aliases.
    final feetY = pv.feetY;
    final centreX = pv.x;
    final facingRight = pv.facing == Facing.right;

    // -- 0. Drop shadow at kGroundY (depth cue) --------------------------------
    // The shadow fades and shrinks as the player rises. Scale = 1 when on the
    // ground, 0 when at the jump apex. Derived from feetY vs kGroundY and
    // kPlayerJumpHeight.
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

    // -- 1. Shoes at feet -----------------------------------------------------
    canvas
      ..drawOval(
        Rect.fromCenter(
          center: Offset(centreX - 8, feetY - _kShoeH / 2),
          width: _kShoeW,
          height: _kShoeH,
        ),
        _shoePaint,
      )
      ..drawOval(
        Rect.fromCenter(
          center: Offset(centreX + 8, feetY - _kShoeH / 2),
          width: _kShoeW,
          height: _kShoeH,
        ),
        _shoePaint,
      );

    // -- 2. Torso (rounded rect, team colour) ----------------------------------
    final torsoTop = feetY - _kTorsoTopFromFeet - _kTorsoH;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centreX - _kTorsoW / 2,
          torsoTop,
          _kTorsoW,
          _kTorsoH,
        ),
        const Radius.circular(6),
      ),
      _bodyPaint,
    );

    // -- 3. Head + 4. Headband (clipped to head circle) ----------------------
    final headCy = feetY - _kHeadCentreFromFeet;
    canvas
      ..drawCircle(Offset(centreX, headCy), _kHeadRadius, _skinPaint)
      ..save()
      ..clipPath(
        Path()..addOval(
          Rect.fromCircle(
            center: Offset(centreX, headCy),
            radius: _kHeadRadius,
          ),
        ),
      )
      ..drawRect(
        Rect.fromLTWH(
          centreX - _kHeadRadius,
          headCy - _kHeadbandOffsetFromHeadCentre - _kHeadbandH / 2,
          _kHeadDiameter,
          _kHeadbandH,
        ),
        _headbandPaint,
      )
      ..restore();

    // -- 5. Eyes (two circles, pupils look toward facing direction) -----------
    final pupilShift = facingRight ? 1.5 : -1.5;
    final eyeY = headCy - _kEyeOffsetY;
    // All four eye circles in one cascade.
    canvas
      ..drawCircle(
        Offset(centreX - _kEyeOffsetX, eyeY),
        _kEyeRadius,
        _eyeWhitePaint,
      )
      ..drawCircle(
        Offset(centreX - _kEyeOffsetX + pupilShift, eyeY),
        _kPupilRadius,
        _pupilPaint,
      )
      ..drawCircle(
        Offset(centreX + _kEyeOffsetX, eyeY),
        _kEyeRadius,
        _eyeWhitePaint,
      )
      ..drawCircle(
        Offset(centreX + _kEyeOffsetX + pupilShift, eyeY),
        _kPupilRadius,
        _pupilPaint,
      );

    // -- 6. Racquet (animated swing or static rest position) ------------------
    _drawRacquet(canvas, feetY, centreX, facingRight);

    // -- 7. Stun flash overlay (blink every 8 frames) -------------------------
    if (pv.isStunned && (_blinkCounter ~/ 8).isEven) {
      canvas.drawCircle(Offset(centreX, headCy), _kHeadRadius, _stunPaint);
    }

    // -- 8. Dizzy stars (3 stars arcing above head while stunned) -------------
    if (pv.isStunned) {
      final angleOffset = _blinkCounter * 0.08; // radians per frame
      for (var i = 0; i < _kStarCount; i++) {
        final angle = angleOffset + i * (2 * math.pi / _kStarCount);
        final starX = centreX + math.cos(angle) * _kStarOrbitRadius;
        final starY =
            headCy -
            _kStarOrbitOffsetY +
            math.sin(angle) * (_kStarOrbitRadius * 0.5);
        _drawStar(canvas, starX, starY, _kStarRadius, _dizzyStarPaint);
      }
    }
  }

  // Draws the racquet — animated through a swing arc if swinging, or at the
  // static rest position otherwise.
  //
  // The racquet pivots around the shoulder point. Angle 0 = arm pointing
  // straight up from shoulder; positive = clockwise (toward the ground on the
  // right side). For the left-facing player the angles are mirrored.
  void _drawRacquet(
    Canvas canvas,
    double feetY,
    double centreX,
    bool facingRight,
  ) {
    // Shoulder position (the pivot for the swing arc).
    final shoulderX = facingRight
        ? centreX + _kTorsoW / 2
        : centreX - _kTorsoW / 2;
    final shoulderY = feetY - _kRacquetFromFeet;

    // Compute the current racquet angle.
    double racquetAngle;
    if (_swingFrame < _kSwingDuration) {
      // Swing in progress — ease-out: t*(2−t).
      final t = _swingFrame / _kSwingDuration;
      final eased = t * (2 - t);
      racquetAngle =
          _swingBackAngle + (_swingFollowAngle - _swingBackAngle) * eased;
    } else {
      // Static rest: racquet points slightly outward from shoulder.
      racquetAngle = facingRight ? 15 * math.pi / 180 : -15 * math.pi / 180;
    }

    // Mirror angle for left-facing player (facing left means racquet is on the
    // left side, angles are negated).
    final signedAngle = facingRight ? racquetAngle : -racquetAngle;

    // The racquet frame centre is at the end of the handle from shoulder.
    // Angle 0 = up (negative y), so sin/cos components:
    //   dx = sin(signedAngle) * handle (toward +x when angle > 0)
    //   dy = -cos(signedAngle) * handle (upward when angle ~ 0)
    final handleEndX = shoulderX + math.sin(signedAngle) * _kRacquetHandleLen;
    final handleEndY = shoulderY - math.cos(signedAngle) * _kRacquetHandleLen;

    // Draw handle.
    final handlePaint = Paint()
      ..color = GamePalette.shoeColor
      ..strokeWidth = _kRacquetHandleW
      ..style = PaintingStyle.stroke;

    canvas
      ..save()
      ..drawLine(
        Offset(shoulderX, shoulderY),
        Offset(handleEndX, handleEndY),
        handlePaint,
      )
      // Draw racquet head (oval) — centred at handle end, rotated with swing.
      // Use canvas transform so the oval aligns with the swing direction.
      ..translate(handleEndX, handleEndY)
      ..rotate(signedAngle)
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
