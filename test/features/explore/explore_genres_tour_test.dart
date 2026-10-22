import 'package:everlore/core/guide/guide_controller.dart';
import 'package:everlore/core/guide/guide_flows.dart';
import 'package:everlore/core/guide/guide_ids.dart';
import 'package:everlore/core/guide/guide_progress.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  group('Explore tour & exploreGenres once-only rule', () {
    setUp(() async {
      await guide.onSignedOut();
      GuideController.arcGap = Duration.zero;
    });

    tearDown(() async {
      await guide.onSignedOut();
      GuideController.arcGap = Duration.zero;
    });

    test('arrival beats explain genres and filter without interface jargon', () {
      final tabsBeat = GuideFlows.arrival.beats.firstWhere(
        (b) => b.anchors.contains(GuideIds.discoverTabs),
      );
      expect(tabsBeat.title, 'Shelves of the Archive');
      expect(tabsBeat.body, contains('For You gathers a little of everything'));
      expect(tabsBeat.body, contains('Each shelf after it keeps one kind of tale'));

      final filterBeat = GuideFlows.arrival.beats.firstWhere(
        (b) => b.anchors.contains(GuideIds.discoverFilter),
      );
      expect(filterBeat.title, 'Narrowing the Search');
      expect(filterBeat.body, contains('Seek only worlds or only souls'));

      final banned = RegExp(r'\b(tap|taps|tapping|button|screen|click)\b', caseSensitive: false);
      expect(banned.hasMatch('${tabsBeat.title} ${tabsBeat.body}'), isFalse);
      expect(banned.hasMatch('${filterBeat.title} ${filterBeat.body}'), isFalse);
    });

    test('exploreGenres arc explains shelves and filters together in Chronicler register', () {
      expect(GuideFlows.all, contains(GuideFlows.exploreGenres));
      expect(GuideFlows.exploreGenres.route, '/discover');
      expect(GuideFlows.exploreGenres.beats, hasLength(1));

      final beat = GuideFlows.exploreGenres.beats.single;
      expect(beat.anchors, contains(GuideIds.discoverFilter));
      expect(beat.title, 'Shelves of the Archive');
      expect(beat.body, contains('Each shelf keeps one kind of tale'));
      expect(beat.body, contains('Seek only worlds or only souls'));

      final banned = RegExp(r'\b(tap|taps|tapping|button|screen|click)\b', caseSensitive: false);
      expect(banned.hasMatch('${beat.title} ${beat.body}'), isFalse);
    });

    test('a new player cannot auto-start exploreGenres before arrival', () async {
      // Clean slate — arrival not recorded
      expect(guide.progress[GuideFlows.arrival.id], isNull);
      expect(guide.canAutoStart(GuideFlows.arrival), isTrue);

      // exploreGenres must NOT auto-start for a brand new player
      expect(guide.canAutoStart(GuideFlows.exploreGenres), isFalse);
    });

    test('a new player starting arrival gets exploreGenres marked seen at once', () async {
      // Start arrival flow
      final started = await guide.maybeStart(GuideFlows.arrival, delay: Duration.zero);
      expect(started, isTrue);

      // exploreGenres is marked as seen simultaneously
      final exploreRecord = guide.progress[GuideFlows.exploreGenres.id];
      expect(exploreRecord, isNotNull);
      expect(exploreRecord!.status, GuideStatus.seen);

      // Neither arc will auto-start again
      expect(guide.canAutoStart(GuideFlows.arrival), isFalse);
      expect(guide.canAutoStart(GuideFlows.exploreGenres), isFalse);
    });

    test('an existing player whose arrival was recorded before auto-starts exploreGenres once', () async {
      // Simulate an existing player who finished arrival in a past session
      await guide.hydrateFromAccount({
        GuideFlows.arrival.id: {
          'version': 1,
          'step': 3,
          'status': 'done',
          'at': '2026-10-01T00:00:00.000Z',
        },
      });

      // Arrival is already done
      expect(guide.canAutoStart(GuideFlows.arrival), isFalse);

      // exploreGenres is eligible because arrival was previously recorded
      expect(guide.canAutoStart(GuideFlows.exploreGenres), isTrue);

      // Start exploreGenres
      final started = await guide.maybeStart(GuideFlows.exploreGenres, delay: Duration.zero);
      expect(started, isTrue);

      // After starting, it is recorded and will not auto-start again
      expect(guide.progress[GuideFlows.exploreGenres.id], isNotNull);
      expect(guide.canAutoStart(GuideFlows.exploreGenres), isFalse);
    });
  });
}
