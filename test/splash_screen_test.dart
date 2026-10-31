import 'dart:async';
import 'dart:ui' as ui;

import 'package:everlore/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _tagline = 'Step into a story that remembers you';

Widget _app(Future<String?> Function() decide) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => SplashScreen(decideRoute: decide),
      ),
      GoRoute(path: '/welcome', builder: (_, __) => const Text('at-welcome')),
      GoRoute(path: '/discover', builder: (_, __) => const Text('at-discover')),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

/// Pumps in small steps until [finder] matches or [limit] passes.
Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration limit = const Duration(seconds: 5),
}) async {
  var spent = Duration.zero;
  while (finder.evaluate().isEmpty && spent < limit) {
    await tester.pump(const Duration(milliseconds: 50));
    spent += const Duration(milliseconds: 50);
  }
}

void main() {
  setUp(() => SplashScreen.waitForPainting = false);
  tearDown(() => SplashScreen.waitForPainting = true);

  Future<void> sizeScreen(WidgetTester tester) async {
    tester.view.physicalSize = const ui.Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('frame 0 is the system splash: a 160px circle at the centre', (
    tester,
  ) async {
    await sizeScreen(tester);
    final never = Completer<String?>();
    await tester.pumpWidget(_app(() => never.future));

    final box = find.byKey(const Key('splash-painting'));
    expect(tester.getSize(box), const Size(160, 160));
    expect(tester.getCenter(box), const Offset(200, 400));

    final mask = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((c) => c.painter)
        .whereType<SplashPaintingMask>()
        .single;
    expect(mask.side, 160, reason: 'radius 80: the OS circle');
    expect(mask.feather, lessThan(0.01), reason: 'a hair: the OS circle edge');
  });

  testWidgets('does not leave before the decision arrives', (tester) async {
    await sizeScreen(tester);
    final decision = Completer<String?>();
    await tester.pumpWidget(_app(() => decision.future));

    // Well past the open phase and the minimum hold.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byKey(const Key('splash-painting')), findsOneWidget);
    expect(find.text('at-discover'), findsNothing);
    // Opened out to the full width by now.
    expect(tester.getSize(find.byKey(const Key('splash-painting'))).width, 400);

    decision.complete('/discover');
    await _pumpUntil(tester, find.text('at-discover'));
    expect(find.text('at-discover'), findsOneWidget);
  });

  testWidgets('walks in before it goes to the decided route', (tester) async {
    await sizeScreen(tester);
    await tester.pumpWidget(_app(() async => '/discover'));

    // Open (900) + hold (250) are done at 1.15 s; the walk and the fade out
    // run to about 2.3 s, so the route is not reached before then.
    for (var i = 0; i < 38; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('at-discover'), findsNothing);
    await _pumpUntil(tester, find.text('at-discover'));
    expect(find.text('at-discover'), findsOneWidget);
  });

  testWidgets('a throwing decision falls back to /welcome', (tester) async {
    await sizeScreen(tester);
    await tester.pumpWidget(_app(() async => throw StateError('offline')));
    await _pumpUntil(tester, find.text('at-welcome'));
    expect(find.text('at-welcome'), findsOneWidget);
  });

  testWidgets('reduced motion goes without the walk-in', (tester) async {
    await sizeScreen(tester);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const _Reduced();
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(_app(() async => '/discover'));

    // Painted at full width straight away, name block shown.
    expect(tester.getSize(find.byKey(const Key('splash-painting'))).width, 400);
    expect(find.text(_tagline), findsOneWidget);

    // Still on screen for at least 400 ms.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('at-discover'), findsNothing);
    // And gone well before the 1.15 s the walk-in alone would need.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('at-discover'), findsOneWidget);
  });

  testWidgets('shows the new line and no AI', (tester) async {
    await sizeScreen(tester);
    final never = Completer<String?>();
    await tester.pumpWidget(_app(() => never.future));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text(_tagline), findsOneWidget);
    expect(find.text('EVERLORE'), findsOneWidget);
    expect(find.textContaining('AI'), findsNothing);
  });
}

class _Reduced implements ui.AccessibilityFeatures {
  const _Reduced();
  @override
  bool get disableAnimations => true;
  @override
  dynamic noSuchMethod(Invocation i) => false;
}
