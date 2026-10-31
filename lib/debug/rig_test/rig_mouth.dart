import 'dart:math' as math;

/// The talking mouth: while a line plays, a new random opening is picked every
/// 90-160 ms, now and then a closed beat, smoothed so it flaps rather than
/// flickers.
class MouthFlapper {
  MouthFlapper(this._random);

  final math.Random _random;

  static const double minInterval = 0.09;
  static const double maxInterval = 0.16;
  static const double minOpen = 0.3;

  /// Chance that the next beat is a closed gap (never twice running).
  static const double gapChance = 0.2;

  /// Smoothing time constant, s. Short enough to read as syllables.
  static const double _tau = 0.035;

  bool _talking = false;
  double _target = 0;
  double _value = 0;
  double _untilNext = 0;

  bool get talking => _talking;

  /// Smoothed openness, always within 0..1.
  double get value => _value;

  /// The raw beat: 0 in a gap or when silent. The paper doll uses it as an
  /// on/off switch so both rigs flap on the same timings.
  double get target => _target;
  bool get isOpen => _target > 0;

  void start() {
    _talking = true;
    _untilNext = 0;
  }

  /// The line is over: close the mouth.
  void stop() {
    _talking = false;
    _target = 0;
  }

  void update(double dt) {
    if (_talking) {
      _untilNext -= dt;
      while (_untilNext <= 0) {
        if (_target > 0 && _random.nextDouble() < gapChance) {
          _target = 0;
        } else {
          _target = minOpen + (1 - minOpen) * _random.nextDouble();
        }
        _untilNext += minInterval + (maxInterval - minInterval) * _random.nextDouble();
      }
    }
    _value += (_target - _value) * (1 - math.exp(-dt / _tau));
    _value = _value.clamp(0.0, 1.0);
  }

  void reset() {
    _talking = false;
    _target = 0;
    _value = 0;
    _untilNext = 0;
  }
}
