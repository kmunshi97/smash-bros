import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/entities/player.dart';
import 'package:smash_bros/engine/render/render_state.dart';
import 'package:smash_bros/game/animation/player_animator.dart';
import 'package:smash_bros/game/badminton_game.dart';
import 'package:smash_bros/game/palette.dart';

// ---------------------------------------------------------------------------
// PlayerComponent — M1-023c sprite characters
//   (based on M1-023, M1-027, M1-035v, M1-023b)
//
// Draws one player as a full-character sprite (racquet baked into the art).
// The local player is always the red astronaut; the opponent is one of three
// parody tycoon sprites picked per match in BadmintonGame. Painter's order:
//   0. Drop shadow ellipse at kGroundY (fades/shrinks with jump height).
//   1. Character sprite — aspect-scaled to the 150-unit hitbox height,
//      feet-anchored, horizontally flipped to match PlayerView.facing, with a
//      translucent white tint on stun blink frames.
//   2. Dizzy stars — 3 stars arc above the character while stunned.
//
// A SwingEvent still drives the [isSwinging]/[swingFrame] counters (consumed
// by tests today; sprite-sheet swing animations arrive with M2-001 and will
// read the same counters).
//
// Tick-order position: rendered after CourtComponent, before ShuttleComponent.
// ---------------------------------------------------------------------------

// Swing animation duration in render frames (counter only; see header).
const int _kSwingDuration = 12;

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

/// Renders one player avatar as a full-character sprite.
///
/// Responsibilities (pure presentation — no game logic):
///  * Each [update] reads the matching [PlayerView] from [BadmintonGame.view]
///    and sets [position] so the hitbox rect (60 × 150) is anchored at the
///    player's feet (top-left = (x − 30, feetY − 150)).
///  * [update] also scans [BadmintonGame.frameEvents] for a [SwingEvent]
///    matching this component's [side] and restarts the 12-frame swing
///    counter (consumed by tests today; sprite swing animations land in M2).
///  * [render] draws: drop shadow, then the character sprite (aspect-scaled
///    to hitbox height, feet-anchored, flipped to match facing), then stun FX.
///  * Drop shadow fades/shrinks as the player rises (scale by 1 − jumpFraction).
///  * When [PlayerView.isStunned], the sprite blinks with a translucent white
///    tint every 8 render frames AND 3 dizzy stars arc above the character.
///
/// One [PlayerComponent] instance is created per [CourtSide].
class PlayerComponent extends Component with HasGameReference<BadmintonGame> {
  /// Creates a component that tracks the player on [side].
  PlayerComponent(this.side);

  /// Which court side this component tracks.
  final CourtSide side;

  // Stun / dizzy.
  static final _dizzyStarPaint = Paint()..color = GamePalette.dizzyStarColor;

  // Stun-blink state: purely cosmetic frame counter.
  int _blinkCounter = 0;

  // Swing animation state.
  int _swingFrame = _kSwingDuration; // >= _kSwingDuration means not swinging

  // Procedural animation state machine (M2-005) and the per-frame facts it
  // needs that aren't in a single PlayerView (movement / vertical direction
  // are derived from the deltas between frames).
  final PlayerAnimator _animator = PlayerAnimator();
  double _prevX = 0;
  double _prevFeetY = 0;
  bool _hasPrev = false;

  /// The current animation state (drives the procedural pose).
  ///
  /// Exposed for testing.
  @visibleForTesting
  PlayerAnimState get animState => _animator.state;

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
        _swingFrame = 0; // restart the swing counter (see header comment)
        break; // only one swing per frame
      }
    }

    // -- Drive the procedural animation state machine (M2-005) ----------------
    // Movement and vertical direction come from the deltas between frames; the
    // rest of the facts are read straight off the player view.
    const moveEps = 0.01;
    final moving = _hasPrev && (pv.x - _prevX).abs() > moveEps;
    // +y is down, so a decreasing feetY means the player is gaining height.
    final rising = _hasPrev && pv.feetY < _prevFeetY - moveEps;
    final swing01 = _swingFrame < _kSwingDuration
        ? _swingFrame / _kSwingDuration
        : -1.0;
    _animator.update(
      dt,
      stunned: pv.isStunned,
      airborne: pv.isAirborne,
      rising: rising,
      moving: moving,
      swing01: swing01,
    );
    _prevX = pv.x;
    _prevFeetY = pv.feetY;
    _hasPrev = true;
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

    // -- 1. Character Sprite --------------------------------------------------
    // Determine the active character type
    final character = side == CourtSide.left
        ? game.leftCharacter
        : game.rightCharacter;

    // Retrieve cached sprite from the game instance
    final Sprite sprite;
    switch (character) {
      case CharacterType.astronautRed:
        sprite = game.astronautRedSprite;
      case CharacterType.mukesh:
        sprite = game.mukeshSprite;
      case CharacterType.jeff:
        sprite = game.jeffSprite;
      case CharacterType.elon:
        sprite = game.elonSprite;
    }

    // Red Astronaut, Mukesh, and Jeff face LEFT by default in their sprites.
    // Elon faces RIGHT by default.
    final spriteFacesLeftByDefault = character != CharacterType.elon;
    final shouldFlip = facingRight == spriteFacesLeftByDefault;

    // Maintain aspect ratio relative to the simulation hitbox height (150).
    final ratio = sprite.src.width / sprite.src.height;
    const visualHeight = kPlayerHitboxHeight; // 150
    final visualWidth = visualHeight * ratio;

    canvas.save();

    // -- Procedural animation pose (M2-005) -----------------------------------
    // Rotate + squash/stretch around the feet pivot (feet stay planted), then
    // the horizontal flip below mirrors it to match facing. bobY shifts the
    // sprite vertically. Applied before the flip so the same pose reads
    // consistently for both facings.
    final pose = _animator.pose;
    canvas
      ..translate(centreX, feetY)
      ..rotate(pose.rotation)
      ..scale(pose.scaleX, pose.scaleY)
      ..translate(-centreX, -feetY);

    // Apply horizontal flip if the facing direction does not match the default
    if (shouldFlip) {
      canvas
        ..translate(centreX, 0)
        ..scale(-1, 1)
        ..translate(-centreX, 0);
    }

    // Position character so that the feet anchor is centered horizontally
    // and sits exactly at feetY. The pose's vertical bob shifts the sprite.
    final left = centreX - visualWidth / 2;
    final top = feetY - visualHeight + pose.bobY;

    // Apply a translucent white tint if stunned and on a blink frame
    final Paint? overridePaint;
    if (pv.isStunned && (_blinkCounter ~/ 8).isEven) {
      overridePaint = Paint()
        ..colorFilter = const ColorFilter.mode(
          Color(0x80FFFFFF),
          BlendMode.srcATop,
        );
    } else {
      overridePaint = null;
    }

    sprite.render(
      canvas,
      position: Vector2(left, top),
      size: Vector2(visualWidth, visualHeight),
      overridePaint: overridePaint,
    );

    canvas.restore();

    // -- 2. Dizzy stars (3 stars arcing above the character while stunned) ----
    if (pv.isStunned) {
      final angleOffset = _blinkCounter * 0.08;
      final orbitCX = centreX;
      // Position orbit above the character height (visualHeight = 150)
      final orbitCY = feetY - visualHeight - 20;
      for (var i = 0; i < _kStarCount; i++) {
        final angle = angleOffset + i * (2 * math.pi / _kStarCount);
        final starX = orbitCX + math.cos(angle) * _kStarOrbitRadius;
        final starY = orbitCY + math.sin(angle) * (_kStarOrbitRadius * 0.5);
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
