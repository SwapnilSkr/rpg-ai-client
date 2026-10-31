import 'dart:math' as math;

import 'rig_tuning.dart';

/// The lid phase of a blink. Cartoon and anime eyes are discrete drawings: a
/// blink steps through these holds instead of fading between them, and these
/// are the only states there are.
enum BlinkPhase { open, half, closed }

/// Blinks at random, 2-6 s apart (start to start), now and then a double.
///
/// The clock is injected: callers pass the current time in seconds to
/// [phase], so a test can run an hour of blinks in a loop and the record
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

  /// The lid phase at [t].
  ///
  /// [withHalf] is false on an expression face: its patch carries its own eyes,
  /// so the blink is one shut of [RigTuning.blinkClosedHoldExpression] and the
  /// neutral half-lid drawing never appears.
  BlinkPhase phase(double t, {bool withHalf = true}) {
    if (t >= _nextGroup) {
      final start = _nextGroup;
      lastGroupStart = start;
      groups++;
      _blinkStarts
        ..clear()
        ..add(start);
      if (_random.nextDouble() < doubleChance) {
        _blinkStarts.add(start + RigTuning.blinkNeutralSeconds + _doubleSpacing);
      }
      _nextGroup = start + minGap + (maxGap - minGap) * _random.nextDouble();
    }
    var out = BlinkPhase.open;
    for (final s in _blinkStarts) {
      final p = _phaseAt(t - s, withHalf);
      // A double's two blinks never overlap; take the more closed if they ever
      // do, so the lids can never lift for a frame inside a blink.
      if (p.index > out.index) out = p;
    }
    return out;
  }

  static BlinkPhase _phaseAt(double u, bool withHalf) {
    if (!withHalf) {
      return u >= 0 && u < RigTuning.blinkClosedHoldExpression
          ? BlinkPhase.closed
          : BlinkPhase.open;
    }
    if (u < 0) return BlinkPhase.open;
    if (u < RigTuning.blinkHalfHold) return BlinkPhase.half;
    if (u < RigTuning.blinkHalfHold + RigTuning.blinkClosedHold) {
      return BlinkPhase.closed;
    }
    if (u < RigTuning.blinkNeutralSeconds) return BlinkPhase.half;
    return BlinkPhase.open;
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
  ///
  /// Glances belong to the neutral face, whose eye layers match its eyeballs.
  /// While [enabled] is false no glance starts and a running one is cut, but
  /// the clock keeps ticking, so coming back to neutral does not release a
  /// backlog of glances at once.
  double update(double t, {bool enabled = true}) {
    if (t >= _nextStart) {
      final start = _nextStart;
      if (enabled) {
        lastStart = start;
        glances++;
        final sign = _random.nextBool() ? 1.0 : -1.0;
        _direction = sign * (0.7 + 0.3 * _random.nextDouble());
        _holdUntil = start + minHold + (maxHold - minHold) * _random.nextDouble();
      }
      _nextStart = start + minGap + (maxGap - minGap) * _random.nextDouble();
    }
    return enabled && t < _holdUntil ? _direction : 0;
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
