// ignore_for_file: avoid_print // tool script — print is the output mechanism
import 'dart:math' as math;

const kGroundY = 600.0;
const kNetX = 640.0;
const kNetTopY = 470.0;
const kShuttleGravity = 0.14;
const kShuttleDragCoefficient = 0.001;
const kShuttleMaxVelocity = 20.0;

({double landingX, double netCrossingY, int ticks}) simulate(
  double startX,
  double startY,
  double speed,
  double angleDeg,
) {
  final angle = angleDeg * math.pi / 180.0;
  var vx = math.cos(angle) * speed;
  var vy = -math.sin(angle) * speed;
  var x = startX;
  var y = startY;
  var crossedNet = false;
  var netY = double.nan;
  for (var t = 0; t < 5000; t++) {
    final prevX = x;
    final prevY = y;
    final spd2 = math.sqrt(vx * vx + vy * vy);
    final drag = kShuttleDragCoefficient * spd2;
    vx -= drag * vx;
    vy -= drag * vy;
    vy += kShuttleGravity;
    final spd = math.sqrt(vx * vx + vy * vy);
    if (spd > kShuttleMaxVelocity) {
      final sc = kShuttleMaxVelocity / spd;
      vx *= sc;
      vy *= sc;
    }
    x += vx;
    y += vy;
    if (!crossedNet && prevX < kNetX && x >= kNetX) {
      final frac = (kNetX - prevX) / (x - prevX);
      netY = prevY + frac * (y - prevY);
      crossedNet = true;
    }
    if (y >= kGroundY) {
      final frac = (kGroundY - prevY) / (y - prevY);
      return (
        landingX: prevX + frac * (x - prevX),
        netCrossingY: crossedNet ? netY : double.nan,
        ticks: t + 1,
      );
    }
  }
  return (landingX: x, netCrossingY: netY, ticks: 5000);
}

void main() {
  const startX = 210.0;
  const startY = 490.0;

  print('=== Trying higher speeds at 43° (need MAX > 1100):');
  for (var speed = 14.0; speed <= 20.0; speed += 0.5) {
    final r = simulate(startX, startY, speed, 43);
    final clears = !r.netCrossingY.isNaN && r.netCrossingY < 460;
    final inMax = r.landingX >= 1100 && r.landingX <= 1240;
    print(
      '${speed.toStringAsFixed(1)}@43°: land=${r.landingX.toStringAsFixed(1)}, netY=${r.netCrossingY.isNaN ? "n/a" : r.netCrossingY.toStringAsFixed(1)}, clears=$clears, inMax=$inMax, ticks=${r.ticks}',
    );
  }

  print(
    '\n=== Different angles — find where both MIN and MAX land bands work:',
  );
  for (final angle in [38.0, 40.0, 43.0, 45.0, 48.0]) {
    print('\nAngle $angle°:');
    for (var speed = 9.0; speed <= 19.0; speed += 1.0) {
      final r = simulate(startX, startY, speed, angle);
      final clears = !r.netCrossingY.isNaN && r.netCrossingY < 460;
      final inMin = r.landingX >= 840 && r.landingX <= 960;
      final inMax = r.landingX >= 1100 && r.landingX <= 1240;
      if (clears) {
        print(
          '  speed=${speed.toStringAsFixed(1)}: land=${r.landingX.toStringAsFixed(1)}, netY=${r.netCrossingY.toStringAsFixed(1)}, MIN=$inMin, MAX=$inMax, ticks=${r.ticks}',
        );
      }
    }
  }
}
