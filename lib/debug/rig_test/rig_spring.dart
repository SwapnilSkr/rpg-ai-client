/// A damped spring chasing a target: `x'' = k (target - x) - c x'`.
///
/// Used for the hair (underdamped, so it overshoots and settles) and, critically
/// damped, to smooth every head and eye input so a step in a target becomes an
/// ease rather than a jump.
class Spring {
  Spring({
    required this.stiffness,
    required this.damping,
    this.position = 0,
    this.velocity = 0,
  });

  /// Damping ratio 1: the fastest approach with no overshoot, `omega` rad/s.
  factory Spring.critical(double omega, {double position = 0}) => Spring(
        stiffness: omega * omega,
        damping: 2 * omega,
        position: position,
      );

  final double stiffness;
  final double damping;
  double position;
  double velocity;

  /// Substeps stay under this so a stiff spring stays stable at a slow frame
  /// rate (semi-implicit Euler needs `omega * h < 2`).
  static const double _maxSubstep = 1 / 240;

  void step(double target, double dt) {
    if (dt <= 0) return;
    final n = (dt / _maxSubstep).ceil().clamp(1, 60);
    final h = dt / n;
    for (var i = 0; i < n; i++) {
      velocity += (stiffness * (target - position) - damping * velocity) * h;
      position += velocity * h;
    }
  }

  void reset([double to = 0]) {
    position = to;
    velocity = 0;
  }
}
