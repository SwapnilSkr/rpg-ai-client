import 'dart:math' as math;

import 'rig_tuning.dart';

/// Blinks at random, 2-6 s apart (start to start), now and then a double.
///
/// The clock is injected: callers pass the current time in seconds to
/// [update], so a test can run an hour of blinks in a loop and the record
/// script can replay the same sequence from the same seed.
class BlinkScheduler {
  BlinkScheduler(this._random) {
    _nextGroup = 1 + 2 * _random.nextDouble();
  }

  final math.Random _random;

  static const double minGap = 2;
  static const double maxGap = 6;
  static const double doubleChance = 0.25;
  static const double _doubleSpacing = 0.12;

  late double _nextGroup;
  final List<double> _blinkStarts = [];

  /// Start time of the most recent blink group, and how many have begun.
  double lastGroupStart = double.negativeInfinity;
  int groups = 0;

  /// Openness at the keyframe `u` (0..1 through the blink): open, closing with
  /// the half-closed frame on the way, a beat shut, opening more slowly.
  static double profile(double u) {
    if (u <= 0 || u >= 1) return 1;
    if (u < 0.38) return 1 - u / 0.38;
    if (u < 0.45) return 0;
    return (u - 0.45) / 0.55;
  }

  /// Eye openness at [t]: 1 open, 0.5 half, 0 closed.
  double update(double t) {
    if (t >= _nextGroup) {
      final start = _nextGroup;
      lastGroupStart = start;
      groups++;
      _blinkStarts
        ..clear()
        ..add(start);
      if (_random.nextDouble() < doubleChance) {
        _blinkStarts.add(start + RigTuning.blinkSeconds + _doubleSpacing);
      }
      _nextGroup = start + minGap + (maxGap - minGap) * _random.nextDouble();
    }
    var open = 1.0;
    for (final s in _blinkStarts) {
      final u = (t - s) / RigTuning.blinkSeconds;
      if (u > 0 && u < 1) open = math.min(open, profile(u));
    }
    return open;
  }
}

/// Eye glances at random: one every 1.5-4 s (start to start), held 0.4-1.2 s.
class GlanceScheduler {
  GlanceScheduler(this._random) {
    _nextStart = minGap + (maxGap - minGap) * _random.nextDouble();
  }

  final math.Random _random;

  static const double minGap = 1.5;
  static const double maxGap = 4;
  static const double minHold = 0.4;
  static const double maxHold = 1.2;

  late double _nextStart;
  double _holdUntil = double.negativeInfinity;
  double _direction = 0;

  double lastStart = double.negativeInfinity;
  int glances = 0;

  /// Target eye direction at [t], -1..1; 0 between glances.
  double update(double t) {
    if (t >= _nextStart) {
      final start = _nextStart;
      lastStart = start;
      glances++;
      final sign = _random.nextBool() ? 1.0 : -1.0;
      _direction = sign * (0.7 + 0.3 * _random.nextDouble());
      _holdUntil = start + minHold + (maxHold - minHold) * _random.nextDouble();
      _nextStart = start + minGap + (maxGap - minGap) * _random.nextDouble();
    }
    return t < _holdUntil ? _direction : 0;
  }
}

/// Smooth value noise: random values on a 1.3 s lattice, eased between.
/// The "little noise" on top of the head drift, so it never quite repeats.
class SmoothNoise {
  SmoothNoise(this._random);

  final math.Random _random;
  static const double _spacing = 1.3;
  final List<double> _lattice = [];

  /// -1..1; `t` must be >= 0.
  double sample(double t) {
    final k = t / _spacing;
    final i = k.floor();
    while (_lattice.length < i + 2) {
      _lattice.add(_random.nextDouble() * 2 - 1);
    }
    final f = k - i;
    final e = f * f * (3 - 2 * f);
    return _lattice[i] + (_lattice[i + 1] - _lattice[i]) * e;
  }
}
