import 'dart:collection';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/rules/match_phase.dart';
import 'package:smash_bros/game/badminton_game.dart';
import 'package:smash_bros/game/palette.dart';

// ---------------------------------------------------------------------------
// ShuttleComponent — M1-024
//
// Draws the shuttle as a filled circle plus a fading cosmetic trail. This
// component carries NO game logic and reads ONLY game.view — it is pure
// presentation.
//
// Tick-order position: rendered last (highest z-order) so the shuttle appears
// on top of court and players.
// ---------------------------------------------------------------------------

/// Renders the shuttle: a circle of radius [kShuttleRadius] with a fading
/// cosmetic trail.
///
/// Responsibilities (pure presentation — no game logic):
///  * Each [update] reads [BadmintonGame.view] for the current shuttle position
///    and the match phase to decide whether to accumulate trail positions.
///  * The trail is a fixed-capacity (24) ring buffer of [Vector2] positions.
///    Each [update] pushes the current shuttle position onto the front of the
///    buffer. The buffer is cleared when the phase is not [MatchPhase.inPlay]
///    so a parked serve shuttle never shows a stale trail.
///  * [render] draws the trail as filled circles of decreasing radius and
///    opacity from newest (index 0) to oldest (index 23), then draws the
///    shuttle itself on top.
///
/// Trail sampling is render-frame based (cosmetic only — no tick-exact
/// requirement). The capacity is bounded at [_trailCapacity] = 24.
class ShuttleComponent extends Component with HasGameReference<BadmintonGame> {
  /// Maximum number of trail positions retained.
  static const int _trailCapacity = 24;

  // Fixed-capacity ring buffer of trail positions (newest at index 0).
  final Queue<Vector2> _trail = Queue<Vector2>();

  // Pre-built paints.
  static final _shuttlePaint = Paint()..color = GamePalette.shuttle;

  /// Outline stroke paint — dark grey ring drawn around the shuttle body so
  /// the white shuttle stays readable against the light cream ad wall and
  /// pale grandstand backdrop of the daylight stadium.
  static final _shuttleOutlinePaint = Paint()
    ..color = GamePalette.shuttleOutline
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.8;

  /// Feather-skirt fill — a faint off-white so the white cork still reads as
  /// the brightest part of the shuttlecock.
  static final _featherPaint = Paint()..color = const Color(0xFFEDEDED);

  /// Thin grey ribs suggesting individual feathers.
  static final _featherRibPaint = Paint()
    ..color = GamePalette.shuttleOutline.withValues(alpha: 0.5)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;

  /// Current shuttle position in game-unit world space.
  Vector2 get position => _position;
  Vector2 _position = Vector2.zero();

  // Velocity-derived flight orientation (radians), smoothed across frames so a
  // momentary zero-velocity tick doesn't snap the shuttlecock. Cosmetic.
  double _angle = -math.pi / 2; // default: cork pointing up
  // Free-running cosmetic clock for the feather flutter.
  double _clock = 0;

  /// Read-only view of the trail buffer (newest first).
  ///
  /// Exposed for testing; do not mutate.
  List<Vector2> get trail => List.unmodifiable(_trail);

  @override
  void update(double dt) {
    final v = game.view;
    _position = Vector2(v.shuttle.x, v.shuttle.y);
    _clock += dt;

    // Orient the shuttlecock cork-first along its velocity. Below a small speed
    // (a parked serve) keep the last orientation so it doesn't spin from noise.
    final vx = v.shuttle.vx;
    final vy = v.shuttle.vy;
    if (vx * vx + vy * vy > 1) {
      _angle = math.atan2(vy, vx);
    }

    if (v.phase == MatchPhase.inPlay) {
      // Push current position to the front of the trail buffer.
      _trail.addFirst(_position.clone());
      // Trim oldest entries to maintain the capacity cap.
      while (_trail.length > _trailCapacity) {
        _trail.removeLast();
      }
    } else {
      // Clear stale trail whenever not actively in play.
      _trail.clear();
    }
  }

