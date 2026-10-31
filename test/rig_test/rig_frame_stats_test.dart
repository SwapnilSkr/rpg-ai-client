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
}
