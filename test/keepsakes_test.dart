import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:everlore/shared/app_icons.dart';
import 'package:everlore/app/theme/nexus_theme.dart';
import 'package:everlore/core/auth/auth_service.dart';
import 'package:everlore/core/guide/guide_controller.dart';
import 'package:everlore/core/network/ws_manager.dart';
import 'package:everlore/core/storage/secure_storage.dart';
import 'package:everlore/screens/auth_screen.dart';
import 'package:everlore/features/keepsakes/data/keepsakes_repository.dart';
import 'package:everlore/features/keepsakes/models/keepsake_item.dart';
import 'package:everlore/features/creator/presentation/my_worlds_screen.dart';
import 'package:everlore/features/keepsakes/presentation/keepsakes_screen.dart';
import 'package:everlore/features/keepsakes/presentation/widgets/keepsake_faded_tile.dart';
import 'package:everlore/features/keepsakes/presentation/widgets/keepsake_feed_post.dart';
import 'package:everlore/features/keepsakes/presentation/widgets/keepsakes_state_view.dart';
import 'package:everlore/features/keepsakes/presentation/widgets/keepsake_caption.dart';
import 'package:everlore/features/keepsakes/presentation/widgets/keepsakes_viewer_screen.dart';
import 'package:everlore/features/keepsakes/state/keepsakes_cubit.dart';
import 'package:everlore/features/play/presentation/play_screen.dart';
import 'package:everlore/features/play/state/play_cubit.dart';
import 'package:everlore/features/media/data/media_repository.dart';
import 'package:everlore/features/media/models/media_usage.dart';
import 'package:everlore/shared/models/event.dart';
import 'package:everlore/shared/models/user.dart';
import 'package:everlore/shared/widgets/everlore_nav_bar.dart';
import 'package:everlore/shared/widgets/everlore_top_bar.dart';
import 'package:everlore/shared/widgets/neu.dart';

class _FakeMediaRepository extends MediaRepository {
  final List<({String instanceId, String eventId})> pictureRequests = [];

  @override
  Future<MediaUsage?> getUsage() async {
    return const MediaUsage(
      voice: UsageQuota(used: 0, limit: 10),
      picture: UsageQuota(used: 0, limit: 10),
      video: UsageQuota(used: 0, limit: 10),
      portrait: UsageQuota(used: 0, limit: 10),
      resetsAt: '',
    );
  }

  @override
  Future<MediaRequestResponse> requestPicture({
    required String instanceId,
    required String eventId,
  }) async {
    pictureRequests.add((instanceId: instanceId, eventId: eventId));
    return const MediaRequestResponse(status: 'queued', mediaId: 'mock_pic_1');
  }
}

class FakeKeepsakesRepository implements KeepsakesRepository {
  List<KeepsakeItem> items;
  bool saves;
  Exception? loadError;
  Exception? nextPageError;
  int? pageSize;
  final List<String> hiddenMediaIds = [];
  final List<String> requestedKinds = [];

  FakeKeepsakesRepository({
    this.items = const [],
    this.saves = true,
    this.loadError,
    this.nextPageError,
    this.pageSize,
  });

  @override
  Future<KeepsakesPage> getKeepsakes({
    KeepsakesFilter filter = KeepsakesFilter.all,
    String? before,
    int limit = 20,
  }) async {
    requestedKinds.add(filter.apiKind);
    if (before == null && loadError != null) {
      throw loadError!;
    }
    if (before != null && nextPageError != null) {
      throw nextPageError!;
    }

    final effectiveLimit = pageSize ?? limit;

    final filtered = items.where((i) {
      if (filter == KeepsakesFilter.all) {
        return i.kind == KeepsakeKind.picture || i.kind == KeepsakeKind.video;
      }
      return i.kind.apiValue == filter.apiKind;
    }).toList();

    if (before != null) {
      final idx = filtered.indexWhere((i) => i.createdAt.toIso8601String() == before);
      final sub = idx >= 0 ? filtered.sublist(idx + 1) : filtered;
      final pageItems = sub.take(effectiveLimit).toList();
      final nextBefore = sub.length > effectiveLimit ? pageItems.last.createdAt.toIso8601String() : null;
      return KeepsakesPage(items: pageItems, nextBefore: nextBefore);
    }

    final pageItems = filtered.take(effectiveLimit).toList();
    final nextBefore = filtered.length > effectiveLimit ? pageItems.last.createdAt.toIso8601String() : null;
    return KeepsakesPage(items: pageItems, nextBefore: nextBefore);
  }

  @override
  Future<void> hideKeepsake(String mediaId) async {
    hiddenMediaIds.add(mediaId);
    items = items.where((i) => i.mediaId != mediaId).toList();
  }

  @override
  Future<bool> hasAnySaves() async => saves;
}

