import 'dart:ui';

import 'package:flame/components.dart';

/// Maps the engine's flat side-view play space onto the drawn perspective
/// court (M2 POC fix).
///
/// ## Why this exists
///
/// The simulation is a flat 2D side view: x is the horizontal court position
/// in `[kCourtLeftBound, kCourtRightBound]`, y is height with the ground at
/// `kGroundY`, the net is a vertical plane at `kNetX`. The stadium art, though,
/// is a *perspective* court whose playable surface is a trapezoid in the lower
/// middle of the screen. Drawing engine coordinates 1:1 made the shuttle land
/// (and players stand) on the art's near edge — so in/out calls and player
/// placement looked wrong even though the engine was correct.
///
/// This is a pure **render-space** affine map applied by the gameplay
/// components (players, shuttle, impact bursts) when they draw:
///
/// ```text
/// screenX = offsetX + scaleX * engineX
/// screenY = offsetY + scaleY * engineY
/// ```
///
/// The engine is untouched, so all the tuned shot trajectories and the in/out
/// rules stay exactly as they were — the projection only changes *where the
/// already-correct result is drawn*, so the visible court matches what the
/// engine judges (the engine's left/right bounds map onto the drawn court
/// edges, and the ground line maps onto the court's mid-depth "centre line"
/// where the players now stand).
///
/// The four parameters are mutable so a debug overlay can calibrate the
/// alignment live against the art (the exact pixel geometry of the perspective
/// floor is easiest to dial in by eye).
class CourtProjection {
  /// Creates a projection with explicit parameters.
  CourtProjection({
    required this.offsetX,
    required this.offsetY,
    required this.scaleX,
    required this.scaleY,
  });

  /// The shipped defaults, estimated from the stadium art. Calibrate live via
  /// the debug court-alignment overlay; these put the engine court onto the
  /// visual court's mid-depth band as a starting point.
  CourtProjection.defaults()
    : offsetX = 117,
      offsetY = -32,
      scaleX = 0.817,
      scaleY = 0.77;

  /// Horizontal offset (screen units) added after scaling.
  double offsetX;

  /// Vertical offset (screen units) added after scaling.
  double offsetY;

  /// Horizontal scale applied to engine x.
  double scaleX;

  /// Vertical scale applied to engine y.
  double scaleY;

  /// Projects an engine-space point to screen space.
  Vector2 apply(double x, double y) =>
      Vector2(offsetX + scaleX * x, offsetY + scaleY * y);

  /// Applies the projection to [canvas] so subsequent draws in engine
  /// coordinates land on the visual court. Wrap the call site in
  /// save()/restore().
  void applyToCanvas(Canvas canvas) {
    canvas
      ..translate(offsetX, offsetY)
      ..scale(scaleX, scaleY);
  }
}
