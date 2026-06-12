import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/rules/match_phase.dart';
import 'package:smash_bros/game/badminton_game.dart';
import 'package:smash_bros/game/palette.dart';

// ---------------------------------------------------------------------------
// ActionButtonsComponent — M1-025 (reskinned M1-027, arc layout M1-035v)
//
// Cluster of circular action buttons anchored to the bottom-right corner in a
// quarter-circle FAN rather than a 2×2 grid. The PRIMARY button (SMASH/TOSS,
// radius 48) sits innermost; JUMP (radius 40) is above it; CLEAR (radius 40)
// is to its left; DROP (radius 36) is on the diagonal between JUMP and CLEAR.
//
// Visual: same chunky circular style (orange-gold, bevel, outline) as M1-027.
//   • TOSS slot retains serveAccent face colour and charge-arc ring.
//   • Pressed state fills the face with buttonPressed (brighter gold).
//
// Serve-slot context sensitivity (UNCHANGED from M1-025/027):
//   Primary slot shows SMASH during normal rally, TOSS during servePending
//   when the local player (left) is serving. Hold/release semantics and the
//   charge arc are preserved exactly.
//
// Physical-size reasoning
// -----------------------
// At the 1280×720 fixed-resolution viewport on a typical landscape phone the
// scale is ~1.0 dp per game unit. The primary button (radius 48 = diameter 96)
// is comfortably above the 48dp interaction minimum. Smaller arc buttons
// (radius 36–40) are still above 48dp diameter. See MovePadComponent for the
// same reasoning.
// ---------------------------------------------------------------------------

// Primary button (SMASH/TOSS) radius — innermost of the fan.
const double _kPrimaryRadius = 48;
// Secondary button radii.
const double _kJumpRadius = 40;
const double _kClearRadius = 40;
const double _kDropRadius = 36;

// Arc spacing — distance from the corner anchor to each button centre.
// PRIMARY sits closest to the corner; arc buttons fan outward.
const double _kPrimaryOffset = 70; // distance from corner to primary centre
const double _kArcOffset = 170; // distance from corner to arc button centres
// (DROP uses the same _kArcOffset as JUMP and CLEAR; no separate constant needed.)

const double _kEdgeMargin = 12; // gap from viewport edge (before safe-area)
const double _kOutlineWidth = 3;

// Fan angles (measured from the corner — the fan opens toward the court
// interior, i.e. upward and to the left from the bottom-right corner).
// Angle 0 = straight up (negative y), angle 90° = straight left (negative x).
// JUMP = 0° (straight up from corner), CLEAR = 90° (straight left).
// DROP = 45° (diagonal between them).
const double _kJumpAngle = 0; // straight up
const double _kClearAngle = math.pi / 2; // straight left
const double _kDropAngle = math.pi / 4; // 45° diagonal

/// A single circular action button with the Head-Ball-style look.
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
    required double radius,
    void Function()? onHold,
    void Function()? onRelease,
    double Function()? chargeProvider,
  }) : _label = label,
       _onPress = onPress,
       _color = color,
       _onHold = onHold,
       _onRelease = onRelease,
       _chargeProvider = chargeProvider,
       _radius = radius,
       super(
         position: position,
         size: Vector2.all(radius * 2),
       );

  String _label;
  void Function() _onPress;
  Color _color;
  void Function()? _onHold;
  void Function()? _onRelease;
  double Function()? _chargeProvider;
  bool _pressed = false;
  final double _radius;

  static final TextPaint _textPaint = TextPaint(
    style: const TextStyle(
      fontSize: 18,
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
    final centre = Offset(_radius, _radius);

    // 1. Button face.
    final facePaint = Paint()
      ..color = _pressed ? GamePalette.buttonPressed : _color;
    canvas.drawCircle(centre, _radius, facePaint);

    // 2. Bevel highlight — lighter arc on the top ~45% of the circle.
    //    Skip when pressed to reinforce the depth illusion.
    if (!_pressed) {
      final bevelPaint = Paint()
        ..color = GamePalette.buttonBevel.withAlpha(120);
      // Use a clipping arc on the top half.
      final bevelPath = Path()
        ..addArc(
          Rect.fromCircle(center: centre, radius: _radius - 3),
          // Start at 200° and sweep through 140° (top-left to top-right arc).
          200 * 3.14159 / 180,
          140 * 3.14159 / 180,
        )
        ..lineTo(centre.dx, centre.dy)
        ..close();
      canvas
        ..save()
        ..clipPath(bevelPath)
        ..drawCircle(centre, _radius - 3, bevelPaint)
        ..restore();
    }

    // 3. Dark outline.
    canvas.drawCircle(
      centre,
      _radius - _kOutlineWidth / 2,
      _outlinePaint,
    );

    // 4. Charge arc — radial ring fill proportional to charge fraction.
    //    Drawn above the outline so it is clearly visible.
    final charge = _chargeProvider?.call() ?? 0.0;
    if (charge > 0.0) {
      const ringWidth = 6.0;
      final ringRadius = _radius - _kOutlineWidth - ringWidth / 2;
      final arcPaint = Paint()
        ..color = GamePalette.serveAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth
        ..strokeCap = StrokeCap.round;
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
      Vector2(_radius, _radius),
      anchor: Anchor.center,
    );
  }
}

