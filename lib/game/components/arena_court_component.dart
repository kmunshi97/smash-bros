import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/game/arena/arena_theme.dart';
import 'package:smash_bros/game/arena/court_geometry.dart';
import 'package:smash_bros/game/badminton_game.dart';

/// Procedurally-drawn court floor + markings (M2 court rework).
///
/// Replaces the baked `stadium_floor.png`. Stacked over the parallax backdrop
/// and *under* the players: a textured/lit perspective floor with the white
/// court lines drawn at exact engine-derived positions via [CourtGeometry],
/// which reuses the live `CourtProjection` so everything stays aligned with the
/// players and shuttle. Swap [ArenaTheme] (its floor colours) to re-skin the
/// arena without touching geometry.
class ArenaCourtComponent extends Component
    with HasGameReference<BadmintonGame> {
  /// Creates the court at the given [priority] within its parent.
  ArenaCourtComponent({required this.theme, super.priority});

  /// The arena look (floor colours, line colour…). The swap point.
  final ArenaTheme theme;

  CourtGeometry get _geo {
    final p = game.courtProjection;
    return CourtGeometry(
      offsetX: p.offsetX,
      offsetY: p.offsetY,
      scaleX: p.scaleX,
      scaleY: p.scaleY,
    );
  }

  @override
  void render(Canvas canvas) {
    final geo = _geo;
    _drawFloor(canvas, geo);
    _drawLines(canvas, geo);
  }

  void _drawFloor(Canvas canvas, CourtGeometry geo) {
    final quad = geo.floorQuad();
    final path = Path()..addPolygon(quad, true);
    final bounds = path.getBounds();

    // Base floor: a vertical gradient (near = lit, far = shaded).
    final floorPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [theme.floorFar, theme.floorNear],
      ).createShader(bounds);
    canvas
      ..save()
      ..clipPath(path)
      ..drawPath(path, floorPaint);

    // Subtle floor texture: a few length-wise planks fading with depth.
    final texPaint = Paint()
      ..color = theme.floorTextureLine
      ..strokeWidth = 1.5;
    for (var i = 1; i < 6; i++) {
      final depth = -1 + 2 * (i / 6);
      canvas.drawLine(
        geo.point(kCourtLeftBound, depth),
        geo.point(kCourtRightBound, depth),
        texPaint,
      );
    }

    // Lighting: a soft radial highlight rising from the near-centre court.
    final lightCenter = geo.point(kNetX, 0.4);
    final lightPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          (lightCenter.dx - bounds.center.dx) / (bounds.width / 2),
          (lightCenter.dy - bounds.center.dy) / (bounds.height / 2),
        ),
        radius: 0.9,
        colors: const [Color(0x33FFFFFF), Color(0x00000000)],
      ).createShader(bounds);
    canvas
      ..drawRect(bounds, lightPaint)
      ..restore();
  }

  void _drawLines(Canvas canvas, CourtGeometry geo) {
    final shadow = Paint()
      ..color = theme.lineShadow
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final line = Paint()
      ..color = theme.lineColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    void seg((Offset, Offset) ab) {
      // Shadow first (offset down for a lit-from-above feel), then the line.
      canvas
        ..drawLine(ab.$1.translate(0, 2), ab.$2.translate(0, 2), shadow)
        ..drawLine(ab.$1, ab.$2, line);
    }

    // Sidelines (far + near) frame the court.
    seg(geo.farSideline());
    seg(geo.nearSideline());
    // Length-wise lines: baselines, short-service lines, and the net line.
    for (final xe in CourtGeometry.lineXs) {
      seg(geo.verticalLine(xe));
    }
    // Centre service lines: only between each short-service line and the
    // baseline, along the play line (real badminton centre line).
    seg((geo.point(kCourtLeftBound, 0), geo.point(kShortServeLineLeft, 0)));
    seg((geo.point(kShortServeLineRight, 0), geo.point(kCourtRightBound, 0)));
  }
}

/// Procedurally-drawn net (M2 court rework), replacing `stadium_net.png`.
///
/// Drawn over the players (high priority) so the shuttle and characters pass
/// behind it near the centre. In this side view the net plane is edge-on at
/// `kNetX`, so it is rendered as a central vertical mesh ribbon between two
/// depth posts, capped by a white cord, with shading and a floor shadow.
class NetComponent extends Component with HasGameReference<BadmintonGame> {
  /// Creates the net; [priority] keeps it in front of players.
  NetComponent({required this.theme, super.priority = 10});

  /// The arena look (net cord / mesh / post colours).
  final ArenaTheme theme;

  // Half-width (screen px) of the visible net ribbon at the centre line.
  static const double _kRibbonHalf = 9;
  static const double _kPostHalf = 4;

  CourtGeometry get _geo {
    final p = game.courtProjection;
    return CourtGeometry(
      offsetX: p.offsetX,
      offsetY: p.offsetY,
      scaleX: p.scaleX,
      scaleY: p.scaleY,
    );
  }

  @override
  void render(Canvas canvas) {
    final geo = _geo;
    final (farBase, nearBase) = geo.netBase();
    final (farTop, nearTop) = geo.netCordTops();

    // 1. Floor shadow under the net.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(geo.centerX, nearBase.dy),
        width: _kRibbonHalf * 4,
        height: 10,
      ),
      Paint()..color = const Color(0x55000000),
    );

    // 2. Mesh ribbon between the cord run (top) and base run (bottom).
    final ribbon = Path()
      ..moveTo(farTop.dx - _kRibbonHalf, farTop.dy)
      ..lineTo(nearTop.dx + _kRibbonHalf, nearTop.dy)
      ..lineTo(nearBase.dx + _kRibbonHalf, nearBase.dy)
      ..lineTo(farBase.dx - _kRibbonHalf, farBase.dy)
      ..close();
    canvas
      ..save()
      ..clipPath(ribbon)
      ..drawPath(
        ribbon,
        Paint()..color = theme.netMesh.withValues(alpha: 0.18),
      );
    _drawMeshHatch(canvas, farTop, nearBase);
    canvas.restore();

    // 3. Posts at the far and near ends, shaded for volume.
    _drawPost(canvas, farBase, farTop);
    _drawPost(canvas, nearBase, nearTop);

    // 4. Cord (white tape) along the top.
    canvas.drawLine(
      farTop,
      nearTop,
      Paint()
        ..color = theme.netCord
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawMeshHatch(Canvas canvas, Offset topRef, Offset baseRef) {
    final mesh = Paint()
      ..color = theme.netMesh
      ..strokeWidth = 1;
    // A light diamond hatch across the ribbon's vertical extent.
    final top = topRef.dy;
    final bottom = baseRef.dy;
    for (var y = top; y <= bottom; y += 7) {
      canvas.drawLine(
        Offset(_geo.centerX - _kRibbonHalf, y),
        Offset(_geo.centerX + _kRibbonHalf, y),
        mesh,
      );
    }
  }

  void _drawPost(Canvas canvas, Offset base, Offset top) {
    final rect = Rect.fromLTRB(
      base.dx - _kPostHalf,
      top.dy,
      base.dx + _kPostHalf,
      base.dy,
    );
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [theme.postLight, theme.postDark],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      paint,
    );
  }
}
