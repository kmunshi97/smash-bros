import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/rules/match_phase.dart';
import 'package:smash_bros/game/badminton_game.dart';
import 'package:smash_bros/game/palette.dart';

// ---------------------------------------------------------------------------
// ActionButtonsComponent — M1-025 (reskinned M1-027, tray layout M1-036)
//
// Compact bottom-right button cluster with context-sensitive visibility.
//
// ## Layout (rally / returning state)
//
// Three circular buttons hug the bottom-right corner in a tight tray:
//
//   • JUMP & SMASH (primary, radius 60) — innermost, at the corner.
//     Two-line label "JUMP\nSMASH". On tap it calls
//     game.controls.pressJumpSmash(airborne: <derived from view>) — the
//     combo issues a jump + delayed apex smash when grounded, or an
//     immediate smash when already airborne.
//
//   • RALLY (radius 54) — directly left of the primary with a _kGap spacing.
//     Renamed from CLEAR; calls pressNormal.
//
//   • DROP (radius 54) — directly above the primary with a _kGap spacing.
//     Calls pressDrop.
//
// Cluster footprint: primary centre is ~84 units from the corner along the
// 45° diagonal; RALLY and DROP are adjacent. All three are sized for
// comfortable mobile taps (see the radius constants for the dp reasoning).
//
// ## Serving state
//
// When view.phase == MatchPhase.servePending && view.server == CourtSide.left:
//   • ONLY the TOSS button is shown at the primary's corner position.
//   • RALLY and DROP are hidden (removed from the component tree) and
//     non-tappable while serving.
//   • The TOSS button uses hold/release semantics with a charge-arc ring,
//     identical to the pre-M1-036 primary slot.
//   • When the slot flips away from serving, any stale tossHeld is cleared.
//
// ## Serve-slot flip implementation
//
// RALLY and DROP are added/removed from the tree when the serving state flips.
// The flip is detected by diffing _serving across update() calls. Guard:
// add/remove only on the tick of the flip, not every frame.
//
// ## Visual style
//
// Unchanged from M1-027: chunky orange-gold face, bevel highlight, dark
// outline, pressed fill, and charge-arc ring for the TOSS slot. Palette
// entries are unchanged.
//
// ---------------------------------------------------------------------------

// Primary button (JUMP&SMASH / TOSS) radius.
//
// Sizes bumped (M2 POC) for comfortable mobile taps: on a typical landscape
// phone the 1280-unit viewport scales to ~700–900 logical px, so 1 game unit
// is ~0.55–0.7 dp. The old secondary radius (40 → 80-unit diameter ≈ 44–56 dp)
// sat at/below the 48 dp minimum; these larger radii keep RALLY/DROP at
// ~64–80 dp diameter on the same phones.
const double _kPrimaryRadius = 60;
// Secondary button radius (RALLY and DROP).
const double _kSecondaryRadius = 54;

// Gap between adjacent button edges in the tray.
const double _kGap = 12;

// Distance from the corner anchor to the primary button centre along the 45°
// diagonal. This places the primary snugly in the corner. Scaled up with the
// larger primary so the cluster still hugs the corner without clipping it.
const double _kPrimaryOffset = 84;

const double _kEdgeMargin = 12; // gap from viewport edge (before safe-area)
const double _kOutlineWidth = 3;

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
  /// to one-shot semantics (e.g. when the slot flips from TOSS → JUMP&SMASH).
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

    // 5. Label text — supports multi-line via '\n' (rendered as two lines).
    final lines = _label.split('\n');
    if (lines.length == 1) {
      _textPaint.render(
        canvas,
        _label,
        Vector2(_radius, _radius),
        anchor: Anchor.center,
      );
    } else {
      // Two-line label: render each line offset by half a line height above/
      // below centre. fontSize 16 → lineHeight ≈ 18.
      const lineHeight = 9.0;
      for (var i = 0; i < lines.length; i++) {
        final offsetY =
            _radius - lineHeight * (lines.length - 1) / 2 + i * lineHeight * 2;
        _textPaint.render(
          canvas,
          lines[i],
          Vector2(_radius, offsetY),
          anchor: Anchor.center,
        );
      }
    }
  }
}

