import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:everlore/app/theme/nexus_theme.dart';
import 'package:everlore/core/guide/guide_controller.dart';
import 'package:everlore/core/guide/guide_flows.dart';
import 'package:everlore/core/guide/guide_ids.dart';
import 'package:everlore/core/network/ws_manager.dart';
import 'package:everlore/features/media/data/media_repository.dart';
import 'package:everlore/features/media/models/spoken_line.dart';
import 'package:everlore/features/media/presentation/spoken_line_menu.dart';
import 'package:everlore/features/play/presentation/play_screen.dart';
import 'package:everlore/features/play/presentation/widgets/anchored_menu_popup.dart';
import 'package:everlore/features/play/presentation/widgets/narrative_bubble.dart';
import 'package:everlore/features/play/state/play_cubit.dart';
import 'package:everlore/shared/models/event.dart';

class _MockWsManager extends Fake implements WsManager {
  final mediaReadyCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final mediaUnseenCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final mediaFailedCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final spokenLinesCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final connectionStateCtrl = StreamController<bool>.broadcast();

  @override
  Stream<Map<String, dynamic>> get onMediaReady => mediaReadyCtrl.stream;
  @override
  Stream<Map<String, dynamic>> get onMediaUnseen => mediaUnseenCtrl.stream;
  @override
  Stream<Map<String, dynamic>> get onMediaFailed => mediaFailedCtrl.stream;
  @override
  Stream<Map<String, dynamic>> get onSpokenLines => spokenLinesCtrl.stream;
  @override
  Stream<bool> get onConnectionState => connectionStateCtrl.stream;

  @override
  Stream<Map<String, dynamic>> get onGenerationComplete => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> get onGenerationStarted => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> get onGenerationDelta => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> get onGenerationStreamEnd => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> get onChoicesReady => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> get onGenerationRetrying => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> get onGenerationReset => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> get onMemoriesCurated => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> get onError => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> get onInstanceLoaded => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> get onCharacterCodexUpdated => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> get onReplayDelta => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> get onReplayComplete => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> get onMilestoneUnlocked => const Stream.empty();

  @override
  bool get isConnected => true;
  @override
  void loadInstance(String instanceId) {}
  @override
  Future<void> disconnect({bool clearToken = false}) async {}

  @override
  void dispose() {
    mediaReadyCtrl.close();
    mediaUnseenCtrl.close();
    mediaFailedCtrl.close();
    spokenLinesCtrl.close();
    connectionStateCtrl.close();
  }
}

