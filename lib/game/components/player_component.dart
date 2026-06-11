import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/entities/player.dart';
import 'package:smash_bros/engine/render/render_state.dart';
import 'package:smash_bros/game/badminton_game.dart';
import 'package:smash_bros/game/palette.dart';

// ---------------------------------------------------------------------------
// PlayerComponent — M1-023
//
// Draws one player (left or right side) as a filled hitbox rectangle with a
// facing marker and a stun-flash blink overlay. This component carries NO
// game logic and reads ONLY game.view for positional data — it is pure
// presentation.
//
// Tick-order position: rendered after CourtComponent, before ShuttleComponent.
// ---------------------------------------------------------------------------

/// Renders one player avatar (a coloured hitbox rect with a facing notch).
///
/// Responsibilities (pure presentation — no game logic):
///  * Each [update] reads the matching [PlayerView] from [BadmintonGame.view]
///    and sets this component's [position] so the hitbox rect (48 x 80) is
///    anchored at the player's feet (top-left = (x - 24, feetY - 80)).
///  * [render] fills the hitbox with the side's palette colour.
///  * When [PlayerView.isStunned], a stun-flash overlay blinks every 8
///    render frames (frame-count based, not wall-clock — testable and
///    deterministic at the render layer).
///  * A 6 x 6 notch on the facing edge at racquet height marks the direction
///    the player is facing, so sprite-less build is still readable.
///
/// One [PlayerComponent] instance is created per [CourtSide].
class PlayerComponent extends Component with HasGameReference<BadmintonGame> {
  /// Creates a component that tracks the player on [side].
  PlayerComponent(this.side);

  /// Which court side this component tracks.
  final CourtSide side;

  // Pre-built Paint objects.
  late final Paint _bodyPaint = Paint()
    ..color = side == CourtSide.left
        ? GamePalette.leftPlayer
        : GamePalette.rightPlayer;
  static final _stunPaint = Paint()..color = GamePalette.stunFlash;
  static final _facingPaint = Paint()
    ..color = GamePalette.background
    ..style = PaintingStyle.fill;

  // Stun-blink state: purely cosmetic frame counter.
  int _blinkCounter = 0;

  // Cached view snapshot used by render (set in update, used in render).
  PlayerView? _playerView;

  /// Current position of this component in game-unit world space.
  ///
  /// Top-left of the hitbox rect: (x - 24, feetY - 80).
  Vector2 position = Vector2.zero();

  @override
  void update(double dt) {
    final pv = _playerViewFromGame();
    _playerView = pv;
    // Anchor: top-left of the 48x80 hitbox.
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

    final rect = Rect.fromLTWH(
      position.x,
      position.y,
      kPlayerHitboxWidth,
      kPlayerHitboxHeight,
    );

    // 1. Fill player body.
    canvas.drawRect(rect, _bodyPaint);

    // 2. Stun flash overlay — blinks every 8 render frames.
    if (pv.isStunned && (_blinkCounter ~/ 8).isEven) {
      canvas.drawRect(rect, _stunPaint);
    }

    // 3. Facing notch — a 6x6 filled square on the leading edge at racquet
    //    height (~40 units above the feet = 40 units from bottom of hitbox).
    const notchSize = 6.0;
    const racquetHeightFromFeet = 40.0;
    final notchY =
        position.y +
        kPlayerHitboxHeight -
        racquetHeightFromFeet -
        notchSize / 2;
    final notchX = pv.facing == Facing.right
        ? position.x + kPlayerHitboxWidth - notchSize
        : position.x;
    canvas.drawRect(
      Rect.fromLTWH(notchX, notchY, notchSize, notchSize),
      _facingPaint,
    );
  }

  PlayerView _playerViewFromGame() {
    final v = game.view;
    return side == CourtSide.left ? v.leftPlayer : v.rightPlayer;
  }
}
