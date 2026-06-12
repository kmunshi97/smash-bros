import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/rules/match_phase.dart';
import 'package:smash_bros/game/badminton_game.dart';
import 'package:smash_bros/game/palette.dart';

// ---------------------------------------------------------------------------
// ActionButtonsComponent — M1-025 (reskinned M1-027)
//
// Cluster of circular action buttons anchored to the bottom-right of the HUD
// viewport. Buttons fire one-shot press* calls on LocalControlState.
//
// Visual changes in M1-027:
//   • Chunky circular buttons in orange-gold (GamePalette.buttonFace) with a
//     3-unit darker outline, a lighter bevel arc on the top ~45%, and a bold
//     dark-brown label.
//   • TOSS slot retains serveAccent face colour so it still stands out.
//   • Pressed state fills the face with buttonPressed (brighter gold).
//
// Geometry, hit areas, and callbacks are UNCHANGED from M1-025.
//
// Physical-size reasoning
// -----------------------
// At the 1280×720 fixed-resolution viewport on a typical 360dp-logical-width
// landscape phone the scale is ~1.0 dp per game unit. 96-unit circles therefore
// map to ~96 dp — comfortably above the 48dp interaction minimum. On narrower
// phones or tablets with larger letterboxing the effective dp could drop; 96
// game units was chosen so that even at 0.6× downscale the button remains ≥48
// dp physical. See MovePadComponent for the same reasoning.
//
// Serve-slot context sensitivity
// --------------------------------
// The bottom-left slot (primary action) is SMASH during normal rally, but flips
// to TOSS during servePending when the local player is the server (left side).
// The slot's action and label are re-evaluated in update() each frame so the
// flip is instant and requires no special signalling.
// ---------------------------------------------------------------------------

const double _kButtonRadius = 48; // game units — diameter 96 gu
const double _kButtonDiameter = _kButtonRadius * 2;
const double _kButtonSpacing = 10;
const double _kEdgeMargin = 12;
const double _kOutlineWidth = 3;

/// A single circular action button with the new Head-Ball-style look.
///
/// The optional `onHold`/`onRelease` callbacks promote a button to
/// press-and-hold semantics (used by the TOSS slot for the charge-serve).
/// When `onHold` is supplied, `onPress` is ignored — down fires `onHold` and
/// up/cancel fires `onRelease`. The `chargeProvider` callback, if set, is
/// called during render to get the current charge fraction `[0,1]`; a non-zero
/// value draws a gold radial ring around the button proportional to the charge.
class _ActionButton extends PositionComponent with TapCallbacks {
  _ActionButton({
    required String label,
    required void Function() onPress,
    required Color color,
    required Vector2 position,
    void Function()? onHold,
    void Function()? onRelease,
    double Function()? chargeProvider,
  }) : _label = label,
       _onPress = onPress,
       _color = color,
       _onHold = onHold,
       _onRelease = onRelease,
       _chargeProvider = chargeProvider,
       super(
         position: position,
         size: Vector2.all(_kButtonDiameter),
       );

  String _label;
  void Function() _onPress;
  Color _color;
  void Function()? _onHold;
  void Function()? _onRelease;
  double Function()? _chargeProvider;
  bool _pressed = false;

  static final TextPaint _textPaint = TextPaint(
    style: const TextStyle(
      fontSize: 20,
      color: GamePalette.buttonGlyph,
      fontWeight: FontWeight.bold,
    ),
  );

  static final Paint _outlinePaint = Paint()
    ..color = GamePalette.buttonOutline
    ..style = PaintingStyle.stroke
    ..strokeWidth = _kOutlineWidth;