/// Four action buttons (JUMP, SMASH/TOSS, DROP, CLEAR) anchored bottom-right
/// in a quarter-circle fan layout.
///
/// The PRIMARY button (SMASH/TOSS, radius 48) sits innermost at the
/// bottom-right corner. JUMP (radius 40) is above it, CLEAR (radius 40) is
/// to its left, and DROP (radius 36) sits diagonally between them at 45°.
///
/// The primary slot shows SMASH during normal play and switches to TOSS when
/// `game.view.phase == MatchPhase.servePending` and
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

  // Buttons — fan layout from bottom-right corner.
  late _ActionButton _jumpButton; // straight up from corner
  late _ActionButton _primaryButton; // innermost (SMASH or TOSS)
  late _ActionButton _dropButton; // 45° diagonal
  late _ActionButton _clearButton; // straight left from corner

  bool _loaded = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _primaryButton = _ActionButton(
      label: 'SMASH',
      onPress: game.controls.pressSmash,
      color: GamePalette.buttonFace,
      position: _primaryPos(),
      radius: _kPrimaryRadius,
    );
    _jumpButton = _ActionButton(
      label: 'JUMP',
      onPress: game.controls.pressJump,
      color: GamePalette.buttonFace,
      position: _arcPos(_kJumpAngle, _kJumpRadius),
      radius: _kJumpRadius,
    );
    _clearButton = _ActionButton(
      label: 'CLEAR',
      onPress: game.controls.pressNormal,
      color: GamePalette.buttonFace,
      position: _arcPos(_kClearAngle, _kClearRadius),
      radius: _kClearRadius,
    );
    _dropButton = _ActionButton(
      label: 'DROP',
      onPress: game.controls.pressDrop,
      color: GamePalette.buttonFace,
      position: _arcPos(_kDropAngle, _kDropRadius),
      radius: _kDropRadius,
    );
    await addAll([_jumpButton, _primaryButton, _dropButton, _clearButton]);
    _loaded = true;
  }

  // Whether the primary slot is currently showing TOSS (tracked to detect flips).
  bool _slotIsToss = false;

  @override
  void update(double dt) {
    if (!_loaded) return;

    // Re-position the cluster based on current safe area.
    _primaryButton.position = _primaryPos();
    _jumpButton.position = _arcPos(_kJumpAngle, _kJumpRadius);
    _clearButton.position = _arcPos(_kClearAngle, _kClearRadius);
    _dropButton.position = _arcPos(_kDropAngle, _kDropRadius);

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
      // one-shot smash.
      _slotIsToss = false;
      game.controls.tossHeld = false;
      _primaryButton.reconfigure(
        label: 'SMASH',
        onPress: game.controls.pressSmash,
        color: GamePalette.buttonFace,
      );
    }
  }

  /// Returns the top-left position of the PRIMARY button, anchored to the
  /// bottom-right corner with safe-area insets.
  ///
  /// The primary button sits at _kPrimaryOffset distance from the corner anchor
  /// along the 45° diagonal (innermost of the fan).
  Vector2 _primaryPos() {
    final anchor = _cornerAnchor();
    // Primary sits along the 45° diagonal from the corner.
    const angle = math.pi / 4; // 45° (diagonal up-left from corner)
    final cx = anchor.x - math.sin(angle) * _kPrimaryOffset;
    final cy = anchor.y - math.cos(angle) * _kPrimaryOffset;
    return Vector2(cx - _kPrimaryRadius, cy - _kPrimaryRadius);
  }

  /// Returns the top-left position of an arc button at [angle] (from vertical,
  /// 0 = up, π/2 = left) with the given [radius].
  Vector2 _arcPos(double angle, double radius) {
    final anchor = _cornerAnchor();
    // Arc buttons fan at _kArcOffset from the corner anchor.
    final cx = anchor.x - math.sin(angle) * _kArcOffset;
    final cy = anchor.y - math.cos(angle) * _kArcOffset;
    return Vector2(cx - radius, cy - radius);
  }

  /// Returns the bottom-right corner anchor (the point the fan radiates from),
  /// in viewport coordinates, after applying edge margin and safe-area insets.
  Vector2 _cornerAnchor() {
    final viewportSize = game.camera.viewport.size;
    final x = viewportSize.x - _kEdgeMargin - safeArea.right;
    final y = viewportSize.y - _kEdgeMargin - safeArea.bottom;
    return Vector2(x, y);
  }
}
