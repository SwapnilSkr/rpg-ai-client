import 'dart:collection';

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
