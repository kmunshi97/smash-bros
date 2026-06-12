import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/rules/match_phase.dart';
import 'package:smash_bros/game/badminton_game.dart';
import 'package:smash_bros/game/palette.dart';

// ---------------------------------------------------------------------------
// ActionButtonsComponent — M1-025
//
// Cluster of circular action buttons anchored to the bottom-right of the HUD
// viewport. Buttons fire one-shot press* calls on LocalControlState.
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

/// A single circular action button.
class _ActionButton extends PositionComponent with TapCallbacks {
  _ActionButton({
    required String label,
    required void Function() onPress,
    required Color color,
    required Vector2 position,
  }) : _label = label,
       _onPress = onPress,
       _color = color,
       super(
         position: position,
         size: Vector2.all(_kButtonDiameter),
       );

  String _label;
  void Function() _onPress;
  Color _color;
  bool _pressed = false;

  static final TextPaint _textPaint = TextPaint(
    style: const TextStyle(
      fontSize: 22,
      color: GamePalette.courtLines,
      fontWeight: FontWeight.bold,
    ),
  );

  /// Updates the button's label, action, and colour (used by the serve slot).
  void reconfigure({
    required String label,
    required void Function() onPress,
    required Color color,
  }) {
    _label = label;
    _onPress = onPress;
    _color = color;
  }

  @override
  void onTapDown(TapDownEvent event) {
    _pressed = true;
    _onPress();
  }

  @override
  void onTapUp(TapUpEvent event) {
    _pressed = false;
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    _pressed = false;
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..color = _pressed ? _color.withAlpha(255) : _color.withAlpha(180);
    canvas.drawCircle(
      const Offset(_kButtonRadius, _kButtonRadius),
      _kButtonRadius,
      paint,
    );
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
      color: GamePalette.leftPlayer,
      position: _pos(col: 0, row: 0),
    );
    _primaryButton = _ActionButton(
      label: 'SMASH',
      onPress: game.controls.pressSmash,
      color: GamePalette.rightPlayer,
      position: _pos(col: 1, row: 0),
    );
    _dropButton = _ActionButton(
      label: 'DROP',
      onPress: game.controls.pressDrop,
      color: GamePalette.netTape,
      position: _pos(col: 0, row: 1),
    );
    _clearButton = _ActionButton(
      label: 'CLEAR',
      onPress: game.controls.pressNormal,
      color: GamePalette.leftPlayer,
      position: _pos(col: 1, row: 1),
    );
    await addAll([_jumpButton, _primaryButton, _dropButton, _clearButton]);
    _loaded = true;
  }

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

    if (isServingLeft) {
      _primaryButton.reconfigure(
        label: 'TOSS',
        onPress: game.controls.pressToss,
        color: GamePalette.serveAccent,
      );
    } else {
      _primaryButton.reconfigure(
        label: 'SMASH',
        onPress: game.controls.pressSmash,
        color: GamePalette.rightPlayer,
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
