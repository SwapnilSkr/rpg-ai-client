import 'dart:math' as math;

import 'rig_tuning.dart';

/// The talking mouth: while a line plays, a new random opening is picked every
/// 90-160 ms, now and then a closed beat, smoothed so it flaps rather than
/// flickers.
///
/// The smoothed [value] is never an alpha: two lip drawings at partial opacity
/// would be two pairs of lips on one mouth. [DiscreteMouth] turns the raw beat
/// into the open/shut drawing that is actually painted.
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

/// The mouth as the painter sees it: one open drawing or one shut drawing,
/// never a fade, and each held at least [RigTuning.mouthMinHoldSeconds].
///
/// The flapper's beat already runs slower than that hold, so in a steady line
/// this gate passes every change through on the frame it lands. The hold exists
/// for the edges: a line starting or ending, or a flapper restarted in the
/// middle of a syllable, must not put a shape on screen for one frame.
class DiscreteMouth {
  bool _open = false;

  /// Time since the last switch. It starts at the minimum because the hold
  /// applies between shapes: the first switch has waited long enough already.
  double _held = RigTuning.mouthMinHoldSeconds;

  /// True when the open-mouth drawing is the one on screen.
  bool get open => _open;

  void update(double dt, {required bool rawOpen}) {
    _held += dt;
    if (rawOpen == _open || _held < RigTuning.mouthMinHoldSeconds) return;
    _open = rawOpen;
    _held = 0;
  }
}
