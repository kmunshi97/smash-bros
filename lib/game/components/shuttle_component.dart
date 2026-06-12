import 'dart:collection';

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

  /// Current shuttle position in game-unit world space.
  Vector2 get position => _position;
  Vector2 _position = Vector2.zero();

  /// Read-only view of the trail buffer (newest first).
  ///
  /// Exposed for testing; do not mutate.
  List<Vector2> get trail => List.unmodifiable(_trail);

  @override
  void update(double dt) {
    final v = game.view;
    _position = Vector2(v.shuttle.x, v.shuttle.y);

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

    // 2. Shuttle circle — drawn last so it sits on top of the trail.
    canvas.drawCircle(
      Offset(_position.x, _position.y),
      kShuttleRadius,
      _shuttlePaint,
    );
  }
}
