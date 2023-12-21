import 'dart:math';
import 'dart:ui';

const Map<int, Offset> cuadrants = const {
  1: Offset(0.5, 0.5),
  2: Offset(-0.5, 0.5),
  3: Offset(-0.5, -0.5),
  4: Offset(0.5, -0.5),
};

const pi_0_5 = pi * 0.5;
const pi_2_5 = pi * 2.5;
const pi_2 = pi * 2;

class SpinVelocity {
  final double height;
  final double width;

  double get width_0_5 => width / 2;
  double get height_0_5 => height / 2;

  SpinVelocity({required this.height, required this.width});

  double getVelocity(Offset position, Offset pps) {
    var cuadrantIndex = _getCuadrantFromOffset(position);
    var cuadrant = cuadrants[cuadrantIndex];
    return (cuadrant!.dx * pps.dx) + (cuadrant.dy * pps.dy);
  }

  double offsetToRadians(Offset position) {
    var a = position.dx - width_0_5;
    var b = height_0_5 - position.dy;
    var angle = atan2(b, a);
    return _normalizeAngle(angle);
  }

  int _getCuadrantFromOffset(Offset p) => p.dx > width_0_5
      ? (p.dy > height_0_5 ? 2 : 1)
      : (p.dy > height_0_5 ? 3 : 4);

  double _normalizeAngle(double angle) => angle > 0
      ? (angle > pi_0_5 ? (pi_2_5 - angle) : (pi_0_5 - angle))
      : pi_0_5 - angle;

  bool contains(Offset p) => Size(width, height).contains(p);
}

class NonUniformCircularMotion {
  final double resistance;

  NonUniformCircularMotion({required this.resistance});

  double get acceleration => resistance * -7 * pi;

  double distance(double velocity, double time) =>
      (velocity * time) + (0.5 * acceleration * pow(time, 2));

  double duration(double velocity) => -velocity / acceleration;

  double modulo(double angle) => angle % (2 * pi);

  double anglePerDivision(int dividers) => (2 * pi) / dividers;
}

double pixelsPerSecondToRadians(double pps) {
  return (pps * 2 * pi) / 1000;
}
