import 'dart:ui';

import 'package:smash_bros/engine/constants.dart';

/// Pure perspective geometry for the procedurally-drawn court (M2 court rework).
///
/// ## Coordinate model
///
/// The simulation is a flat side view: engine x runs along the court *length*
/// (`kCourtLeftBound`..`kCourtRightBound`) with the net at `kNetX`, and players
/// stand on the ground line `kGroundY`. [CourtGeometry] reuses the game's
/// affine `CourtProjection` (its four numbers are passed in) to place that
/// **play line** on screen, then fans the floor out into *depth* so it reads as
/// a 3D court while staying pixel-aligned with the players and shuttle (which
/// draw through the same projection).
///
/// `depth` is `-1` at the far sideline (top, foreshortened), `0` on the play
/// line where the players stand, and `+1` at the near sideline (bottom). At a
/// given depth the court is scaled about the centre line by
/// `1 + depth*perspectiveGain` (near is wider, far is narrower) and shifted in
/// y by `depth*depthSpan`.
///
/// Every method is pure and returns screen-space [Offset]s, so the geometry is
/// unit-testable without a running game.
class CourtGeometry {
  /// Builds geometry from the projection's affine params plus the depth shaping.
  const CourtGeometry({
    required this.offsetX,
    required this.offsetY,
    required this.scaleX,
    required this.scaleY,
    this.perspectiveGain = 0.22,
    this.depthSpan = 120,
  });

  /// `CourtProjection` affine params (`screen = offset + scale*engine`).
  final double offsetX;
  final double offsetY;
  final double scaleX;
  final double scaleY;

  /// How much wider the near edge is than the play line (and narrower the far).
  final double perspectiveGain;

  /// Screen-y distance from the play line to each sideline.
  final double depthSpan;

  /// Screen x of engine [xe] on the play line.
  double _playX(double xe) => offsetX + scaleX * xe;

  /// Screen y of the play line (engine ground).
  double get _playY => offsetY + scaleY * kGroundY;

  /// Screen x of the court centre (the net line).
  double get centerX => _playX(kNetX);

  /// Projects engine [xe] at [depth] (-1 far .. 0 play .. +1 near) to screen.
  Offset point(double xe, double depth) {
    final widen = 1 + depth * perspectiveGain;
    final px = centerX + (_playX(xe) - centerX) * widen;
    return Offset(px, _playY + depth * depthSpan);
  }

  /// The floor quad: far-left, far-right, near-right, near-left (clockwise).
  List<Offset> floorQuad() => [
    point(kCourtLeftBound, -1),
    point(kCourtRightBound, -1),
    point(kCourtRightBound, 1),
    point(kCourtLeftBound, 1),
  ];

  /// A line at constant engine x, spanning far→near (a sideline-crossing mark).
  (Offset, Offset) verticalLine(double xe) => (point(xe, -1), point(xe, 1));

  /// The far sideline (top edge of the floor).
  (Offset, Offset) farSideline() =>
      (point(kCourtLeftBound, -1), point(kCourtRightBound, -1));

  /// The near sideline (bottom edge of the floor).
  (Offset, Offset) nearSideline() =>
      (point(kCourtLeftBound, 1), point(kCourtRightBound, 1));

  /// The engine x of every length-wise court line, in draw order.
  static const List<double> lineXs = [
    kCourtLeftBound,
    kShortServeLineLeft,
    kNetX,
    kShortServeLineRight,
    kCourtRightBound,
  ];

  /// Net height in screen pixels at the play line (ground → net top via the
  /// projection's y scale).
  double get netHeightPx => scaleY * (kGroundY - kNetTopY);

  /// The net's base run far→near along the centre line.
  (Offset, Offset) netBase() => (point(kNetX, -1), point(kNetX, 1));

  /// The two net-post tops (far, near) — the cord connects them. The near post
  /// is a touch taller than the far one for perspective.
  (Offset farTop, Offset nearTop) netCordTops() {
    final farBase = point(kNetX, -1);
    final nearBase = point(kNetX, 1);
    return (
      farBase.translate(0, -netHeightPx * 0.85),
      nearBase.translate(0, -netHeightPx * 1.05),
    );
  }
}