void main() {
  setUp(() async {
    await guide.onSignedOut();
    GuideController.arcGap = Duration.zero;
  });

  tearDown(() async {
    await guide.onSignedOut();
    GuideController.arcGap = Duration.zero;
  });

  group('Anchored Turn Options Menu', () {
    testWidgets('shows only normal options and excludes Picture this / Film this', (tester) async {
      final items = [
        AnchoredMenuItem(
          icon: const Icon(Icons.refresh_rounded),
          label: 'Replay response',
          onTap: () {},
        ),
        AnchoredMenuItem(
          icon: const Icon(Icons.copy_rounded),
          label: 'Copy response',
          onTap: () {},
        ),
        AnchoredMenuItem(
          icon: const Icon(Icons.edit_note_rounded),
          label: 'Edit response',
          onTap: () {},
        ),
        AnchoredMenuItem(
          icon: const Icon(Icons.history_rounded),
          label: 'Rewind to here',
          onTap: () {},
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => AnchoredMenuPopup(
                items: items,
                dialogContext: context,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Replay response'), findsOneWidget);
      expect(find.text('Copy response'), findsOneWidget);
      expect(find.text('Edit response'), findsOneWidget);
      expect(find.text('Rewind to here'), findsOneWidget);

      // Verify separation: Picture this and Film this must NOT appear
      expect(find.text('Picture this'), findsNothing);
      expect(find.text('Film this'), findsNothing);
    });

    testWidgets('AnchoredMenuItem onTap closes menu and executes callback', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () {
                  showAnchoredMenu(
                    context: ctx,
                    anchorRect: const Rect.fromLTWH(50, 100, 200, 50),
                    items: [
                      AnchoredMenuItem(
                        icon: const Icon(Icons.copy_rounded),
                        label: 'Copy response',
                        onTap: () {
                          tapped = true;
                        },
                      ),
                    ],
                  );
                },
                child: const Text('Open Menu'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Menu'));
      await tester.pumpAndSettle();

      expect(find.text('Copy response'), findsOneWidget);
      await tester.tap(find.text('Copy response'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
      expect(find.text('Copy response'), findsNothing); // dismissed
    });
    testWidgets('long-press popup anchors to prose box right edge, not player bubble', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final event = GameEvent(
        id: 'ev_dual_1',
        instanceId: 'inst_1',
        sequence: 1,
        type: 'narration',
        playerInput: 'I enter the throne room with caution.',
        aiResponse: 'Shadows pool between the basalt columns.',
        createdAt: DateTime.now(),
      );

      Rect? measuredAnchor;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => NarrativeBubble(
                event: event,
                onLongPress: (rect) {
                  measuredAnchor = rect;
                  showAnchoredMenu(
                    context: context,
                    anchorRect: rect,
                    items: [
                      AnchoredMenuItem(
                        icon: const Icon(Icons.copy_rounded),
                        label: 'Copy response',
                        onTap: () {},
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final playerTextFinder = find.text('I enter the throne room with caution.');
      expect(playerTextFinder, findsOneWidget);
      final proseFinder = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('Shadows pool'),
      );
      expect(proseFinder, findsOneWidget);

      // Long press prose to trigger popup
      await tester.longPress(proseFinder);
      await tester.pumpAndSettle();

      expect(measuredAnchor, isNotNull);
      expect(find.text('Copy response'), findsOneWidget);

      // Player bubble visible box right edge is 800 - 16 = 784.
      // Narrator prose panel container right edge is 800 - 40 = 760.
      final playerBubbleFinder = find.ancestor(of: playerTextFinder, matching: find.byType(ClipRRect)).first;
      final playerBubbleRect = tester.getRect(playerBubbleFinder);
      expect(playerBubbleRect.right, closeTo(800.0 - 16.0, 1.5));

      // The anchor rect is the narrator prose box only:
      // top begins below player bubble, right is exactly 800 - 40 = 760.
      expect(measuredAnchor!.top, greaterThanOrEqualTo(playerBubbleRect.bottom));
      expect(measuredAnchor!.right, equals(800.0 - 40.0));
      expect(measuredAnchor!.right, lessThan(playerBubbleRect.right));

      // The menu popup right edge aligns with the prose box right edge
      final popupFinder = find.byType(AnchoredMenuPopup);
      expect(popupFinder, findsOneWidget);
      final popupRect = tester.getRect(popupFinder);
      expect(popupRect.right, closeTo(measuredAnchor!.right, 0.5));
    });
  });

  group('Dedicated Media Trigger and Menu', () {
    testWidgets('shows Picture this and Film this with correct styling', (tester) async {
      final event = GameEvent(
        id: 'ev_1',
        instanceId: 'inst_1',
        sequence: 1,
        type: 'narration',
        aiResponse: 'A raven flew into the twilight sky.',
        createdAt: DateTime.now(),
      );

      final ws = _MockWsManager();
      addTearDown(ws.dispose);

      final client = MockClient((request) async => http.Response('{}', 200));
      final mediaRepo = MediaRepository(
        client: client,
        baseUrl: 'https://api.test',
        tokenProvider: () async => 'token',
      );

      final cubit = PlayCubit(
        instanceId: 'inst_1',
        ws: ws,
        mediaRepo: mediaRepo,
      );
      addTearDown(cubit.close);

      cubit.emit(cubit.state.copyWith(
        events: [event],
        isMediaAvailable: true,
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider<PlayCubit>.value(
              value: cubit,
              child: Builder(
                builder: (context) => NarrativeBubble(
                  event: event,
                  onMedia: (rect) {
                    showTurnMediaMenu(
                      context: context,
                      cubit: cubit,
                      eventId: event.id,
                      anchorRect: rect,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final mediaBtn = find.text('Media');
      expect(mediaBtn, findsOneWidget);
      await tester.tap(mediaBtn);
      await tester.pumpAndSettle();

      expect(find.text('Picture this'), findsOneWidget);
      expect(find.text('Film this'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AnchoredMenuPopup),
          matching: find.byIcon(Icons.auto_awesome_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AnchoredMenuPopup),
          matching: find.byIcon(Icons.videocam_outlined),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Picture this'));
      await tester.pumpAndSettle();

      expect(find.text('Picture this'), findsNothing);
    });

    testWidgets('NarrativeBubble exposes Media button alongside copy', (tester) async {
      final event = GameEvent(
        id: 'ev_narrative_1',
        instanceId: 'inst_1',
        sequence: 1,
        type: 'narration',
        aiResponse: 'The fortress towered above the dark woods.',
        createdAt: DateTime.now(),
      );

      bool mediaTapped = false;
      Rect? capturedRect;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NarrativeBubble(
              event: event,
              onMedia: (rect) {
                mediaTapped = true;
                capturedRect = rect;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the Media action button
      final mediaBtn = find.text('Media');
      expect(mediaBtn, findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);

      await tester.tap(mediaBtn);
      await tester.pumpAndSettle();

      expect(mediaTapped, isTrue);
      expect(capturedRect, isNotNull);
    });
  });

  group('Spoken Line Menu and Voiceable Marks', () {
    testWidgets('voiceable line has dotted aether decoration; unvoiceable does not', (tester) async {
      const lineText = '"Stand fast, travellers!"';
      const fullText = '$lineText he shouted.';
      final voiceableLine = SpokenLine(
        lineId: 'sp_1',
        start: 0,
        end: lineText.length,
        unvoiceable: false,
      );

      final event = GameEvent(
        id: 'ev_spoken',
        instanceId: 'inst_1',
        sequence: 1,
        type: 'narration',
        aiResponse: fullText,
        spokenLines: [voiceableLine],
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NarrativeBubble(
              event: event,
              spokenLines: [voiceableLine],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify RichText exists with the decorated span
      final richTextFinder = find.byType(RichText);
      expect(richTextFinder, findsWidgets);

      bool foundDecoratedSpan = false;
      for (final widget in tester.widgetList<RichText>(richTextFinder)) {
        widget.text.visitChildren((span) {
          if (span is TextSpan && (span.text?.contains('Stand fast') ?? false)) {
            if (span.style?.decoration == TextDecoration.underline &&
                span.style?.decorationStyle == TextDecorationStyle.dotted &&
                span.style?.decorationColor == EverloreTheme.aether.withValues(alpha: 0.45)) {
              foundDecoratedSpan = true;
            }
          }
          return true;
        });
      }
      expect(foundDecoratedSpan, isTrue);
    });

    testWidgets('unvoiceable line does not have underline decoration', (tester) async {
      const lineText = '"Stand fast, travellers!"';
      const fullText = '$lineText he shouted.';
      final unvoiceableLine = SpokenLine(
        lineId: 'sp_2',
        start: 0,
        end: lineText.length,
        unvoiceable: true,
      );

      final event = GameEvent(
        id: 'ev_unvoiceable',
        instanceId: 'inst_1',
        sequence: 1,
        type: 'narration',
        aiResponse: fullText,
        spokenLines: [unvoiceableLine],
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NarrativeBubble(
              event: event,
              spokenLines: [unvoiceableLine],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final richTextFinder = find.byType(RichText);
      expect(richTextFinder, findsWidgets);

      bool foundDecoratedSpan = false;
      for (final widget in tester.widgetList<RichText>(richTextFinder)) {
        widget.text.visitChildren((span) {
          if (span is TextSpan && (span.text?.contains('Stand fast') ?? false)) {
            if (span.style?.decoration == TextDecoration.underline) {
              foundDecoratedSpan = true;
            }
          }
          return true;
        });
      }
      expect(foundDecoratedSpan, isFalse);
    });

    testWidgets('showSpokenLineMenu opens anchored popup with Hear it and See them say it', (tester) async {
      bool hearTapped = false;
      bool filmTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  showSpokenLineMenu(
                    context: context,
                    anchorRect: const Rect.fromLTWH(60, 120, 200, 40),
                    onHearIt: () => hearTapped = true,
                    onSeeThemSayIt: () => filmTapped = true,
                  );
                },
                child: const Text('Open Spoken Menu'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Spoken Menu'));
      await tester.pumpAndSettle();

      expect(find.text('Hear it'), findsOneWidget);
      expect(find.text('See them say it'), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);

      await tester.tap(find.text('Hear it'));
      await tester.pumpAndSettle();

      expect(hearTapped, isTrue);
      expect(filmTapped, isFalse);
      expect(find.text('Hear it'), findsNothing); // dismissed
    });
  });

  group('AnchoredMenuLayoutDelegate Positioning & Flip Logic', () {
    test('places menu below anchor when room is available', () {
      const delegate = AnchoredMenuLayoutDelegate(
        anchorRect: Rect.fromLTWH(50, 100, 200, 60),
        safeArea: EdgeInsets.only(top: 24, bottom: 24, left: 16, right: 16),
        composerTop: 700,
      );

      const screenSize = Size(400, 800);
      const childSize = Size(180, 100);

      final offset = delegate.getPositionForChild(screenSize, childSize);

      // Should place below anchor bottom (100 + 60 = 160) + 4 = 164
      expect(offset.dy, equals(164.0));
      // Right edge of anchor is 50 + 200 = 250. childSize is 180, so x = 250 - 180 = 70.
      expect(offset.dx, equals(70.0));
    });

    test('flips menu above anchor when near composer / bottom bound', () {
      const delegate = AnchoredMenuLayoutDelegate(
        anchorRect: Rect.fromLTWH(50, 620, 200, 60),
        safeArea: EdgeInsets.only(top: 24, bottom: 24, left: 16, right: 16),
        composerTop: 700,
      );

      const screenSize = Size(400, 800);
      const childSize = Size(180, 100);

      // visibleRect bottom clamped to bottomBound (700 - 8 = 692).
      // spaceBelow is 692 - 680 = 12 < childSize.height + 4 (104).
      // So it must flip above: visibleRect.top (620) - 100 - 4 = 516.
      final offset = delegate.getPositionForChild(screenSize, childSize);

      expect(offset.dy, equals(516.0));
      expect(offset.dx, equals(70.0));
    });

    test('clamps horizontal position within safe area bounds', () {
      const delegate = AnchoredMenuLayoutDelegate(
        anchorRect: Rect.fromLTWH(300, 100, 100, 50), // right edge = 400 (screen boundary)
        safeArea: EdgeInsets.only(top: 24, bottom: 24, left: 16, right: 16),
        composerTop: 700,
      );

      const screenSize = Size(400, 800);
      const childSize = Size(180, 100);

      final offset = delegate.getPositionForChild(screenSize, childSize);

      // rightBound is 400 - 16 - 8 = 376.
      // x + childSize.width must not exceed rightBound: x = 376 - 180 = 196.
      expect(offset.dx, equals(196.0));
      expect(offset.dx + childSize.width, lessThanOrEqualTo(screenSize.width - 24));
    });
  });

  group('One-Time Guide Hints', () {
    test('flow IDs are registered and canAutoStart behaves correctly', () async {
      expect(GuideIds.playMedia, equals('play.media'));
      expect(GuideIds.playSpokenLine, equals('play.spoken_line'));

      expect(guide.canAutoStart(GuideFlows.playMedia), isTrue);
      expect(guide.canAutoStart(GuideFlows.spokenLine), isTrue);
    });
  });

  group('Media Notices (one-shot transient notices)', () {
    setUp(() async {
      await GuideController.instance.hydrateFromAccount(null, remoteOptOut: true);
    });

    testWidgets('an unseen media message shows a notice and leaves the composer hint at its default', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'test_token'});

      final event = GameEvent(
        id: 'ev_unseen_1',
        instanceId: 'inst_unseen',
        sequence: 1,
        type: 'narration',
        aiResponse: 'The fortress towered above the dark woods.',
        createdAt: DateTime.now(),
      );

      final ws = _MockWsManager();
      addTearDown(ws.dispose);

      final mediaRepo = MediaRepository(
        client: MockClient((request) async => http.Response('{}', 200)),
        baseUrl: 'https://api.test',
        tokenProvider: () async => 'token',
      );

      final cubit = PlayCubit(
        instanceId: 'inst_unseen',
        ws: ws,
        mediaRepo: mediaRepo,
      );
      addTearDown(cubit.close);

      cubit.emit(cubit.state.copyWith(
        isLoading: false,
        isConnected: true,
        events: [event],
        isMediaAvailable: true,
      ));

      await tester.pumpWidget(
        MaterialApp(
          theme: EverloreTheme.dark,
          home: PlayScreen(
            instanceId: 'inst_unseen',
            cubit: cubit,
          ),
        ),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Initially, composer hint is at its default ("What do you do?")
      final initialField = tester.widget<TextField>(find.byType(TextField));
      expect(initialField.decoration?.hintText, equals('What do you do?'));
      expect(cubit.state.notice, isNull);

      // Server emits media_unseen message
      ws.mediaUnseenCtrl.add({
        'type': 'media_unseen',
        'instanceId': 'inst_unseen',
        'eventId': 'ev_unseen_1',
        'media_id': 'med_1',
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Shows transient notice via showEverloreNotice
      expect(find.text('This moment stays unseen.'), findsOneWidget);

      // Leaves composer hint at its default (never stuck in composer notice)
      expect(cubit.state.notice, isNull);
      final afterField = tester.widget<TextField>(find.byType(TextField));
      expect(afterField.decoration?.hintText, equals('What do you do?'));
    });

    testWidgets('a resting outcome shows a notice and leaves the composer hint at its default', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'test_token'});

      final event = GameEvent(
        id: 'ev_resting_1',
        instanceId: 'inst_resting',
        sequence: 1,
        type: 'narration',
        aiResponse: 'A lonely road curved into the mist.',
        createdAt: DateTime.now(),
      );

      final ws = _MockWsManager();
      addTearDown(ws.dispose);

      // Fake client returning 429 resting response
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'code': 'RATE_LIMITED',
            'kind': 'video',
            'resets_at': '2026-10-17T00:00:00.000Z',
          }),
          429,
        );
      });

      final mediaRepo = MediaRepository(
        client: client,
        baseUrl: 'https://api.test',
        tokenProvider: () async => 'token',
      );

      final cubit = PlayCubit(
        instanceId: 'inst_resting',
        ws: ws,
        mediaRepo: mediaRepo,
      );
      addTearDown(cubit.close);

      cubit.emit(cubit.state.copyWith(
        isLoading: false,
        isConnected: true,
        events: [event],
        isMediaAvailable: true,
      ));

      await tester.pumpWidget(
        MaterialApp(
          theme: EverloreTheme.dark,
          home: PlayScreen(
            instanceId: 'inst_resting',
            cubit: cubit,
          ),
        ),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Request a turn video which will hit 429 MediaRestingException
      await cubit.requestTurnVideo('ev_resting_1');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Shows resting copy in notice banner
      expect(find.text('The visions rest until tomorrow.'), findsOneWidget);

      // Composer notice remains null, hint remains default
      expect(cubit.state.notice, isNull);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration?.hintText, equals('What do you do?'));
    });

    testWidgets('the notice doesn\'t re-show on an unrelated rebuild', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'test_token'});

      final event = GameEvent(
        id: 'ev_rebuild_1',
        instanceId: 'inst_rebuild',
        sequence: 1,
        type: 'narration',
        aiResponse: 'Lanterns flickered in the fog.',
        createdAt: DateTime.now(),
      );

      final ws = _MockWsManager();
      addTearDown(ws.dispose);

      final mediaRepo = MediaRepository(
        client: MockClient((request) async => http.Response('{}', 200)),
        baseUrl: 'https://api.test',
        tokenProvider: () async => 'token',
      );

      final cubit = PlayCubit(
        instanceId: 'inst_rebuild',
        ws: ws,
        mediaRepo: mediaRepo,
      );
      addTearDown(cubit.close);

      cubit.emit(cubit.state.copyWith(
        isLoading: false,
        isConnected: true,
        events: [event],
        isMediaAvailable: true,
      ));

      await tester.pumpWidget(
        MaterialApp(
          theme: EverloreTheme.dark,
          home: PlayScreen(
            instanceId: 'inst_rebuild',
            cubit: cubit,
          ),
        ),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Trigger unseen notice
      ws.mediaUnseenCtrl.add({
        'type': 'media_unseen',
        'instanceId': 'inst_rebuild',
        'eventId': 'ev_rebuild_1',
        'media_id': 'med_rebuild',
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('This moment stays unseen.'), findsOneWidget);

      // Dismiss notice by tapping it
      await tester.tap(find.text('This moment stays unseen.'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('This moment stays unseen.'), findsNothing);

      // Perform unrelated state emissions / rebuilds
      cubit.emit(cubit.state.copyWith(narrativeStreaming: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('This moment stays unseen.'), findsNothing);

      cubit.emit(cubit.state.copyWith(narrativeStreaming: false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('This moment stays unseen.'), findsNothing);

      // Force widget tree rebuild
      await tester.pumpWidget(
        MaterialApp(
          theme: EverloreTheme.dark,
          home: PlayScreen(
            instanceId: 'inst_rebuild',
            cubit: cubit,
          ),
        ),
      );
      for (int i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('This moment stays unseen.'), findsNothing);
    });
  });
}