  @override
  void render(Canvas canvas) {
    final v = game.view;

    // Project shadow, trail and shuttlecock from engine space onto the drawn
    // perspective court (M2 POC), matching the players.
    canvas.save();
    game.courtProjection.applyToCanvas(canvas);

    // 0. Ground shadow — only during inPlay (landing-spot depth cue).
    //    A small dark ellipse at (shuttle.x, kGroundY); size and opacity scale
    //    with height above the ground: shadow is largest/darkest when the
    //    shuttle is near the ground, smallest/faintest when high up.
    if (v.phase == MatchPhase.inPlay) {
      final heightAboveGround = (kGroundY - _position.y).clamp(0.0, 400.0);
      final shadowFraction = (heightAboveGround / 400.0).clamp(0.0, 1.0);
      // Shadow opacity: 0.5 when on the ground, 0.05 when at max height.
      final shadowAlpha = 0.05 + (1.0 - shadowFraction) * 0.45;
      final shadowW = 16.0 + (1.0 - shadowFraction) * 8.0;
      final shadowH = 6.0 + (1.0 - shadowFraction) * 4.0;
      final shadowPaint = Paint()
        ..color = const Color(0xFF000000).withValues(alpha: shadowAlpha);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(_position.x, kGroundY - shadowH / 2),
          width: shadowW,
          height: shadowH,
        ),
        shadowPaint,
      );
    }

    // 1. Trail — drawn oldest-to-newest so newer segments paint over older.
    //    We iterate in reverse (oldest first) for correct layering.
    final trailList = _trail.toList();
    final count = trailList.length;
    for (var i = count - 1; i >= 0; i--) {
      // age 0 = newest (most opaque, largest), age count-1 = oldest (most faded).
      final age = i.toDouble();
      final fraction = count > 1 ? age / (count - 1) : 0.0;
      final alpha = (1 - fraction) * 0.4; // max 40% opacity
      final radius = kShuttleRadius * (0.3 + 0.7 * (1 - fraction));

      final paint = Paint()
        ..color = GamePalette.shuttle.withValues(alpha: alpha);

      canvas.drawCircle(
        Offset(trailList[i].x, trailList[i].y),
        radius,
        paint,
      );
    }

    // 2. Shuttlecock — a cork nose + flared feather skirt, oriented cork-first
    //    along the flight direction with a subtle feather flutter. Drawn in a
    //    local frame (cork toward +x) then rotated to [_angle].
    _renderShuttlecock(canvas);

    // Close the court projection opened at the top of render().
    canvas.restore();
  }

  /// Draws the shuttlecock at [_position], rotated so the cork leads along the
  /// flight direction. Local frame: +x is the direction of travel (cork nose),
  /// −x is the trailing feather skirt.
  void _renderShuttlecock(Canvas canvas) {
    // Geometry scaled off the collision radius so the silhouette stays
    // proportional if the radius is ever retuned.
    const r = kShuttleRadius;
    const corkR = r * 0.9; // cork nose radius
    const noseX = r * 1.4; // cork centre, ahead of the body
    const skirtBackX = -r * 2.2; // tail of the feather skirt
    const skirtBaseX = r * 0.2; // where the skirt meets the cork
    const skirtHalf = r * 1.7; // half-width of the skirt mouth

    // Feather flutter: the skirt mouth breathes a little and the whole cock
    // wobbles a couple of degrees about the flight line.
    final flutter = math.sin(_clock * 14) * (r * 0.18);
    final wobble = math.sin(_clock * 9) * 0.06;

    canvas
      ..save()
      ..translate(_position.x, _position.y)
      ..rotate(_angle + wobble);

    // Feather skirt — a trapezoid mouth from the cork base out to the tail.
    final half = skirtHalf + flutter;
    final skirt = Path()
      ..moveTo(skirtBaseX, -r * 0.5)
      ..lineTo(skirtBackX, -half)
      ..lineTo(skirtBackX, half)
      ..lineTo(skirtBaseX, r * 0.5)
      ..close();
    canvas
      ..drawPath(skirt, _featherPaint)
      ..drawPath(skirt, _shuttleOutlinePaint);

    // Feather ribs for a bit of detail (cork base → evenly spaced tail points).
    for (var i = -2; i <= 2; i++) {
      final ty = (half * i) / 2;
      canvas.drawLine(
        const Offset(skirtBaseX, 0),
        Offset(skirtBackX, ty),
        _featherRibPaint,
      );
    }

    // Cork nose — a filled dome with an outline, drawn last so it sits on top.
    canvas
      ..drawCircle(const Offset(noseX, 0), corkR, _shuttlePaint)
      ..drawCircle(const Offset(noseX, 0), corkR, _shuttleOutlinePaint)
      ..restore();
  }
}
