import 'dart:collection';

import 'rig_tuning.dart';

/// The [p]th percentile (0..100) of [values] by nearest rank. Sorts a copy, so
/// the caller's list keeps its order.
double percentile(Iterable<double> values, double p) {
  final v = values.toList()..sort();
  if (v.isEmpty) return 0;
  final rank = ((p / 100) * v.length).ceil().clamp(1, v.length);
  return v[rank - 1];
}

/// One run's frame times summarised for the benchmark: the three percentiles
/// that describe a distribution rather than an average (one bad frame barely
/// moves p50 and clearly moves p99), and how many frames missed the two
/// deadlines a 60 fps budget cares about.
class FramePercentiles {
  FramePercentiles._(
    this.count,
    this.p50,
    this.p90,
    this.p99,
    this.worst,
    this.overBudget,
    this.overStutter,
  );

  factory FramePercentiles.of(Iterable<double> ms) {
    final v = ms.toList();
    var overBudget = 0;
    var overStutter = 0;
    var worst = 0.0;
    for (final t in v) {
      if (t > RigTuning.frameBudgetMs) overBudget++;
      if (t > RigTuning.stutterMs) overStutter++;
      if (t > worst) worst = t;
    }
    return FramePercentiles._(
      v.length,
      percentile(v, 50),
      percentile(v, 90),
      percentile(v, 99),
      worst,
      overBudget,
      overStutter,
    );
  }

  final int count;
  final double p50;
  final double p90;
  final double p99;
  final double worst;
  final int overBudget;
  final int overStutter;
}

/// Frame times over a sliding window (one second), for the FPS readout.
class FrameStats {
  FrameStats({this.windowMicros = 1000000});

  final int windowMicros;
  final Queue<({int at, double ms})> _samples = Queue();

  /// Records a frame that finished at [atMicros] and took [ms].
  void add(int atMicros, double ms) {
    _samples.addLast((at: atMicros, ms: ms));
    _trim(atMicros);
  }

  void _trim(int now) {
    while (_samples.isNotEmpty && now - _samples.first.at > windowMicros) {
      _samples.removeFirst();
    }
  }

  ({int count, double avgMs, double worstMs}) snapshot(int nowMicros) {
    _trim(nowMicros);
    if (_samples.isEmpty) return (count: 0, avgMs: 0, worstMs: 0);
    var sum = 0.0;
    var worst = 0.0;
    for (final s in _samples) {
      sum += s.ms;
      if (s.ms > worst) worst = s.ms;
    }
    return (count: _samples.length, avgMs: sum / _samples.length, worstMs: worst);
  }
}
