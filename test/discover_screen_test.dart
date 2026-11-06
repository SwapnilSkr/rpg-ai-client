import 'dart:async';

import 'package:everlore/app/theme/nexus_theme.dart';
import 'package:everlore/core/guide/guide_anchor.dart';
import 'package:everlore/core/guide/guide_controller.dart';
import 'package:everlore/core/guide/guide_ids.dart';
import 'package:everlore/features/notifications/presentation/widgets/notifications_bell_button.dart';
import 'package:everlore/features/templates/data/template_repository.dart';
import 'package:everlore/features/templates/presentation/explore_filter_sheet.dart';
import 'package:everlore/screens/discover_screen.dart';
import 'package:everlore/shared/models/world_template.dart';
import 'package:everlore/shared/widgets/everlore_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

WorldTemplate _makeTestTemplate(String id) {
  return WorldTemplate(
    id: id,
    title: 'World $id',
    slug: 'world-$id',
    description: 'Description for $id',
    creatorId: 'c1',
    kind: 'world',
    genre: 'fantasy',
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  setUp(() async {
    await GuideController.instance.hydrateFromAccount(null, remoteOptOut: true);
    TemplateRepository.invalidate();
    TemplateRepository.listPublishedOverride = ({
      int page = 1,
      int limit = 20,
      String? search,
      String? genre,
      String? kind,
      Iterable<String>? styles,
      String? sort,
      bool forceRefresh = false,
    }) async {
      return {
        'templates': [_makeTestTemplate('t1'), _makeTestTemplate('t2')],
        'total': 2,
      };
    };
  });

  tearDown(() {
    TemplateRepository.listPublishedOverride = null;
    TemplateRepository.invalidate();
  });

  testWidgets(
    'Explore header has bell and search, but NOT the filter button',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: EverloreTheme.dark,
          home: const DiscoverScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final topBarFinder = find.byType(EverloreTopBar);
      expect(topBarFinder, findsOneWidget);

      final topBar = tester.widget<EverloreTopBar>(topBarFinder);
      expect(topBar.showNotifications, isTrue);

      // Bell is inside the top bar
      expect(
        find.descendant(
          of: topBarFinder,
          matching: find.byType(NotificationsBellButton),
        ),
        findsOneWidget,
      );

      // Search is inside the top bar
      expect(
        find.descendant(
          of: topBarFinder,
          matching: find.byIcon(Icons.search_rounded),
        ),
        findsOneWidget,
      );

      // Filter icon (tune_rounded) is NOT inside the top bar
      expect(
        find.descendant(
          of: topBarFinder,
          matching: find.byIcon(Icons.tune_rounded),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Explore filter button is in the shelf row with GuideAnchor, opens sheet, and shows dot with active filter',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: EverloreTheme.dark,
          home: const DiscoverScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Filter button exists on screen
      final filterIconFinder = find.byIcon(Icons.tune_rounded);
      expect(filterIconFinder, findsOneWidget);

      // Filter button is wrapped in GuideAnchor with id discoverFilter
      final filterAnchorFinder = find.byWidgetPredicate(
        (w) => w is GuideAnchor && w.id == GuideIds.discoverFilter,
      );
      expect(filterAnchorFinder, findsOneWidget);
      expect(
        find.descendant(of: filterAnchorFinder, matching: filterIconFinder),
        findsOneWidget,
      );

      // Shelves/tabs are wrapped in GuideAnchor with id discoverTabs
      final tabsAnchorFinder = find.byWidgetPredicate(
        (w) => w is GuideAnchor && w.id == GuideIds.discoverTabs,
      );
      expect(tabsAnchorFinder, findsOneWidget);

      // Verify the shelf row layout: tabs are to the left of the filter button
      final tabsRect = tester.getRect(tabsAnchorFinder);
      final filterRect = tester.getRect(filterAnchorFinder);
      expect(tabsRect.right, lessThanOrEqualTo(filterRect.left));

      // Initially no active filter -> no gold dot badge
      Finder goldDotFinder() => find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).color == EverloreTheme.gold &&
                (w.decoration as BoxDecoration).shape == BoxShape.circle &&
                (w.decoration as BoxDecoration).boxShadow != null,
          );

      expect(
        find.descendant(of: filterAnchorFinder, matching: goldDotFinder()),
        findsNothing,
      );

      // Tap filter button to open filter sheet
      await tester.tap(filterIconFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Filter sheet is now open
      expect(find.byType(ExploreFilterSheet), findsOneWidget);

      // Select 'Worlds' chip in the filter sheet
      await tester.tap(find.text('Worlds'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Apply the filter
      await tester.tap(find.text('Apply'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Filter sheet is closed
      expect(find.byType(ExploreFilterSheet), findsNothing);

      // Now active filter exists -> gold dot badge is rendered on the filter button
      expect(
        find.descendant(of: filterAnchorFinder, matching: goldDotFinder()),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Explore layout at 360dp wide with text scale 1.3 has no overflow and pills scroll',
    (tester) async {
      final errors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      tester.view.physicalSize = const Size(360 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: EverloreTheme.dark,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 800),
              textScaler: TextScaler.linear(1.3),
            ),
            child: const DiscoverScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final overflowErrors = errors.where(
        (e) => e.toString().contains('overflowed'),
      );
      expect(overflowErrors, isEmpty);

      // Both the tabs and filter button are visible
      expect(find.text('For You'), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);

      // The pills list is scrollable
      final listFinder = find.byType(Scrollable).first;
      expect(listFinder, findsOneWidget);
    },
  );
}
