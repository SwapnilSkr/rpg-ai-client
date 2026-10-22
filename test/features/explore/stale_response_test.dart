import 'dart:async';

import 'package:everlore/core/guide/guide_controller.dart';
import 'package:everlore/features/templates/data/template_repository.dart';
import 'package:everlore/features/templates/presentation/explore_filter_sheet.dart';
import 'package:everlore/screens/discover_screen.dart';
import 'package:everlore/shared/models/explore_genre.dart';
import 'package:everlore/shared/models/world_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

WorldTemplate _mockTemplate(String id, String title) {
  return WorldTemplate(
    id: id,
    creatorId: 'c1',
    title: title,
    slug: id,
    description: 'A test world blurb',
    genre: 'romance',
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  setUp(() async {
    await GuideController.instance.hydrateFromAccount(null, remoteOptOut: true);
    TemplateRepository.invalidate();
  });

  tearDown(() {
    TemplateRepository.invalidate();
  });

  group('ExploreFilterSheet live interests by kind (Requirement 3)', () {
    testWidgets('changing Show to Worlds or Characters drops unavailable picked voices live', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExploreFilterSheet(
                initialFilter: ExploreFilterState(
                  styles: {'dark_romance', 'flirty'},
                ),
                availableStyles: {
                  // dark_romance has 0 worlds, 10 characters
                  'dark_romance': GenreStyleCount(worlds: 0, characters: 10),
                  // flirty has 2 worlds, 9 characters
                  'flirty': GenreStyleCount(worlds: 2, characters: 9),
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Initially SHOW is All: both Dark Romance and Flirty chips exist
      expect(find.text('Dark Romance'), findsOneWidget);
      expect(find.text('Flirty / Lustful'), findsOneWidget);

      // Tap 'Worlds'
      await tester.tap(find.text('Worlds'));
      await tester.pump();

      // dark_romance has 0 worlds: it must disappear live!
      expect(find.text('Dark Romance'), findsNothing,
          reason: 'Voices with 0 worlds must not be listed when Show is Worlds');
      expect(find.text('Flirty / Lustful'), findsOneWidget);

      // Tap 'Characters'
      await tester.tap(find.text('Characters'));
      await tester.pump();

      // Both voices have characters > 0
      expect(find.text('Dark Romance'), findsOneWidget);
      expect(find.text('Flirty / Lustful'), findsOneWidget);

      // Switch back to 'Worlds' to ensure dark_romance disappears again
      await tester.tap(find.text('Worlds'));
      await tester.pump();

      expect(find.text('Dark Romance'), findsNothing);
      expect(find.text('Flirty / Lustful'), findsOneWidget);
    });
  });

  group('DiscoverScreen stale response token handling (Requirement 1)', () {
    testWidgets('stale _load response is dropped and does not overwrite current feed', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final completer1 = Completer<Map<String, dynamic>>();
      final completer2 = Completer<Map<String, dynamic>>();
      int callCount = 0;

      TemplateRepository.listPublishedOverride = ({
        int page = 1,
        int limit = 20,
        String? search,
        String? genre,
        String? kind,
        Iterable<String>? styles,
        String? sort,
        bool forceRefresh = false,
      }) {
        callCount++;
        if (callCount == 1) {
          return completer1.future;
        } else {
          return completer2.future;
        }
      };

      await tester.pumpWidget(
        const MaterialApp(
          home: DiscoverScreen(),
        ),
      );

      // First load in flight (callCount == 1)
      expect(callCount, 1);

      // Trigger a second load (e.g. search changed) before completer1 finishes
      await tester.tap(find.byTooltip('Search Explore'));
      await tester.pump(const Duration(milliseconds: 200));

      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'dragon');
      // Wait past the 280ms debounce timer
      await tester.pump(const Duration(milliseconds: 350));

      expect(callCount, 2);

      // Now completer2 (for 'dragon') resolves FIRST
      completer2.complete({
        'templates': [_mockTemplate('dragon-1', 'Dragon Realm')],
        'total': 1,
      });
      await tester.pump(const Duration(milliseconds: 200));

      // Feed should show 'Dragon Realm'
      expect(find.text('Dragon Realm'), findsOneWidget);

      // Now completer1 (stale initial request) resolves LATER
      completer1.complete({
        'templates': [_mockTemplate('stale-1', 'Stale Old Realm')],
        'total': 99,
      });
      await tester.pump(const Duration(milliseconds: 200));

      // Stale reply must be DROPPED: 'Stale Old Realm' must NOT be in view
      expect(find.text('Dragon Realm'), findsOneWidget);
      expect(find.text('Stale Old Realm'), findsNothing);

      // Drain any delayed guide or animation timers
      await tester.pump(const Duration(seconds: 25));
    });

    testWidgets('stale _loadMore response is dropped when a new _load starts after it', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final initialLoad = Completer<Map<String, dynamic>>();
      final loadMoreCompleter = Completer<Map<String, dynamic>>();
      final newLoadCompleter = Completer<Map<String, dynamic>>();

      int callCount = 0;
      TemplateRepository.listPublishedOverride = ({
        int page = 1,
        int limit = 20,
        String? search,
        String? genre,
        String? kind,
        Iterable<String>? styles,
        String? sort,
        bool forceRefresh = false,
      }) {
        callCount++;
        if (callCount == 1) {
          return initialLoad.future;
        } else if (page > 1) {
          return loadMoreCompleter.future;
        } else {
          return newLoadCompleter.future;
        }
      };

      await tester.pumpWidget(
        const MaterialApp(
          home: DiscoverScreen(),
        ),
      );

      // Complete initial load with total = 50 so _loadMore is eligible
      initialLoad.complete({
        'templates': List.generate(20, (i) => _mockTemplate('init-$i', 'Realm $i')),
        'total': 50,
      });
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Realm 0'), findsOneWidget);

      // Scroll to trigger _loadMore
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -3000));
      await tester.pump(const Duration(milliseconds: 100));

      // Now _loadMore is in flight. A new _load starts (e.g. search)
      await tester.tap(find.byTooltip('Search Explore'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(find.byType(TextField), 'magic');
      await tester.pump(const Duration(milliseconds: 350));

      // Resolve the new _load first
      newLoadCompleter.complete({
        'templates': [_mockTemplate('magic-1', 'Magic Realm')],
        'total': 1,
      });
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Magic Realm'), findsOneWidget);

      // Now the old _loadMore completes with page 2 from previous request
      loadMoreCompleter.complete({
        'templates': [_mockTemplate('p2-0', 'Stale Page 2 Realm')],
        'total': 50,
      });
      await tester.pump(const Duration(milliseconds: 200));

      // Stale page 2 must NOT be appended into the new load's feed
      expect(find.text('Magic Realm'), findsOneWidget);
      expect(find.text('Stale Page 2 Realm'), findsNothing);

      // Drain any delayed guide or animation timers
      await tester.pump(const Duration(seconds: 25));
    });
  });
}