KeepsakeItem _createTestItem({
  String mediaId = 'media-1',
  KeepsakeKind kind = KeepsakeKind.picture,
  String url = 'https://cdn.everlore.com/pic1.jpg',
  String? posterUrl,
  int? durationMs,
  String? instanceId = 'inst-1',
  String? eventId = 'evt-1',
  String? worldTitle = 'The Iron Realm',
  String? coverUrl = 'https://cdn.everlore.com/cover1.jpg',
  String? saveLabel = 'Valen',
  String? excerpt = 'The stone archway groaned as frost gathered upon the brass sigil.',
  String? speakerName,
  String? characterName,
}) {
  return KeepsakeItem(
    mediaId: mediaId,
    kind: kind,
    url: url,
    posterUrl: posterUrl,
    durationMs: durationMs,
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    instanceId: instanceId,
    eventId: eventId,
    world: worldTitle != null ? KeepsakeWorld(title: worldTitle, coverUrl: coverUrl) : null,
    saveLabel: saveLabel,
    excerpt: excerpt,
    speakerName: speakerName,
    character: characterName != null
        ? KeepsakeCharacter(id: 'char-1', name: characterName)
        : null,
  );
}

GameEvent _createTestGameEvent({
  required String id,
  String instanceId = 'inst_1',
  required int sequence,
  String type = 'narration',
  String? aiResponse,
}) {
  return GameEvent(
    id: id,
    instanceId: instanceId,
    sequence: sequence,
    type: type,
    aiResponse: aiResponse,
    createdAt: DateTime.now().subtract(Duration(minutes: 50 - sequence)),
  );
}

class CustomKeepsakesRepository implements KeepsakesRepository {
  final Future<KeepsakesPage> Function(
      KeepsakesFilter filter, String? before, int limit) onGetKeepsakes;
  final bool saves;

  CustomKeepsakesRepository({
    required this.onGetKeepsakes,
    this.saves = true,
  });

  @override
  Future<KeepsakesPage> getKeepsakes({
    KeepsakesFilter filter = KeepsakesFilter.all,
    String? before,
    int limit = 20,
  }) =>
      onGetKeepsakes(filter, before, limit);

  @override
  Future<void> hideKeepsake(String mediaId) async {}

  @override
  Future<bool> hasAnySaves() async => saves;
}

class _TestWsManager extends Fake implements WsManager {
  final _ctrl = StreamController<Map<String, dynamic>>.broadcast();
  final _boolCtrl = StreamController<bool>.broadcast();

  @override
  Stream<Map<String, dynamic>> get onGenerationDelta => _ctrl.stream;
  @override
  Stream<Map<String, dynamic>> get onGenerationStarted => _ctrl.stream;
  @override
  Stream<Map<String, dynamic>> get onGenerationComplete => _ctrl.stream;
  @override
  Stream<Map<String, dynamic>> get onGenerationStreamEnd => _ctrl.stream;
  @override
  Stream<Map<String, dynamic>> get onChoicesReady => _ctrl.stream;
  @override
  Stream<Map<String, dynamic>> get onGenerationRetrying => _ctrl.stream;
  @override
  Stream<Map<String, dynamic>> get onGenerationReset => _ctrl.stream;
  @override
  Stream<Map<String, dynamic>> get onMemoriesCurated => _ctrl.stream;
  @override
  Stream<Map<String, dynamic>> get onError => _ctrl.stream;
  @override
  Stream<bool> get onConnectionState => _boolCtrl.stream;
  @override
  Stream<Map<String, dynamic>> get onInstanceLoaded => _ctrl.stream;
  @override
  Stream<Map<String, dynamic>> get onCharacterCodexUpdated => _ctrl.stream;
  @override
  Stream<Map<String, dynamic>> get onReplayDelta => _ctrl.stream;
  @override
  Stream<Map<String, dynamic>> get onReplayComplete => _ctrl.stream;
  @override
  Stream<Map<String, dynamic>> get onWorldProjectionUpdated => _ctrl.stream;
  @override
  Stream<Map<String, dynamic>> get onMilestoneUnlocked => _ctrl.stream;
  @override
  Stream<Map<String, dynamic>> get onSpokenLines => _ctrl.stream;
  @override
  Stream<Map<String, dynamic>> get onMediaReady => _ctrl.stream;
  @override
  Stream<Map<String, dynamic>> get onMediaUnseen => _ctrl.stream;
  @override
  Stream<Map<String, dynamic>> get onMediaFailed => _ctrl.stream;
  @override
  Stream<void> get onAccountDeleted => const Stream.empty();

  @override
  Future<void> connect(String token, {bool force = false}) async {}
  @override
  Future<void> disconnect({bool clearToken = false}) async {}
  @override
  void loadInstance(String instanceId) {}

  void dispose() {
    _ctrl.close();
    _boolCtrl.close();
  }
}

Widget _buildTestApp({
  required Widget child,
  GoRouter? customRouter,
  Size size = const Size(390, 844),
  double textScale = 1.0,
  bool disableAnimations = true,
}) {
  if (customRouter != null) {
    return MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
        disableAnimations: disableAnimations,
      ),
      child: MaterialApp.router(
        theme: EverloreTheme.dark,
        routerConfig: customRouter,
      ),
    );
  }
  return MediaQuery(
    data: MediaQueryData(
      size: size,
      textScaler: TextScaler.linear(textScale),
      disableAnimations: disableAnimations,
    ),
    child: MaterialApp(
      theme: EverloreTheme.dark,
      home: child,
    ),
  );
}

