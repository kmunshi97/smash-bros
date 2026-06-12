import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/entities/player.dart';
import 'package:smash_bros/engine/render/render_state.dart';
import 'package:smash_bros/game/badminton_game.dart';
import 'package:smash_bros/game/palette.dart';

// ---------------------------------------------------------------------------
// PlayerComponent — M1-023 (reskinned M1-027)
//
// Draws one player (left or right side) as a cartoon "big-head" character:
//   • Large head circle (≈52 diameter) centred near the top of the hitbox,
//     with skin tone, eyes (white + pupil), and a coloured headband strip.
//   • Short rounded torso (team colour) below the head.
//   • Two shoe ellipses at the feet (dark).
//   • Racquet hint on the facing side — a small oval outline + handle — that
//     flips with facing direction.
//   • Stun flash overlay (white blink) + 3 dizzy stars arcing above the head.
//
// Position/feet-anchor logic is UNCHANGED from M1-023. Only render() is
// rewritten.
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

// Racquet geometry — oval + handle on the facing side, at shoulder height.
const double _kRacquetOvalW = 20;
const double _kRacquetOvalH = 30;
const double _kRacquetHandleW = 4;
const double _kRacquetFromFeet = 85; // vertical position above feet

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
///  * [render] draws the cartoon character within (approximately within) the
///    hitbox. The big head (80-unit diameter on a 60-unit-wide hitbox)
///    deliberately overflows ~10 units per side — purely cosmetic; collision
///    uses the engine hitbox, never the drawing.
///  * When [PlayerView.isStunned], a stun-flash blinks every 8 render frames
///    AND 3 dizzy stars arc above the head.
///  * Racquet flips with [PlayerView.facing] so the contact-zone side is
///    always on the correct side.
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

  // Racquet outline — team colour stroke.
  late final Paint _racquetOutlinePaint = Paint()
    ..color = side == CourtSide.left
        ? GamePalette.leftPlayer
        : GamePalette.rightPlayer
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5;

  // Stun-blink state: purely cosmetic frame counter.
  int _blinkCounter = 0;

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
  }

  @override
  void render(Canvas canvas) {
    final pv = _playerView;
    if (pv == null) return;

    // Convenience aliases.
    final feetY = pv.feetY;
    final centreX = pv.x;
    final facingRight = pv.facing == Facing.right;

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

    // -- 6. Racquet hint on the facing side -----------------------------------
    // Oval outline at racquet height + handle from body edge to oval.
    final racquetY = feetY - _kRacquetFromFeet;
    final ovalCX = facingRight
        ? centreX + _kTorsoW / 2 + _kRacquetOvalW / 2
        : centreX - _kTorsoW / 2 - _kRacquetOvalW / 2;
    final handleX1 = facingRight
        ? centreX + _kTorsoW / 2
        : centreX - _kTorsoW / 2;
    final handleX2 = facingRight
        ? ovalCX - _kRacquetOvalW / 2
        : ovalCX + _kRacquetOvalW / 2;
    final handlePaint = Paint()
      ..color = GamePalette.shoeColor
      ..strokeWidth = _kRacquetHandleW
      ..style = PaintingStyle.stroke;
    canvas
      ..drawLine(
        Offset(handleX1, racquetY),
        Offset(handleX2, racquetY),
        handlePaint,
      )
      ..drawOval(
        Rect.fromCenter(
          center: Offset(ovalCX, racquetY),
          width: _kRacquetOvalW,
          height: _kRacquetOvalH,
        ),
        _racquetOutlinePaint,
      );

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
