import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/game/badminton_game.dart';
import 'package:smash_bros/game/palette.dart';

// ---------------------------------------------------------------------------
// MovePadComponent — M1-025 (reskinned M1-027)
//
// Renders two side-by-side d-pad buttons (◀ ▶) anchored to the bottom-left
// of the HUD viewport. Touch events drive moveLeft / moveRight hold flags on
// the game's LocalControlState.
//
// Visual changes in M1-027:
//   • Chunky orange-gold rounded-rect buttons with a 3-unit darker outline,
//     a lighter bevel highlight on the top half, and dark-brown glyph text.
//   • Pressed state fills the whole face with the brighter buttonPressed tone.
//
// Geometry, hit areas, and callbacks are UNCHANGED from M1-025.
//
// Physical-size reasoning
// -----------------------
// The Flame camera is configured for a fixed 1280×720 game-unit space. On a
// typical phone (~360dp logical width in landscape) that maps to roughly
// 0.28 dp per game unit (360/1280). A 110-game-unit pad therefore covers
// ≈30.8 dp. That is still below the 48dp minimum for interactive targets, so
// we size generously: each pad is 110 game units wide × 90 game units tall,
// reaching ≈30 dp on a narrow phone BUT the viewport letterboxes onto the full
// physical width — in practice the game area fills ≈ full phone width in
// landscape giving ≈1.0 dp per game unit, so 110 units → 110 dp, well above
// the 48 dp floor. The comment is left here so any resolution change triggers a
// deliberate revisit.
// ---------------------------------------------------------------------------

const _kPadWidth = 110.0;
const _kPadHeight = 90.0;
const _kPadSpacing = 8.0;
const _kPadCornerRadius = 16.0;
const _kEdgeMargin = 12.0; // gap from viewport edge (before safe-area offset)
const _kOutlineWidth = 3.0;
const _kBevelInset = 4.0; // inset of the bevel highlight rect

/// A single rounded-rect pad that tracks one directional hold.
class _DirPad extends PositionComponent with TapCallbacks {
  _DirPad({
    required this.label,
    required this.onDown,
    required this.onUp,
    required Vector2 position,
  }) : super(
         position: position,
         size: Vector2(_kPadWidth, _kPadHeight),
       );

  final String label;
  final void Function() onDown;
  final void Function() onUp;

  bool _pressed = false;

  // Button face paint (normal and pressed are computed in render to keep code clear).
  static final Paint _outlinePaint = Paint()
    ..color = GamePalette.buttonOutline
    ..style = PaintingStyle.stroke
    ..strokeWidth = _kOutlineWidth;

  static final Paint _bevelPaint = Paint()..color = GamePalette.buttonBevel;

  late final TextPaint _textPaint = TextPaint(
    style: const TextStyle(
      fontSize: 38,
      color: GamePalette.buttonGlyph,
      fontWeight: FontWeight.bold,
    ),
  );

  static final RRect _outerRRect = RRect.fromLTRBR(
    0,
    0,
    _kPadWidth,
    _kPadHeight,
    const Radius.circular(_kPadCornerRadius),
  );

  static final RRect _bevelRRect = RRect.fromLTRBR(
    _kBevelInset,
    _kBevelInset,
    _kPadWidth - _kBevelInset,
    _kPadHeight * 0.45,
    const Radius.circular(_kPadCornerRadius - 2),
  );

  @override
  void onTapDown(TapDownEvent event) {
    _pressed = true;
    onDown();
  }

  @override
  void onTapUp(TapUpEvent event) {
    _pressed = false;
    onUp();
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    _pressed = false;
    onUp();
  }

  @override
  void render(Canvas canvas) {
    // 1. Button face — brighter when pressed.
    final facePaint = Paint()
      ..color = _pressed ? GamePalette.buttonPressed : GamePalette.buttonFace;
    canvas.drawRRect(_outerRRect, facePaint);

    // 2. Bevel highlight — lighter top-arc (skipped when pressed for depth).
    if (!_pressed) {
      canvas.drawRRect(_bevelRRect, _bevelPaint);
    }

    // 3. Dark outline.
    canvas.drawRRect(_outerRRect, _outlinePaint);

    // 4. Glyph (arrow label).
    _textPaint.render(
      canvas,
      label,
      Vector2(_kPadWidth / 2, _kPadHeight / 2),
      anchor: Anchor.center,
    );
  }
}

/// Two side-by-side d-pad pads (◀ ▶) added to the camera viewport (HUD space).
///
/// Anchored to the bottom-left corner. Pass an [EdgeInsets] of safe-area
/// padding (in game units) to offset away from notches/home-bar.
class MovePadComponent extends Component with HasGameReference<BadmintonGame> {
  /// Creates the d-pad cluster.
  ///
  /// [safeArea] is in game units; bottom and left insets are applied to the
  /// anchor position so the buttons clear the device notch / home bar.
  MovePadComponent({required this.safeArea});

  /// Safe-area padding in game units. Updated each frame via
  /// [BadmintonGame.safeArea]; applied on the next [update] call.
  EdgeInsets safeArea;

  late _DirPad _leftPad;
  late _DirPad _rightPad;
  bool _loaded = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _leftPad = _DirPad(
      label: '◀',
      position: _leftPos(),
      onDown: () => game.controls.moveLeft = true,
      onUp: () => game.controls.moveLeft = false,
    );
    _rightPad = _DirPad(
      label: '▶',
      position: _rightPos(),
      onDown: () => game.controls.moveRight = true,
      onUp: () => game.controls.moveRight = false,
    );
    await addAll([_leftPad, _rightPad]);
    _loaded = true;
  }

  @override
  void update(double dt) {
    if (!_loaded) return;
    _leftPad.position = _leftPos();
    _rightPad.position = _rightPos();
  }

  // Anchored against the VIRTUAL resolution (kCourtHeight): viewport children
  // render in virtual coordinates, so anchoring against
  // `camera.viewport.size` (the device size) floats the pad off the
  // bottom-left corner on any display whose logical size differs from
  // 1280×720 (e.g. desktop windows).
  Vector2 _leftPos() {
    final x = _kEdgeMargin + safeArea.left;
    final y = kCourtHeight - _kEdgeMargin - safeArea.bottom - _kPadHeight;
    return Vector2(x, y);
  }

  Vector2 _rightPos() {
    final p = _leftPos();
    return Vector2(p.x + _kPadWidth + _kPadSpacing, p.y);
  }
}