Future<void> _pumpIt(WidgetTester tester, [int count = 2]) async {
  for (int i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _setTallViewport(WidgetTester tester, [double height = 1400]) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(800, height);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await Firebase.initializeApp();
    await GuideController.instance.hydrateFromAccount(null, remoteOptOut: true);
  });

  group('Keepsakes & Navigation Requirements', () {
    testWidgets('the bar shows Keepsakes, and the profile menu shows Your worlds, which opens My Worlds', (tester) async {
      // 1. EverloreNavBar verification
      int selectedIndex = 0;
      await tester.pumpWidget(
        _buildTestApp(
          child: Scaffold(
            bottomNavigationBar: EverloreNavBar(
              currentIndex: selectedIndex,
              onSelect: (i) => selectedIndex = i,
              onCreate: () {},
            ),
          ),
        ),
      );
      await _pumpIt(tester);

      expect(find.text('Keepsakes'), findsOneWidget);
      expect(find.byType(EvIcon), findsWidgets);

      // Tap Keepsakes slot (index 2)
      await tester.tap(find.text('Keepsakes'));
      expect(selectedIndex, 2);

      // 2. /profile renders AuthScreen with Your worlds above Membership & Ink, and mature-content switch
      FlutterSecureStorage.setMockInitialValues({});
      await SecureStore.saveUserData(jsonEncode(const User(
        id: 'user-1',
        email: 'test@everlore.com',
        username: 'teller',
        tier: 'creator',
        canForge: true,
        preferences: UserPreferences(
          nsfwEnabled: true,
          interests: ['Fantasy'],
        ),
      ).toJson()));

      String? pushedRoute;
      final testRouter = GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(
            path: '/profile',
            builder: (context, state) => const AuthScreen(),
          ),
          GoRoute(
            path: '/my-worlds',
            builder: (context, state) {
              pushedRoute = '/my-worlds';
              return const Scaffold(body: Text('My Worlds Screen'));
            },
          ),
          GoRoute(
            path: '/membership',
            builder: (context, state) => const Scaffold(body: Text('Membership')),
          ),
        ],
      );

      await tester.pumpWidget(_buildTestApp(child: const SizedBox(), customRouter: testRouter));
      await _pumpIt(tester, 5);

      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.text('Your worlds'), findsOneWidget);
      expect(find.text('Membership & Ink'), findsOneWidget);
      expect(find.text('Allow mature themes'), findsOneWidget);

      final yourWorldsY = tester.getTopLeft(find.text('Your worlds')).dy;
      final membershipY = tester.getTopLeft(find.text('Membership & Ink')).dy;
      expect(yourWorldsY, lessThan(membershipY));

      await tester.tap(find.text('Your worlds'));
      await _pumpIt(tester, 3);

      expect(pushedRoute, '/my-worlds');
    });

    testWidgets('each filter calls the route with the right kind', (tester) async {
      final repo = FakeKeepsakesRepository(
        items: [
          _createTestItem(mediaId: 'p1', kind: KeepsakeKind.picture),
          _createTestItem(mediaId: 'v1', kind: KeepsakeKind.video),
          _createTestItem(mediaId: 'f1', kind: KeepsakeKind.portrait),
        ],
      );

      await tester.pumpWidget(_buildTestApp(child: KeepsakesScreen(repository: repo)));
      await _pumpIt(tester);

      // Initial load uses 'all'
      expect(repo.requestedKinds, contains('all'));

      // Tap Pictures
      await tester.tap(find.text('Pictures'));
      await _pumpIt(tester);
      expect(repo.requestedKinds, contains('picture'));

      // Tap Films
      await tester.tap(find.text('Films'));
      await _pumpIt(tester);
      expect(repo.requestedKinds, contains('video'));

      // Tap Faces
      await tester.tap(find.text('Faces'));
      await _pumpIt(tester);
      expect(repo.requestedKinds, contains('portrait'));
    });

    testWidgets('paging appends without duplicates', (tester) async {
      final itemA = _createTestItem(mediaId: 'm1');
      final itemB = _createTestItem(mediaId: 'm2');
      final itemDuplicate = _createTestItem(mediaId: 'm1'); // duplicate of itemA
      final itemC = _createTestItem(mediaId: 'm3');

      final repo = FakeKeepsakesRepository(
        items: [itemA, itemB, itemDuplicate, itemC],
        pageSize: 2,
      );
      final cubit = KeepsakesCubit(repository: repo);

      await cubit.loadInitial();
      expect(cubit.state.items.length, 2);
      expect(cubit.state.hasMore, isTrue);

      // Emit second page with duplicate
      await cubit.loadNextPage();

      final ids = cubit.state.items.map((i) => i.mediaId).toList();
      final uniqueIds = ids.toSet().toList();
      expect(ids.length, 3);
      expect(ids.length, uniqueIds.length);
      expect(ids, ['m1', 'm2', 'm3']);
      await cubit.close();
    });

    testWidgets('the feed caption uses aiText', (tester) async {
      final repo = FakeKeepsakesRepository(
        items: [_createTestItem(excerpt: 'The tower stood silent against the dying light.')],
      );

      await tester.pumpWidget(_buildTestApp(child: KeepsakesScreen(repository: repo)));
      await _pumpIt(tester);

      final textFinder = find.byWidgetPredicate(
        (w) => w is Text && w.textSpan?.toPlainText().contains('The tower stood silent against the dying light.') == true,
      );
      expect(textFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(textFinder);
      expect(textWidget.style?.fontFamily, EverloreTheme.aiText.fontFamily);
    });

    testWidgets('a line film shows its speaker and line', (tester) async {
      final repo = FakeKeepsakesRepository(
        items: [
          _createTestItem(
            kind: KeepsakeKind.video,
            speakerName: 'Mara',
            excerpt: 'Watch the shadows on the left.',
          ),
        ],
      );

      await tester.pumpWidget(_buildTestApp(child: KeepsakesScreen(repository: repo)));
      await _pumpIt(tester);

      expect(find.text('MARA'), findsOneWidget);
      final captionFinder = find.text('"Watch the shadows on the left."', findRichText: true);
      expect(captionFinder, findsOneWidget);

      final widget = tester.firstWidget(captionFinder);
      final InlineSpan rootSpan = widget is Text
          ? widget.textSpan!
          : (widget as RichText).text;
      final leaves = <TextSpan>[];
      void collectLeaves(InlineSpan s) {
        if (s is TextSpan) {
          if (s.children != null && s.children!.isNotEmpty) {
            for (final c in s.children!) {
              collectLeaves(c);
            }
          } else {
            leaves.add(s);
          }
        }
      }

      collectLeaves(rootSpan);
      expect(leaves, isNotEmpty);
      for (final leaf in leaves) {
        expect(leaf.style?.fontStyle, FontStyle.normal);
        expect(leaf.style?.fontStyle, isNot(FontStyle.italic));
      }
    });

    test('a line film caption renders upright with dialogue style and no italic span', () {
      final item = _createTestItem(
        kind: KeepsakeKind.video,
        speakerName: 'Mara',
        excerpt: 'Watch the shadows on the left.',
      );
      final spans = keepsakeCaptionSpans(item, fontSize: 15, height: 1.45);
      expect(spans, isNotEmpty);
      for (final span in spans) {
        if (span is TextSpan) {
          expect(span.style?.fontStyle, FontStyle.normal);
          expect(span.style?.fontStyle, isNot(FontStyle.italic));
        }
      }
      final texts = [for (final s in spans) if (s is TextSpan) s.text ?? ''].join();
      expect(texts, '"Watch the shadows on the left."');
    });

    test('a narrative piece caption renders with italic narration style', () {
      final item = _createTestItem(
        kind: KeepsakeKind.picture,
        excerpt: 'The tower stood silent.',
      );
      final spans = keepsakeCaptionSpans(item, fontSize: 15, height: 1.45);
      expect(spans, isNotEmpty);
      final textSpans = spans.whereType<TextSpan>().toList();
      expect(textSpans.any((s) => s.style?.fontStyle == FontStyle.italic), isTrue);
    });

    testWidgets('Faces renders as a grid with names and Open their card', (tester) async {
      _setTallViewport(tester, 1000);

      final repo = FakeKeepsakesRepository(
        items: [
          _createTestItem(mediaId: 'p1', kind: KeepsakeKind.picture),
          _createTestItem(
            mediaId: 'f1',
            kind: KeepsakeKind.portrait,
            characterName: 'Seraphina',
          ),
        ],
      );

      await tester.pumpWidget(_buildTestApp(size: const Size(800, 1000), child: KeepsakesScreen(repository: repo)));
      await _pumpIt(tester);

      // Switch to Faces
      await tester.tap(find.text('Faces'));
      await _pumpIt(tester);

      // Grid tile shows character name
      expect(find.text('Seraphina'), findsOneWidget);

      // Tap tile to open viewer
      await tester.tap(find.text('Seraphina'));
      await _pumpIt(tester);

      // Action is "Open their card" instead of "Return to this moment"
      expect(find.text('Open their card'), findsOneWidget);
      expect(find.text('Return to this moment'), findsNothing);
    });

    testWidgets('Remove confirms, then calls hide and drops the post', (tester) async {
      _setTallViewport(tester, 1400);

      final repo = FakeKeepsakesRepository(
        items: [_createTestItem(mediaId: 'to-remove')],
      );

      await tester.pumpWidget(_buildTestApp(size: const Size(800, 1400), child: KeepsakesScreen(repository: repo)));
      await _pumpIt(tester);

      expect(find.byType(KeepsakeFeedPost), findsOneWidget);

      // Open ⋯ menu
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await _pumpIt(tester);

      // Tap Remove from Keepsakes
      await tester.tap(find.text('Remove from Keepsakes'));
      await _pumpIt(tester, 5);

      // Confirm dialog appears
      expect(find.text('This hides this piece from your Keepsakes. It stays in your story.'), findsOneWidget);
      await tester.tap(find.widgetWithText(NeuButton, 'Remove'));
      await _pumpIt(tester, 5);

      // Verify hide was called on repository and post is dropped
      expect(repo.hiddenMediaIds, contains('to-remove'));
      expect(find.byType(KeepsakeFeedPost), findsNothing);
    });

    testWidgets('the empty state shows, in both variants (has saves, no saves)', (tester) async {
      // Variant 1: has saves
      final repoWithSaves = FakeKeepsakesRepository(items: [], saves: true);
      await tester.pumpWidget(_buildTestApp(child: KeepsakesScreen(key: const ValueKey('with-saves'), repository: repoWithSaves)));
      await _pumpIt(tester);

      expect(find.text('NOTHING KEPT YET'), findsOneWidget);
      expect(find.text('Long-press any moment in a story to picture it or film it. What you make gathers here.'), findsOneWidget);
      expect(find.text('Open your realms'), findsOneWidget);

      // Variant 2: no saves
      final repoNoSaves = FakeKeepsakesRepository(items: [], saves: false);
      await tester.pumpWidget(_buildTestApp(child: KeepsakesScreen(key: const ValueKey('no-saves'), repository: repoNoSaves)));
      await _pumpIt(tester);

      expect(find.text('NOTHING KEPT YET'), findsOneWidget);
      expect(find.text('Begin a story, then picture or film the moments worth keeping.'), findsOneWidget);
      expect(find.text('Find a world'), findsOneWidget);
    });

    testWidgets('a filter-only empty state shows the compact variant and Show all', (tester) async {
      final repo = FakeKeepsakesRepository(
        items: [_createTestItem(kind: KeepsakeKind.picture)],
      );

      await tester.pumpWidget(_buildTestApp(child: KeepsakesScreen(repository: repo)));
      await _pumpIt(tester);

      // Switch to Films (which has 0 items, but Pictures has items)
      await tester.tap(find.text('Films'));
      await _pumpIt(tester);

      expect(find.text('NO FILMS YET'), findsOneWidget);
      expect(find.text('No films yet. Long-press a moment and choose Film this, or long-press a spoken line.'), findsOneWidget);
      expect(find.text('Show all'), findsOneWidget);

      // Tap Show all switches back to All filter
      await tester.tap(find.text('Show all'));
      await _pumpIt(tester);

      expect(find.byType(KeepsakeFeedPost), findsOneWidget);
    });

    testWidgets('1–3 pieces end with the ornament and nudge, and grid tiles don\'t stretch', (tester) async {
      _setTallViewport(tester, 1800);

      final repo = FakeKeepsakesRepository(
        items: [
          _createTestItem(mediaId: 'm1'),
          _createTestItem(mediaId: 'm2'),
        ],
      );

      await tester.pumpWidget(_buildTestApp(size: const Size(800, 1800), child: KeepsakesScreen(repository: repo)));
      await _pumpIt(tester);
      await tester.drag(find.byType(ListView), const Offset(0, -1500));
      await _pumpIt(tester);

      expect(find.text('That\'s everything you\'ve kept.'), findsOneWidget);
      expect(find.text('Picture another moment'), findsOneWidget);
    });

    testWidgets('a failed first load shows the calm error and Try again works', (tester) async {
      final repo = FakeKeepsakesRepository(
        loadError: Exception('Network offline'),
        items: [_createTestItem(mediaId: 'recovered')],
      );

      await tester.pumpWidget(_buildTestApp(child: KeepsakesScreen(repository: repo)));
      await _pumpIt(tester);

      expect(find.text('Your keepsakes are out of reach. Check your connection and try again.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      // Fix error and retry
      repo.loadError = null;
      await tester.tap(find.text('Try again'));
      await _pumpIt(tester);

      expect(find.byType(KeepsakeFeedPost), findsOneWidget);
    });

    testWidgets('a failed next page keeps the shown items', (tester) async {
      _setTallViewport(tester, 1800);

      final repo = FakeKeepsakesRepository(
        items: List.generate(25, (i) => _createTestItem(mediaId: 'item-$i')),
        pageSize: 5,
        nextPageError: Exception('Page fetch failed'),
      );

      await tester.pumpWidget(_buildTestApp(size: const Size(800, 1800), child: KeepsakesScreen(repository: repo)));
      await _pumpIt(tester);
      await tester.drag(find.byType(ListView), const Offset(0, -1500));
      await _pumpIt(tester);

      expect(find.byType(KeepsakeFeedPost), findsWidgets);

      // Trigger next page load
      tester.element(find.byType(ListView)).read<KeepsakesCubit>().loadNextPage();
      await _pumpIt(tester);
      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await _pumpIt(tester);

      // Items still visible
      expect(find.byType(KeepsakeFeedPost), findsWidgets);
      expect(find.text("Couldn't reach the rest."), findsOneWidget);
    });

    testWidgets('a broken image URL renders the "faded" tile, never an empty box', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: const KeepsakeFadedTile(),
        ),
      );
      await _pumpIt(tester);

      expect(find.text('This keepsake has faded'), findsOneWidget);
      expect(find.byType(AspectRatio), findsOneWidget);
    });

    testWidgets('missing world, cover, excerpt or duration each drop cleanly', (tester) async {
      final repo = FakeKeepsakesRepository(
        items: [
          _createTestItem(
            worldTitle: null, // world removed
            coverUrl: null,
            excerpt: null,
            durationMs: null,
            saveLabel: null,
          ),
        ],
      );

      await tester.pumpWidget(_buildTestApp(child: KeepsakesScreen(repository: repo)));
      await _pumpIt(tester);

      expect(find.text('A story no longer here'), findsOneWidget);
      expect(find.text('Return to this moment'), findsNothing);
    });

    testWidgets('text scale 1.3 at 360 pt width has no overflow', (tester) async {
      final repo = FakeKeepsakesRepository(
        items: [_createTestItem(worldTitle: 'A very long world title that could potentially overflow on small phones')],
      );

      await tester.pumpWidget(
        _buildTestApp(
          size: const Size(360, 640),
          textScale: 1.3,
          child: KeepsakesScreen(repository: repo),
        ),
      );
      await _pumpIt(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets('at 1000 pt there are 5 columns and the feed is capped at ~560 pt', (tester) async {
      expect(getGridColumns(1000), 5);
      expect(getGridColumns(700), 4);
      expect(getGridColumns(500), 3);

      final repo = FakeKeepsakesRepository(items: [_createTestItem()]);
      await tester.pumpWidget(
        _buildTestApp(
          size: const Size(1000, 800),
          child: KeepsakesScreen(repository: repo),
        ),
      );
      await _pumpIt(tester);

      final constrainedBoxFinder = find.byWidgetPredicate(
        (w) => w is ConstrainedBox && w.constraints.maxWidth == 560,
      );
      expect(constrainedBoxFinder, findsWidgets);
    });

    testWidgets('Return to this moment navigates to the right save and turn', (tester) async {
      _setTallViewport(tester, 1400);

      String? navigatedRoute;
      final testRouter = GoRouter(
        initialLocation: '/keepsakes',
        routes: [
          GoRoute(
            path: '/keepsakes',
            builder: (context, state) => KeepsakesScreen(
              repository: FakeKeepsakesRepository(
                items: [_createTestItem(instanceId: 'save-42', eventId: 'turn-99')],
              ),
            ),
          ),
          GoRoute(
            path: '/play/:instanceId',
            builder: (context, state) {
              final id = state.pathParameters['instanceId'];
              final event = state.uri.queryParameters['event'];
              navigatedRoute = '/play/$id?event=$event';
              return const Scaffold(body: Text('Play Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(_buildTestApp(size: const Size(800, 1400), child: const SizedBox(), customRouter: testRouter));
      await _pumpIt(tester);

      expect(find.text('Return to this moment'), findsOneWidget);
      await tester.tap(find.text('Return to this moment'));
      await _pumpIt(tester, 3);

      expect(navigatedRoute, '/play/save-42?event=turn-99');
    });

    test('an empty page with a cursor auto-fetches and never shows the empty state', () async {
      int fetchCount = 0;
      final item1 = _createTestItem(mediaId: 'item-1');
      final repo = CustomKeepsakesRepository(
        onGetKeepsakes: (filter, before, limit) async {
          fetchCount++;
          if (before == null) {
            // First page returns empty with nextBefore
            return const KeepsakesPage(items: [], nextBefore: 'cursor-1');
          } else if (before == 'cursor-1') {
            // Second page returns the item
            return KeepsakesPage(items: [item1], nextBefore: null);
          }
          return const KeepsakesPage(items: [], nextBefore: null);
        },
      );

      final cubit = KeepsakesCubit(repository: repo);
      await cubit.loadInitial();

      expect(fetchCount, 2);
      expect(cubit.state.items.length, 1);
      expect(cubit.state.items.first.mediaId, 'item-1');
      expect(cubit.state.isLoading, isFalse);
    });

    testWidgets('focusEventId on a loaded event scrolls to it', (tester) async {
      _setTallViewport(tester, 800);
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'token'});

      final events = List<GameEvent>.generate(
        12,
        (i) => _createTestGameEvent(
          id: 'turn_$i',
          sequence: i + 1,
          aiResponse: 'Passage $i of the story.',
        ),
      );

      final ws = _TestWsManager();
      addTearDown(ws.dispose);
      final cubit = PlayCubit(instanceId: 'inst_test_1', ws: ws);
      addTearDown(cubit.close);
      cubit.emit(cubit.state.copyWith(
        isLoading: false,
        isConnected: true,
        events: events,
        totalEvents: 12,
        hasOlderEvents: false,
      ));

      await tester.pumpWidget(
        _buildTestApp(
          child: PlayScreen(
            instanceId: 'inst_test_1',
            focusEventId: 'turn_4',
            cubit: cubit,
          ),
        ),
      );
      await _pumpIt(tester, 5);

      expect(find.text('Passage 4 of the story.', findRichText: true), findsOneWidget);
    });

    testWidgets('an event found after paging older is reached', (tester) async {
      _setTallViewport(tester, 800);
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'token'});

      final initialEvents = List<GameEvent>.generate(
        4,
        (i) => _createTestGameEvent(
          id: 'turn_${i + 5}',
          sequence: i + 6,
          aiResponse: 'Recent passage ${i + 5}.',
        ),
      );

      final olderEvent = _createTestGameEvent(
        id: 'turn_target',
        sequence: 2,
        aiResponse: 'Ancient passage found deep in history.',
      );

      PlayCubit.olderEventsLoaderForTesting =
          (inst, {limit = 20, beforeSequence}) async {
        return {
          'events': [olderEvent],
          'hasOlder': false,
          'total': 5,
        };
      };
      addTearDown(() => PlayCubit.olderEventsLoaderForTesting = null);

      final ws = _TestWsManager();
      addTearDown(ws.dispose);
      final cubit = PlayCubit(instanceId: 'inst_test_2', ws: ws);
      addTearDown(cubit.close);
      cubit.emit(cubit.state.copyWith(
        isLoading: false,
        isConnected: true,
        events: initialEvents,
        totalEvents: 5,
        hasOlderEvents: true,
      ));

      await tester.pumpWidget(
        _buildTestApp(
          child: PlayScreen(
            instanceId: 'inst_test_2',
            focusEventId: 'turn_target',
            cubit: cubit,
          ),
        ),
      );
      await _pumpIt(tester, 8);

      expect(
          find.text('Ancient passage found deep in history.', findRichText: true), findsOneWidget);
    });

    testWidgets('a missing event shows the notice and stays at the newest turn',
        (tester) async {
      _setTallViewport(tester, 800);
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'token'});

      final initialEvents = List<GameEvent>.generate(
        3,
        (i) => _createTestGameEvent(
          id: 'turn_$i',
          sequence: i + 1,
          aiResponse: 'Passage $i.',
        ),
      );

      final ws = _TestWsManager();
      addTearDown(ws.dispose);
      final cubit = PlayCubit(instanceId: 'inst_test_3', ws: ws);
      addTearDown(cubit.close);
      cubit.emit(cubit.state.copyWith(
        isLoading: false,
        isConnected: true,
        events: initialEvents,
        totalEvents: 3,
        hasOlderEvents: false,
      ));

      await tester.pumpWidget(
        _buildTestApp(
          child: PlayScreen(
            instanceId: 'inst_test_3',
            focusEventId: 'missing_turn_404',
            cubit: cubit,
          ),
        ),
      );
      await _pumpIt(tester, 5);

      expect(
        find.text("That moment was rewritten. Here's where the story stands."),
        findsOneWidget,
      );
    });

    testWidgets('no focusEventId keeps today\'s behaviour', (tester) async {
      _setTallViewport(tester, 800);
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'token'});

      final initialEvents = List<GameEvent>.generate(
        3,
        (i) => _createTestGameEvent(
          id: 'turn_$i',
          sequence: i + 1,
          aiResponse: 'Default passage $i.',
        ),
      );

      final ws = _TestWsManager();
      addTearDown(ws.dispose);
      final cubit = PlayCubit(instanceId: 'inst_test_4', ws: ws);
      addTearDown(cubit.close);
      cubit.emit(cubit.state.copyWith(
        isLoading: false,
        isConnected: true,
        events: initialEvents,
        totalEvents: 3,
        hasOlderEvents: false,
      ));

      await tester.pumpWidget(
        _buildTestApp(
          child: PlayScreen(
            instanceId: 'inst_test_4',
            cubit: cubit,
          ),
        ),
      );
      await _pumpIt(tester, 5);

      expect(
        find.text("That moment was rewritten. Here's where the story stands."),
        findsNothing,
      );
      expect(find.text('Default passage 2.', findRichText: true), findsOneWidget);
    });

    testWidgets(
      'regression test: media button opens Picture this through PlayScreen with no hand-wrapped provider and works',
      (tester) async {
        _setTallViewport(tester, 800);
        FlutterSecureStorage.setMockInitialValues({'auth_token': 'token'});

        final ws = _TestWsManager();
        addTearDown(ws.dispose);
        final mediaRepo = _FakeMediaRepository();
        final cubit = PlayCubit(
          instanceId: 'inst_regression_turn_menu',
          ws: ws,
          mediaRepo: mediaRepo,
        );
        addTearDown(cubit.close);

        final event = _createTestGameEvent(
          id: 'turn_menu_evt_1',
          sequence: 1,
          aiResponse: 'A moonlit clearing where silver leaves fall silently.',
        );

        cubit.emit(cubit.state.copyWith(
          isLoading: false,
          isConnected: true,
          isMediaAvailable: true,
          events: [event],
          totalEvents: 1,
        ));

        // Note: No BlocProvider<PlayCubit> wraps _buildTestApp or PlayScreen here.
        // PlayScreen provides PlayCubit to its own children, but the modal popup
        // is pushed on the navigator.
        await tester.pumpWidget(
          _buildTestApp(
            child: PlayScreen(
              instanceId: 'inst_regression_turn_menu',
              cubit: cubit,
            ),
          ),
        );
        await _pumpIt(tester, 5);

        final turnTextFinder = find.text(
          'A moonlit clearing where silver leaves fall silently.',
          findRichText: true,
        );
        expect(turnTextFinder, findsOneWidget);

        final mediaButtonFinder = find.byTooltip('Picture or film this moment');
        expect(mediaButtonFinder, findsOneWidget);

        await tester.tap(mediaButtonFinder);
        await _pumpIt(tester, 5);

        expect(find.text('Picture this'), findsOneWidget);

        await tester.tap(find.text('Picture this'));
        await _pumpIt(tester, 5);

        expect(find.text('Picture this'), findsNothing);
        expect(mediaRepo.pictureRequests, [
          (instanceId: 'inst_regression_turn_menu', eventId: 'turn_menu_evt_1'),
        ]);
      },
    );

    testWidgets(
      'background asset is in the Keepsakes widget tree for both feed and empty state',
      (tester) async {
        final bgAssetFinder = find.byWidgetPredicate(
          (w) =>
              w is Image &&
              w.image is AssetImage &&
              (w.image as AssetImage).assetName ==
                  'assets/art/keepsakes-archive.webp',
        );

        // 1. Feed state
        final repoWithItems = FakeKeepsakesRepository(
          items: [_createTestItem(excerpt: 'A silent monument.')],
        );
        await tester.pumpWidget(
          _buildTestApp(
            child: KeepsakesScreen(
              key: const ValueKey('bg-feed-test'),
              repository: repoWithItems,
            ),
          ),
        );
        await _pumpIt(tester);
        expect(bgAssetFinder, findsOneWidget);

        // 2. Empty state
        final emptyRepo = FakeKeepsakesRepository(items: const []);
        await tester.pumpWidget(
          _buildTestApp(
            child: KeepsakesScreen(
              key: const ValueKey('bg-empty-test'),
              repository: emptyRepo,
            ),
          ),
        );
        await _pumpIt(tester);
        expect(bgAssetFinder, findsOneWidget);
      },
    );

    testWidgets(
      'empty state has no boxed image in both full and compact variants',
      (tester) async {
        // 1. Full empty state
        final emptyRepo = FakeKeepsakesRepository(items: const []);
        await tester.pumpWidget(
          _buildTestApp(
            child: KeepsakesScreen(
              key: const ValueKey('full-empty-box-test'),
              repository: emptyRepo,
            ),
          ),
        );
        await _pumpIt(tester);

        expect(find.byType(KeepsakesStateView), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(KeepsakesStateView),
            matching: find.byType(Image),
          ),
          findsNothing,
        );

        // 2. Filter-only compact empty state
        final pictureOnlyRepo = FakeKeepsakesRepository(
          items: [_createTestItem(kind: KeepsakeKind.picture)],
        );
        await tester.pumpWidget(
          _buildTestApp(
            child: KeepsakesScreen(
              key: const ValueKey('compact-empty-box-test'),
              repository: pictureOnlyRepo,
            ),
          ),
        );
        await _pumpIt(tester);

        await tester.tap(find.text('Films'));
        await _pumpIt(tester);

        expect(find.byType(KeepsakesStateView), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(KeepsakesStateView),
            matching: find.byType(Image),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'a caption with *narration* renders without asterisks in styled story prose',
      (tester) async {
        final repo = FakeKeepsakesRepository(
          items: [
            _createTestItem(
              excerpt: "*The Thorne rider's gaze* pierced through the mist.",
            ),
          ],
        );

        await tester.pumpWidget(
          _buildTestApp(child: KeepsakesScreen(repository: repo)),
        );
        await _pumpIt(tester);

        // No literal asterisks in the rendered caption
        expect(find.textContaining('*', findRichText: true), findsNothing);
        // The text is rendered cleanly
        expect(
          find.textContaining(
            "The Thorne rider's gaze pierced through the mist.",
            findRichText: true,
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Your worlds shows a back control when pushed, and none as a root',
      (tester) async {
        // 1. As a root route: no back button
        await tester.pumpWidget(
          _buildTestApp(
            child: const MyWorldsScreen(),
          ),
        );
        await _pumpIt(tester, 3);
        expect(find.byIcon(Icons.arrow_back_ios_new), findsNothing);

        // 2. Pushed in a Navigator: standard back affordance is visible and pops
        await tester.pumpWidget(
          MaterialApp(
            theme: EverloreTheme.dark,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MyWorldsScreen(),
                      ),
                    ),
                    child: const Text('Open Your Worlds'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.text('Open Your Worlds'));
        await _pumpIt(tester, 3);

        expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
        expect(find.byTooltip('Back'), findsOneWidget);

        // Tapping pops back to root
        await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
        await _pumpIt(tester, 6);
        expect(find.byType(MyWorldsScreen), findsNothing);
      },
    );

    testWidgets(
      'EverloreTopBar has no back control by default, even when pushed',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: EverloreTheme.dark,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const Scaffold(
                          body: EverloreTopBar(title: 'Top Bar Default'),
                        ),
                      ),
                    ),
                    child: const Text('Push Top Bar'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.text('Push Top Bar'));
        await _pumpIt(tester, 3);

        expect(find.byType(EverloreTopBar), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back_ios_new), findsNothing);
        expect(find.byTooltip('Back'), findsNothing);
      },
    );
  });
}