  /// Updates the button's label, action, and colour (used by the serve slot).
  ///
  /// [onHold] / [onRelease] / [chargeProvider] may be null to downgrade back
  /// to one-shot semantics (e.g. when the slot flips from TOSS → SMASH).
  void reconfigure({
    required String label,
    required void Function() onPress,
    required Color color,
    void Function()? onHold,
    void Function()? onRelease,
    double Function()? chargeProvider,
  }) {
    _label = label;
    _onPress = onPress;
    _color = color;
    _onHold = onHold;
    _onRelease = onRelease;
    _chargeProvider = chargeProvider;
  }

  @override
  void onTapDown(TapDownEvent event) {
    _pressed = true;
    if (_onHold != null) {
      _onHold!();
    } else {
      _onPress();
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    _pressed = false;
    _onRelease?.call();
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    _pressed = false;
    _onRelease?.call();
  }

  @override
  void render(Canvas canvas) {
    const centre = Offset(_kButtonRadius, _kButtonRadius);

    // 1. Button face.
    final facePaint = Paint()
      ..color = _pressed ? GamePalette.buttonPressed : _color;
    canvas.drawCircle(centre, _kButtonRadius, facePaint);

    // 2. Bevel highlight — lighter arc on the top ~45% of the circle.
    //    Skip when pressed to reinforce the depth illusion.
    if (!_pressed) {
      final bevelPaint = Paint()
        ..color = GamePalette.buttonBevel.withAlpha(120);
      // Use a clipping arc on the top half.
      final bevelPath = Path()
        ..addArc(
          Rect.fromCircle(center: centre, radius: _kButtonRadius - 3),
          // Start at 200° and sweep through 140° (top-left to top-right arc).
          200 * 3.14159 / 180,
          140 * 3.14159 / 180,
        )
        ..lineTo(centre.dx, centre.dy)
        ..close();
      canvas
        ..save()
        ..clipPath(bevelPath)
        ..drawCircle(centre, _kButtonRadius - 3, bevelPaint)
        ..restore();
    }

    // 3. Dark outline.
    canvas.drawCircle(
      centre,
      _kButtonRadius - _kOutlineWidth / 2,
      _outlinePaint,
    );

    // 4. Charge arc — radial ring fill proportional to charge fraction.
    //    Drawn above the outline so it is clearly visible. Only rendered when
    //    charge > 0 (i.e. during servePending with the button held).
    final charge = _chargeProvider?.call() ?? 0.0;
    if (charge > 0.0) {
      const ringWidth = 6.0;
      const ringRadius = _kButtonRadius - _kOutlineWidth - ringWidth / 2;
      final arcPaint = Paint()
        ..color = GamePalette.serveAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth
        ..strokeCap = StrokeCap.round;
      // Arc starts at top (−π/2) and sweeps clockwise by charge * 2π.
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: ringRadius),
        -math.pi / 2, // start at 12 o'clock
        charge * 2 * math.pi, // sweep
        false,
        arcPaint,
      );
    }

    // 5. Label text.
    _textPaint.render(
      canvas,
      _label,
      Vector2(_kButtonRadius, _kButtonRadius),
      anchor: Anchor.center,
    );
  }
}

