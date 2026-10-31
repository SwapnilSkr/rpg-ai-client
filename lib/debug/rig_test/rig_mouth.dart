import 'dart:math' as math;

import 'rig_tuning.dart';

/// The talking mouth: two drawings, open and shut, alternating while a line
/// plays.
///
/// A beat is one held openness: an open one, then a shut one, then an open one.
/// The alternation is in the machine, not in the odds: re-rolling an open beat
/// straight into another open beat (what an independent chance per beat does)
/// joins two beats into one long open hold, and an open mouth held for a second
/// reads as frozen, not as speech. Each beat's length comes from its own span in
/// [RigTuning], drawn from the flapper's seeded [math.Random] so a recorded clip
/// is identical every run.
///
/// The smoothed [value] is never an alpha: two lip drawings at partial opacity
/// would be two pairs of lips on one mouth. [DiscreteMouth] turns the raw beat
/// into the open/shut drawing that is actually painted.
class MouthFlapper {
  MouthFlapper(this._random);

  final math.Random _random;

  /// Smoothing time constant, s. Short enough to read as syllables.
  static const double _tau = 0.035;

  bool _talking = false;

  /// Which way the beat machine is; every beat flips it, so no two beats of the
  /// same state can touch.
  bool _beatOpen = false;

  double _target = 0;
  double _value = 0;
  double _untilNext = 0;

  bool get talking => _talking;

  /// Smoothed openness, always within 0..1.
  double get value => _value;

  /// The raw beat: 0 in a shut beat or when silent, the beat's openness when
  /// open. The paper doll uses it as an on/off switch so both rigs flap on the
  /// same timings.
  double get target => _target;
  bool get isOpen => _target > 0;

  void start() {
    _talking = true;
    // A line opens on a syllable: the first beat is an open one, and it lands on
    // the first frame of the line.
    _beatOpen = false;
    _target = 0;
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
        _beatOpen = !_beatOpen;
        if (_beatOpen) {
          _target = RigTuning.mouthMinOpen +
              (1 - RigTuning.mouthMinOpen) * _random.nextDouble();
          _untilNext += _span(
            RigTuning.mouthOpenMinSeconds,
            RigTuning.mouthOpenMaxSeconds,
          );
        } else {
          _target = 0;
          _untilNext += _random.nextDouble() < RigTuning.mouthPauseChance
              ? _span(
                  RigTuning.mouthPauseMinSeconds,
                  RigTuning.mouthPauseMaxSeconds,
                )
              : _span(
                  RigTuning.mouthShutMinSeconds,
                  RigTuning.mouthShutMaxSeconds,
                );
        }
      }
    }
    _value += (_target - _value) * (1 - math.exp(-dt / _tau));
    _value = _value.clamp(0.0, 1.0);
  }

  double _span(double min, double max) =>
      min + (max - min) * _random.nextDouble();

  void reset() {
    _talking = false;
    _beatOpen = false;
    _target = 0;
    _value = 0;
    _untilNext = 0;
  }
}

/// The mouth as the painter sees it: one open drawing or one shut drawing,
/// never a fade, and each held at least [RigTuning.mouthMinHoldSeconds].
///
/// The shortest beat is [RigTuning.mouthShutMinSeconds], which is below the
/// hold, so a very short shut beat is stretched to the hold rather than shown
/// as a glitch. The hold matters at the edges too: a line starting or ending, or
/// a flapper restarted in the middle of a syllable, must not put a shape on
/// screen for one frame.
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
