import 'package:everlore/debug/rig_test/rig_frame_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reports count, average and worst over the last second only', () {
    final s = FrameStats();
    s.add(0, 100); // will fall out of the window
    for (var i = 1; i <= 60; i++) {
      s.add(1000000 + i * 16667, i == 30 ? 40 : 16);
    }
    final snap = s.snapshot(2000000);
    expect(snap.count, 60);
    expect(snap.worstMs, 40);
    expect(snap.avgMs, closeTo(16.4, 0.1));
    expect(s.snapshot(9000000).count, 0);
  });

  test('percentiles pick the nearest rank', () {
    final hundred = [for (var i = 1; i <= 100; i++) i.toDouble()];
    expect(percentile(hundred, 50), 50);
    expect(percentile(hundred, 90), 90);
    expect(percentile(hundred, 99), 99);
    // The caller's list keeps its order.
    final unsorted = [3.0, 1.0, 2.0];
    expect(percentile(unsorted, 50), 2);
    expect(unsorted, [3.0, 1.0, 2.0]);
    // Edges.
    expect(percentile(const [], 90), 0);
    expect(percentile(const [7.0], 99), 7);
    expect(percentile(const [4.0, 9.0], 0), 4);
  });

  test('a run summarises into percentiles and missed deadlines', () {
    final p = FramePercentiles.of(const [10, 10, 20, 20, 40]);
    expect(p.count, 5);
    expect(p.worst, 40);
    expect(p.p50, 20);
    expect(p.p90, 40);
    expect(p.p99, 40);
    expect(p.overBudget, 3, reason: '20, 20 and 40 are over 16.7 ms');
    expect(p.overStutter, 1, reason: 'only 40 is over 33 ms');
    expect(FramePercentiles.of(const []).count, 0);
  });
}