/// Four action buttons (JUMP, SMASH/TOSS, DROP, CLEAR) anchored bottom-right.
///
/// The primary slot (centre-left) shows SMASH during normal play and switches
/// to TOSS when `game.view.phase == MatchPhase.servePending` and
/// `game.view.server == CourtSide.left` (the local player is always left).
///
/// [safeArea] is in game units; right + bottom insets offset the anchor.
class ActionButtonsComponent extends Component
    with HasGameReference<BadmintonGame> {
  /// Creates the action button cluster.
  ///
  /// [safeArea] is in game units; bottom and right insets are applied to the
  /// anchor so the buttons clear the device notch / home bar.
  ActionButtonsComponent({required this.safeArea});

  /// Safe-area padding in game units.
  EdgeInsets safeArea;

  // Buttons — laid out in a 2×2 grid:
  //   [JUMP]  [SMASH or TOSS]
  //   [DROP]  [CLEAR]
  late _ActionButton _jumpButton;
  late _ActionButton _primaryButton; // SMASH or TOSS
  late _ActionButton _dropButton;
  late _ActionButton _clearButton;

  bool _loaded = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _jumpButton = _ActionButton(
      label: 'JUMP',
      onPress: game.controls.pressJump,
      color: GamePalette.buttonFace,
      position: _pos(col: 0, row: 0),
    );
    _primaryButton = _ActionButton(
      label: 'SMASH',
      onPress: game.controls.pressSmash,
      color: GamePalette.buttonFace,
      position: _pos(col: 1, row: 0),
    );
    _dropButton = _ActionButton(
      label: 'DROP',
      onPress: game.controls.pressDrop,
      color: GamePalette.buttonFace,
      position: _pos(col: 0, row: 1),
    );
    _clearButton = _ActionButton(
      label: 'CLEAR',
      onPress: game.controls.pressNormal,
      color: GamePalette.buttonFace,
      position: _pos(col: 1, row: 1),
    );
    await addAll([_jumpButton, _primaryButton, _dropButton, _clearButton]);
    _loaded = true;
  }

  // Whether the primary slot is currently showing TOSS (tracked to detect flips).
  bool _slotIsToss = false;

  @override
  void update(double dt) {
    if (!_loaded) return;

    // Re-position the entire cluster based on current safe area.
    _jumpButton.position = _pos(col: 0, row: 0);
    _primaryButton.position = _pos(col: 1, row: 0);
    _dropButton.position = _pos(col: 0, row: 1);
    _clearButton.position = _pos(col: 1, row: 1);

    // Context-sensitive slot: TOSS during servePending (left server), else SMASH.
    final view = game.view;
    final isServingLeft =
        view.phase == MatchPhase.servePending && view.server == CourtSide.left;

    if (isServingLeft && !_slotIsToss) {
      // Slot flipping TO toss — wire hold/release semantics + charge meter.
      _slotIsToss = true;
      _primaryButton.reconfigure(
        label: 'TOSS',
        onPress: () {}, // unused: onHold takes over
        color: GamePalette.serveAccent,
        onHold: () => game.controls.tossHeld = true,
        onRelease: () => game.controls.tossHeld = false,
        chargeProvider: () => game.view.serveCharge,
      );
    } else if (!isServingLeft && _slotIsToss) {
      // Slot flipping AWAY from toss — clear any stale hold and downgrade to
      // one-shot smash. Without this, a finger still down during the serve
      // launch would leave tossHeld = true and bleed into the next tick.
      _slotIsToss = false;
      game.controls.tossHeld = false;
      _primaryButton.reconfigure(
        label: 'SMASH',
        onPress: game.controls.pressSmash,
        color: GamePalette.buttonFace,
      );
    }
  }

  /// Returns the top-left position of the button at grid [col],[row] (0-based),
  /// anchored from the bottom-right viewport corner with safe-area insets.
  ///
  /// Grid layout (col 0 = left, row 0 = top):
  ///   (0,0) JUMP  | (1,0) SMASH
  ///   (0,1) DROP  | (1,1) CLEAR
  Vector2 _pos({required int col, required int row}) {
    final viewportSize = game.camera.viewport.size;
    // Bottom-right corner of the 2×2 grid, offset by margin + safe area.
    final clusterRight = viewportSize.x - _kEdgeMargin - safeArea.right;
    final clusterBottom = viewportSize.y - _kEdgeMargin - safeArea.bottom;

    // Grid origin is the top-left of the full 2×2 cluster.
    final clusterLeft = clusterRight - 2 * _kButtonDiameter - _kButtonSpacing;
    final clusterTop = clusterBottom - 2 * _kButtonDiameter - _kButtonSpacing;

    final x = clusterLeft + col * (_kButtonDiameter + _kButtonSpacing);
    final y = clusterTop + row * (_kButtonDiameter + _kButtonSpacing);
    return Vector2(x, y);
  }
}
