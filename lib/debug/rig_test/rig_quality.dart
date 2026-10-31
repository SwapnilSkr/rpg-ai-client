import 'dart:ui' as ui;

import 'rig_frame_stats.dart';
import 'rig_tuning.dart';

/// How much work the rig does per frame.
///
/// `high` is the tuned look. `low` gives back the three things a cheap GPU
/// spends the frame on: triangle count (a coarser mesh), texture sampling
/// (bilinear instead of mip-mapped) and the hair springs (half the columns).
enum RigQuality { high, low }

extension RigQualityTuning on RigQuality {
  /// Side of one mesh cell, canvas pixels.
  double get meshCellPx => this == RigQuality.high
      ? RigTuning.meshCellPxHigh
      : RigTuning.meshCellPxLow;

  ui.FilterQuality get filterQuality => this == RigQuality.high
      ? RigTuning.filterQualityHigh
      : RigTuning.filterQualityLow;

  /// One spring per hair_long vertex column; this is the column count.
  int get hairColumns => this == RigQuality.high
      ? RigTuning.hairColumnsHigh
      : RigTuning.hairColumnsLow;
}

/// Picks a tier once, from the first few seconds of real frames.
///
/// The emulator runs on a desktop GPU and reports 60 fps whatever the rig costs,
/// so the tier cannot be chosen from the development machine. Instead the rig
/// measures its own raster time while it runs: over the first
/// [RigTuning.autoQualityWindowSeconds], a p90 above
/// [RigTuning.autoQualityRasterP90Ms] means this phone will not hold 60 fps and
/// the tier drops once. A manual choice stops the automatic one for good.
class QualityGovernor {
  QualityGovernor({RigQuality start = RigQuality.high}) : _quality = start;

  final List<double> _window = [];
  RigQuality _quality;
  bool _settled = false;
  bool _auto = false;

  RigQuality get quality => _quality;

  /// What the HUD shows; the suffix says the switch was the automatic one, so
  /// the owner knows why the rig looks coarser.
  String get label => _auto ? '${_quality.name} (auto)' : _quality.name;

  /// Pins a tier by hand, overriding auto-select.
  void choose(RigQuality q) {
    _quality = q;
    _settled = true;
    _auto = false;
  }

  /// Feeds one frame's raster time (ms) at [t] seconds since the run started.
  /// Returns true on the one frame where the tier changed.
  bool addRaster(double ms, double t) {
    if (_settled) return false;
    if (t < RigTuning.autoQualityWindowSeconds) {
      _window.add(ms);
      return false;
    }
    _settled = true;
    final p90 = FramePercentiles.of(_window).p90;
    if (p90 > RigTuning.autoQualityRasterP90Ms && _quality != RigQuality.low) {
      _quality = RigQuality.low;
      _auto = true;
      return true;
    }
    return false;
  }
}
