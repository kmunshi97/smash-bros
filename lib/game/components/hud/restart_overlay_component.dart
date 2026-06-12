import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:smash_bros/engine/rules/match_phase.dart';
import 'package:smash_bros/game/badminton_game.dart';

// ---------------------------------------------------------------------------
// RestartOverlayComponent — M1-029
//
// A full-screen tap target that calls game.restartMatch() when the match is
// over. During active play (servePending / inPlay / pointScored / preMatch)
// the component is fully tap-transparent so touch controls work normally.
//
// Design rules enforced here:
//   * Uses component-level TapCallbacks, NOT game-level TapDetector mixin
//     (they conflict with component TapCallbacks in Flame).
//   * containsLocalPoint returns false while not in matchOver — makes the
//     component invisible to the hit-test, so all taps fall through to the
//     touch buttons underneath.
//   * Seeds are derived from DateTime.now().millisecondsSinceEpoch in the
//     game layer — allowed here (lib/game/ is NOT lib/engine/).
// ---------------------------------------------------------------------------

/// Full-screen tap overlay that triggers a match restart (M1-029).
///
/// Added to `camera.viewport` in [BadmintonGame.onLoad]. During active play
/// [containsLocalPoint] always returns `false`, making the component invisible
/// to Flame's hit-test and leaving touch controls fully operational.
///
/// Once the phase reaches [MatchPhase.matchOver], [containsLocalPoint] returns
/// `true` for any point, and a tap calls [BadmintonGame.restartMatch] with
/// seeds derived from wall-clock time — never from the engine's PRNG.
class RestartOverlayComponent extends PositionComponent
    with HasGameReference<BadmintonGame>, TapCallbacks {
  /// Creates the overlay; call [onGameResize] to size it to the viewport.
  RestartOverlayComponent() : super(priority: 100);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Fill the entire viewport so any tap during matchOver is captured.
    this.size = size;
  }

  /// Returns `true` only while the phase is [MatchPhase.matchOver].
  ///
  /// During all other phases the component is invisible to Flame's hit-test,
  /// so touch controls (move pad, action buttons) receive their taps normally.
  @override
  bool containsLocalPoint(Vector2 point) {
    return game.view.phase == MatchPhase.matchOver;
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (game.view.phase != MatchPhase.matchOver) return;
    // Derive both seeds from the same wall-clock base, offset so they differ.
    // Wall-clock use is intentional and allowed here — lib/game/ is outside
    // lib/engine/, and this is the presentation layer, not the simulation.
    final base = DateTime.now().millisecondsSinceEpoch;
    game.restartMatch(seed: base, aiSeed: base ^ 0xDEADBEEF);
  }
}
