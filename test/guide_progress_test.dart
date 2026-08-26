import 'package:everlore/core/guide/guide_progress.dart';
import 'package:flutter_test/flutter_test.dart';

GuideFlowProgress _p(
  GuideStatus status, {
  int step = 0,
  int version = 1,
  DateTime? at,
}) => GuideFlowProgress(
  version: version,
  step: step,
  status: status,
  at: at ?? DateTime(2026, 1, 1),
);

void main() {
  group('flow record merge', () {
    test('a finished arc survives a stale device that only started it', () {
      final done = _p(GuideStatus.done, step: 4, at: DateTime(2026, 1, 1));
      // Second device wrote later, but knows less.
      final started = _p(GuideStatus.seen, at: DateTime(2026, 6, 1));

      expect(done.mergeWith(started).status, GuideStatus.done);
      expect(started.mergeWith(done).status, GuideStatus.done);
    });

    test('skipping is not undone by another device re-seeing it', () {
      final skipped = _p(GuideStatus.skipped, step: 1);
      final seen = _p(GuideStatus.seen, step: 3);
      expect(seen.mergeWith(skipped).status, GuideStatus.skipped);
    });

    test('furthest step wins', () {
      expect(_p(GuideStatus.seen, step: 1).mergeWith(_p(GuideStatus.seen, step: 5)).step, 5);
      expect(_p(GuideStatus.seen, step: 5).mergeWith(_p(GuideStatus.seen, step: 1)).step, 5);
    });

    test('a newer flow version supersedes the older record entirely', () {
      final old = _p(GuideStatus.done, step: 9);
      final fresh = _p(GuideStatus.seen, version: 2);
      final merged = old.mergeWith(fresh);
      expect(merged.version, 2);
      // The old terminal status described a different arc; it must not carry
      // over and suppress the replay.
      expect(merged.status, GuideStatus.seen);
      expect(merged.step, 0);
    });
  });

  group('progress record', () {
    test('device and account records union rather than overwrite', () {
      final local = GuideProgress(flows: {'play.first': _p(GuideStatus.seen, step: 2)});
      final remote = GuideProgress(flows: {'chronicle': _p(GuideStatus.done, step: 4)});

      final merged = local.mergeWith(remote);
      expect(merged.flows.keys, containsAll(['play.first', 'chronicle']));
      expect(merged['chronicle']!.status, GuideStatus.done);
    });

    test('opt-out is sticky across devices', () {
      const quiet = GuideProgress(optOut: true);
      const loud = GuideProgress();
      expect(quiet.mergeWith(loud).optOut, isTrue);
      expect(loud.mergeWith(quiet).optOut, isTrue);
    });

    test('withFlow folds instead of overwriting, so a late write cannot regress', () {
      final record = GuideProgress(flows: {'play.first': _p(GuideStatus.done, step: 4)});
      // A slow server response landing after the arc already finished.
      final after = record.withFlow('play.first', _p(GuideStatus.seen, step: 1));
      expect(after['play.first']!.status, GuideStatus.done);
      expect(after['play.first']!.step, 4);
    });

    test('skip count drives the one-time silence offer', () {
      final none = GuideProgress(flows: {'a': _p(GuideStatus.seen)});
      expect(none.skipCount, 0);
      final two = GuideProgress(
        flows: {
          'a': _p(GuideStatus.skipped),
          'b': _p(GuideStatus.skipped),
          'c': _p(GuideStatus.done),
        },
      );
      expect(two.skipCount, 2);
    });

    test('round-trips through json', () {
      final record = GuideProgress(flows: {'play.first': _p(GuideStatus.done, step: 4)});
      final revived = GuideProgress.fromJson(record.toJson());
      expect(revived['play.first']!.status, GuideStatus.done);
      expect(revived['play.first']!.step, 4);
    });

    test('a corrupt or absent payload yields an empty record, not a throw', () {
      expect(GuideProgress.fromJson(null).flows, isEmpty);
      expect(GuideProgress.fromJson({'bad': 'not-a-map'}).flows, isEmpty);
    });
  });
}
