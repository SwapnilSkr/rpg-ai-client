import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:everlore/app/theme/nexus_theme.dart';
import 'package:everlore/app_routes.dart';
import 'package:everlore/core/guide/guide_controller.dart';
import 'package:everlore/core/network/ws_manager.dart';
import 'package:everlore/features/play/presentation/play_screen.dart';
import 'package:everlore/features/play/presentation/widgets/starter_story_link.dart';
import 'package:everlore/features/play/state/play_cubit.dart';
import 'package:everlore/shared/models/event.dart';
import 'package:everlore/shared/models/world_instance.dart';
import 'package:everlore/shared/models/world_template.dart';

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
  Stream<Map<String, dynamic>> get onAck => const Stream.empty();
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

void main() {
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'dummy_token'});
    await guide.onSignedOut();
    await guide.setOptOut(true);
    GuideController.arcGap = Duration.zero;
  });

  tearDown(() async {
    await guide.setOptOut(false);
    await guide.onSignedOut();
    GuideController.arcGap = Duration.zero;
  });

  group('StarterStoryLink widget', () {
    testWidgets('renders copy and chevron icon with EverloreTheme tokens', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StarterStoryLink(),
          ),
        ),
      );

      final textFinder = find.text('Pick a different story');
      expect(textFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(textFinder);
      expect(textWidget.style?.color, EverloreTheme.ash);

      final iconFinder = find.byIcon(Icons.chevron_right_rounded);
      expect(iconFinder, findsOneWidget);
    });

    testWidgets('tap target is at least 44 dp tall', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: StarterStoryLink(),
            ),
          ),
        ),
      );

      final inkWellFinder = find.byType(InkWell);
      expect(inkWellFinder, findsOneWidget);
      final size = tester.getSize(inkWellFinder);
      expect(size.height, greaterThanOrEqualTo(44.0));
    });

    testWidgets('calls custom onTap callback when provided', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StarterStoryLink(
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Pick a different story'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('default tap navigates to /discover via GoRouter', (tester) async {
      var visitedDiscover = false;

      final testRouter = GoRouter(
        initialLocation: '/play/test-instance',
        routes: [
          GoRoute(
            path: '/play/:instanceId',
            builder: (context, state) => const Scaffold(
              body: StarterStoryLink(),
            ),
          ),
          GoRoute(
            path: '/discover',
            builder: (context, state) {
              visitedDiscover = true;
              return const Scaffold(body: Text('Discover Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: testRouter,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pick a different story'), findsOneWidget);
      expect(visitedDiscover, isFalse);

      await tester.tap(find.text('Pick a different story'));
      await tester.pumpAndSettle();

      expect(visitedDiscover, isTrue);
      expect(find.text('Discover Screen'), findsOneWidget);
    });
  });

  group('Route parsing for starter parameter', () {
    testWidgets('passes starter: true to PlayScreen when starter=1 query param is set', (tester) async {
      late PlayScreen built;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final route = router.configuration.routes
                  .whereType<GoRoute>()
                  .firstWhere((r) => r.name == 'play');
              final state = GoRouterState(
                router.configuration,
                uri: Uri.parse('/play/inst-123?starter=1'),
                matchedLocation: '/play/inst-123',
                fullPath: '/play/:instanceId',
                pathParameters: const {'instanceId': 'inst-123'},
                pageKey: const ValueKey('play_test_1'),
              );
              built = route.builder!(context, state) as PlayScreen;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(built.instanceId, 'inst-123');
      expect(built.starter, isTrue);
    });

    testWidgets('passes starter: false to PlayScreen when starter query param is omitted or not 1', (tester) async {
      late PlayScreen builtOmitted;
      late PlayScreen builtOther;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final route = router.configuration.routes
                  .whereType<GoRoute>()
                  .firstWhere((r) => r.name == 'play');
              final state1 = GoRouterState(
                router.configuration,
                uri: Uri.parse('/play/inst-456'),
                matchedLocation: '/play/inst-456',
                fullPath: '/play/:instanceId',
                pathParameters: const {'instanceId': 'inst-456'},
                pageKey: const ValueKey('play_test_2'),
              );
              builtOmitted = route.builder!(context, state1) as PlayScreen;

              final state2 = GoRouterState(
                router.configuration,
                uri: Uri.parse('/play/inst-789?starter=0'),
                matchedLocation: '/play/inst-789',
                fullPath: '/play/:instanceId',
                pathParameters: const {'instanceId': 'inst-789'},
                pageKey: const ValueKey('play_test_3'),
              );
              builtOther = route.builder!(context, state2) as PlayScreen;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(builtOmitted.instanceId, 'inst-456');
      expect(builtOmitted.starter, isFalse);
      expect(builtOther.instanceId, 'inst-789');
      expect(builtOther.starter, isFalse);
    });
  });

  group('PlayScreen with starter flag and turn detection', () {
    testWidgets('shows StarterStoryLink when starter=true and only seed greeting exists', (tester) async {
      final ws = _TestWsManager();
      addTearDown(ws.dispose);
      final cubit = PlayCubit(instanceId: 'inst-test', ws: ws);
      addTearDown(cubit.close);

      final seedEvent = GameEvent(
        id: 'evt-1',
        instanceId: 'inst-test',
        sequence: 1,
        type: 'dialogue',
        playerInput: '',
        aiResponse: 'Welcome to the starter world.',
        modelUsed: 'seed',
        createdAt: DateTime.now(),
      );

      final template = WorldTemplate.fromJson({
        '_id': 't1',
        'title': 'The Realm',
        'opening_line': 'Welcome to the starter world.',
      });

      cubit.emit(cubit.state.copyWith(
        isLoading: false,
        isConnected: true,
        template: template,
        instance: WorldInstance.fromJson({'_id': 'inst-test', 'template_id': 't1', 'player_id': 'p1'}),
        events: [seedEvent],
        totalEvents: 1,
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: PlayScreen(
            instanceId: 'inst-test',
            starter: true,
            cubit: cubit,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(StarterStoryLink), findsOneWidget);
      expect(find.text('Pick a different story'), findsOneWidget);
    });

    testWidgets('hides StarterStoryLink when starter=false', (tester) async {
      final ws = _TestWsManager();
      addTearDown(ws.dispose);
      final cubit = PlayCubit(instanceId: 'inst-test', ws: ws);
      addTearDown(cubit.close);

      final seedEvent = GameEvent(
        id: 'evt-1',
        instanceId: 'inst-test',
        sequence: 1,
        type: 'dialogue',
        playerInput: '',
        aiResponse: 'Welcome to the starter world.',
        modelUsed: 'seed',
        createdAt: DateTime.now(),
      );

      cubit.emit(cubit.state.copyWith(
        isLoading: false,
        isConnected: true,
        events: [seedEvent],
        totalEvents: 1,
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: PlayScreen(
            instanceId: 'inst-test',
            starter: false,
            cubit: cubit,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(StarterStoryLink), findsNothing);
    });

    testWidgets('hides StarterStoryLink once a player turn is sent (optimistic event)', (tester) async {
      final ws = _TestWsManager();
      addTearDown(ws.dispose);
      final cubit = PlayCubit(instanceId: 'inst-test', ws: ws);
      addTearDown(cubit.close);

      final seedEvent = GameEvent(
        id: 'evt-1',
        instanceId: 'inst-test',
        sequence: 1,
        type: 'dialogue',
        playerInput: '',
        aiResponse: 'Welcome to the starter world.',
        modelUsed: 'seed',
        createdAt: DateTime.now(),
      );

      cubit.emit(cubit.state.copyWith(
        isLoading: false,
        isConnected: true,
        events: [seedEvent],
        totalEvents: 1,
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: PlayScreen(
            instanceId: 'inst-test',
            starter: true,
            cubit: cubit,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(StarterStoryLink), findsOneWidget);

      // Simulate player sending a turn -> optimistic event added
      final optimisticEvent = GameEvent.optimistic(
        instanceId: 'inst-test',
        playerInput: 'I explore the cave',
      );
      cubit.emit(cubit.state.copyWith(
        events: [seedEvent, optimisticEvent],
        isGenerating: true,
      ));
      await tester.pump();

      expect(find.byType(StarterStoryLink), findsNothing);
    });

    testWidgets('back button navigates to /discover when starter=true', (tester) async {
      var visitedDiscover = false;
      final ws = _TestWsManager();
      addTearDown(ws.dispose);
      final cubit = PlayCubit(instanceId: 'inst-test', ws: ws);
      addTearDown(cubit.close);

      cubit.emit(cubit.state.copyWith(
        isLoading: false,
        isConnected: true,
        template: WorldTemplate.fromJson({'_id': 't1', 'title': 'The Realm'}),
        instance: WorldInstance.fromJson({'_id': 'inst-test', 'template_id': 't1', 'player_id': 'p1'}),
        events: [],
        totalEvents: 0,
      ));

      final testRouter = GoRouter(
        initialLocation: '/play/inst-test',
        routes: [
          GoRoute(
            path: '/play/:instanceId',
            builder: (context, state) => PlayScreen(
              instanceId: 'inst-test',
              starter: true,
              cubit: cubit,
            ),
          ),
          GoRoute(
            path: '/discover',
            builder: (context, state) {
              visitedDiscover = true;
              return const Scaffold(body: Text('Discover Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: testRouter,
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pumpAndSettle();

      expect(visitedDiscover, isTrue);
      expect(find.text('Discover Screen'), findsOneWidget);
    });

    testWidgets('system back (PopScope) navigates to /discover when starter=true', (tester) async {
      var visitedDiscover = false;
      final ws = _TestWsManager();
      addTearDown(ws.dispose);
      final cubit = PlayCubit(instanceId: 'inst-test', ws: ws);
      addTearDown(cubit.close);

      cubit.emit(cubit.state.copyWith(
        isLoading: false,
        isConnected: true,
        template: WorldTemplate.fromJson({'_id': 't1', 'title': 'The Realm'}),
        instance: WorldInstance.fromJson({'_id': 'inst-test', 'template_id': 't1', 'player_id': 'p1'}),
        events: [],
        totalEvents: 0,
      ));

      final testRouter = GoRouter(
        initialLocation: '/play/inst-test',
        routes: [
          GoRoute(
            path: '/play/:instanceId',
            builder: (context, state) => PlayScreen(
              instanceId: 'inst-test',
              starter: true,
              cubit: cubit,
            ),
          ),
          GoRoute(
            path: '/discover',
            builder: (context, state) {
              visitedDiscover = true;
              return const Scaffold(body: Text('Discover Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: testRouter,
        ),
      );
      await tester.pump();

      final popScopeFinder = find.byWidgetPredicate((w) => w is PopScope);
      expect(popScopeFinder, findsOneWidget);
      final popScope = tester.widget<PopScope>(popScopeFinder);
      expect(popScope.canPop, isFalse);

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      await navigator.maybePop();
      await tester.pumpAndSettle();

      expect(visitedDiscover, isTrue);
      expect(find.text('Discover Screen'), findsOneWidget);
    });
  });
}