/// Three action buttons (JUMP&SMASH primary + RALLY + DROP) anchored
/// bottom-right in a compact tray layout. During serving, only the TOSS
/// button is shown.
///
/// ## Rally layout
///
/// The PRIMARY button (radius 48) sits innermost at the corner. RALLY
/// (radius 40) is to its left with a small gap. DROP (radius 40) is above it
/// with a small gap. No button overlaps another; all are ≥ 48dp diameter.
///
/// ## Serve state
///
/// When `game.view.phase == MatchPhase.servePending && game.view.server ==
/// CourtSide.left` (the local player is always left), RALLY and DROP are
/// removed from the component tree. The primary slot reconfigures to TOSS with
/// hold/release + charge-arc semantics. When the serve phase ends, RALLY and
/// DROP are re-added and the primary reverts to JUMP&SMASH.
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

  // Primary button — JUMP&SMASH during rally, TOSS while serving.
  late _ActionButton _primaryButton;
  // Secondary buttons — hidden while serving.
  late _ActionButton _rallyButton; // RALLY (pressNormal), left of primary
  late _ActionButton _dropButton; // DROP (pressDrop), above primary

  bool _loaded = false;

  // Tracks the current serving state to detect flips (avoid add/remove every
  // frame).
  bool _serving = false;
  // Tracks whether the secondary buttons are currently in the tree.
  bool _secondariesMounted = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _primaryButton = _ActionButton(
      label: 'JUMP\nSMASH',
      onPress: _onJumpSmashPress,
      color: GamePalette.buttonFace,
      position: _primaryPos(),
      radius: _kPrimaryRadius,
    );
    _rallyButton = _ActionButton(
      label: 'RALLY',
      onPress: game.controls.pressNormal,
      color: GamePalette.buttonFace,
      position: _rallyPos(),
      radius: _kSecondaryRadius,
    );
    _dropButton = _ActionButton(
      label: 'DROP',
      onPress: game.controls.pressDrop,
      color: GamePalette.buttonFace,
      position: _dropPos(),
      radius: _kSecondaryRadius,
    );

    // Determine initial serving state.
    final view = game.view;
    _serving =
        view.phase == MatchPhase.servePending && view.server == CourtSide.left;

    if (_serving) {
      // Boot directly into serving mode: only primary (as TOSS).
      _reconfigureAsToss();
      await add(_primaryButton);
      _secondariesMounted = false;
    } else {
      // Boot into rally mode: all three buttons.
      await addAll([_primaryButton, _rallyButton, _dropButton]);
      _secondariesMounted = true;
    }
    _loaded = true;
  }

  /// Called when the JUMP&SMASH primary button is tapped.
  void _onJumpSmashPress() {
    final view = game.view;
    final airborne = view.leftPlayer.feetY < kGroundY;
    game.controls.pressJumpSmash(airborne: airborne);
  }

  @override
  void update(double dt) {
    if (!_loaded) return;

    // Re-position the cluster based on current safe area.
    _primaryButton.position = _primaryPos();
    if (_secondariesMounted) {
      _rallyButton.position = _rallyPos();
      _dropButton.position = _dropPos();
    }

    // Detect serving-state flip.
    final view = game.view;
    final isServingLeft =
        view.phase == MatchPhase.servePending && view.server == CourtSide.left;

    if (isServingLeft && !_serving) {
      // Flipping TO serving: remove secondaries, reconfigure primary as TOSS.
      _serving = true;
      if (_secondariesMounted) {
        remove(_rallyButton);
        remove(_dropButton);
        _secondariesMounted = false;
      }
      _reconfigureAsToss();
    } else if (!isServingLeft && _serving) {
      // Flipping AWAY from serving: clear stale toss hold, revert primary to
      // JUMP&SMASH, re-add secondaries.
      _serving = false;
      game.controls.tossHeld = false;
      _reconfigureAsJumpSmash();
      if (!_secondariesMounted) {
        addAll([_rallyButton, _dropButton]);
        _secondariesMounted = true;
      }
    }
  }

  void _reconfigureAsToss() {
    _primaryButton.reconfigure(
      label: 'TOSS',
      onPress: () {}, // unused: onHold takes over
      color: GamePalette.serveAccent,
      onHold: () => game.controls.tossHeld = true,
      onRelease: () => game.controls.tossHeld = false,
      chargeProvider: () => game.view.serveCharge,
    );
  }

  void _reconfigureAsJumpSmash() {
    _primaryButton.reconfigure(
      label: 'JUMP\nSMASH',
      onPress: _onJumpSmashPress,
      color: GamePalette.buttonFace,
    );
  }

  // ---------------------------------------------------------------------------
  // Layout geometry
  // ---------------------------------------------------------------------------

  /// Returns the corner anchor point (bottom-right of the screen) after
  /// applying edge margin and safe-area insets.
  ///
  /// Anchored against the VIRTUAL resolution (kCourtWidth × kCourtHeight):
  /// viewport children render in virtual coordinates, so anchoring against
  /// `camera.viewport.size` (the device size) misplaces the cluster on any
  /// display whose logical size differs from 1280×720 (e.g. desktop windows).
  Vector2 _cornerAnchor() {
    const x = kCourtWidth - _kEdgeMargin;
    const y = kCourtHeight - _kEdgeMargin;
    return Vector2(x - safeArea.right, y - safeArea.bottom);
  }

  /// Returns the top-left position of the PRIMARY button.
  ///
  /// The primary centre sits at [_kPrimaryOffset] from the corner along the
  /// 45° diagonal (up-left).
  Vector2 _primaryPos() {
    final anchor = _cornerAnchor();
    const angle = math.pi / 4; // 45° diagonal
    final cx = anchor.x - math.sin(angle) * _kPrimaryOffset;
    final cy = anchor.y - math.cos(angle) * _kPrimaryOffset;
    return Vector2(cx - _kPrimaryRadius, cy - _kPrimaryRadius);
  }

  /// Returns the top-left position of the RALLY button (directly left of
  /// the primary, edge-to-edge gap of [_kGap]).
  Vector2 _rallyPos() {
    final pPos = _primaryPos();
    // Directly left of the primary:
    final x = pPos.x - _kGap - 2 * _kSecondaryRadius;
    // Vertically centred on the primary:
    final y = pPos.y + _kPrimaryRadius - _kSecondaryRadius;
    return Vector2(x, y);
  }

  /// Returns the top-left position of the DROP button (directly above the
  /// primary, edge-to-edge gap of [_kGap]).
  Vector2 _dropPos() {
    final pPos = _primaryPos();
    // Horizontally centred on the primary:
    final x = pPos.x + _kPrimaryRadius - _kSecondaryRadius;
    // Directly above the primary:
    final y = pPos.y - _kGap - 2 * _kSecondaryRadius;
    return Vector2(x, y);
  }
}
