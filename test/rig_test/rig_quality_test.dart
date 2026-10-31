import 'dart:ui' as ui;

import 'package:everlore/debug/rig_test/rig_quality.dart';
import 'package:everlore/debug/rig_test/rig_tuning.dart';
import 'package:flutter_test/flutter_test.dart';

/// Feeds [ms] as the raster time of every frame for [seconds] at 60 fps,
/// counting the times the tier changed.
int _feed(QualityGovernor g, double ms, double seconds, {double from = 0}) {
  var changes = 0;
  for (var t = from; t < from + seconds; t += 1 / 60) {
    if (g.addRaster(ms, t)) changes++;
  }
  return changes;
}

void main() {
  test('a slow first 3 s drops to low exactly once', () {
    final g = QualityGovernor();
    expect(g.quality, RigQuality.high);
    expect(_feed(g, 30, RigTuning.autoQualityWindowSeconds + 1), 1);
    expect(g.quality, RigQuality.low);
    expect(g.label, contains('auto'), reason: 'the HUD says why it is coarser');
    // The decision is final: another 10 s of slow frames changes nothing.
    expect(_feed(g, 60, 10, from: 20), 0);
    expect(g.quality, RigQuality.low);
  });

  test('a fast first 3 s stays high', () {
    final g = QualityGovernor();
    expect(_feed(g, 6, RigTuning.autoQualityWindowSeconds + 1), 0);
    expect(g.quality, RigQuality.high);
    expect(_feed(g, 60, 5, from: 10), 0, reason: 'judged once, not continually');
    expect(g.quality, RigQuality.high);
    expect(g.label, 'high');
  });

  test('the threshold is 12 ms of raster p90', () {
    final slow = QualityGovernor();
    expect(_feed(slow, RigTuning.autoQualityRasterP90Ms + 3,
        RigTuning.autoQualityWindowSeconds + 0.1), 1);
    expect(slow.quality, RigQuality.low);

    final ok = QualityGovernor();
    expect(_feed(ok, RigTuning.autoQualityRasterP90Ms,
        RigTuning.autoQualityWindowSeconds + 0.1), 0);
    expect(ok.quality, RigQuality.high, reason: '12 is not above 12');
  });

  test('a manual choice overrides auto-select', () {
    final g = QualityGovernor();
    g.choose(RigQuality.low);
    expect(g.label, 'low');
    expect(_feed(g, 30, 10, from: 20), 0);
    expect(g.quality, RigQuality.low);
    g.choose(RigQuality.high);
    expect(_feed(g, 30, 10, from: 40), 0);
    expect(g.quality, RigQuality.high);
  });

  test('the low tier really is cheaper', () {
    expect(RigQuality.low.meshCellPx, greaterThan(RigQuality.high.meshCellPx));
    expect(RigQuality.high.filterQuality, ui.FilterQuality.medium);
    expect(RigQuality.low.filterQuality, ui.FilterQuality.low);
    expect(RigQuality.low.hairColumns * 2, RigQuality.high.hairColumns);
  });
}
