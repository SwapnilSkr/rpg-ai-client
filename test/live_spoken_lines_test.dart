import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everlore/core/network/ws_manager.dart';
import 'package:everlore/features/media/data/media_repository.dart';
import 'package:everlore/features/media/models/media_usage.dart';
import 'package:everlore/features/media/models/spoken_line.dart';
import 'package:everlore/features/media/presentation/spoken_line_menu.dart';
import 'package:everlore/features/media/services/audio_playback_controller.dart';
import 'package:everlore/features/play/presentation/widgets/narrative_bubble.dart';
import 'package:everlore/features/play/state/play_cubit.dart';
import 'package:everlore/shared/models/event.dart';

class TestWsManager extends Fake implements WsManager {
  final genCompleteCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final replayCompleteCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final spokenLinesCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final instanceLoadedCtrl = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get onGenerationComplete =>
      genCompleteCtrl.stream;

  @override
  Stream<Map<String, dynamic>> get onReplayComplete =>
      replayCompleteCtrl.stream;

  @override
  Stream<Map<String, dynamic>> get onSpokenLines => spokenLinesCtrl.stream;

  @override
  Stream<Map<String, dynamic>> get onInstanceLoaded =>
      instanceLoadedCtrl.stream;

  @override
  Stream<Map<String, dynamic>> get onGenerationStarted =>
      const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get onGenerationDelta =>
      const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get onGenerationStreamEnd =>
      const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get onChoicesReady =>
      const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get onGenerationRetrying =>
      const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get onGenerationReset =>
      const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get onMemoriesCurated =>
      const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get onError =>
      const Stream.empty();

  @override
  Stream<bool> get onConnectionState =>
      const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get onCharacterCodexUpdated =>
      const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get onReplayDelta =>
      const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get onMilestoneUnlocked =>
      const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get onMediaReady =>
      const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get onMediaUnseen =>
      const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get onMediaFailed =>
      const Stream.empty();

  @override
  bool get isConnected => false;

  @override
  void loadInstance(String instanceId) {}

  @override
  Future<void> connect(String token, {bool force = false}) async {}

  @override
  Future<void> disconnect({bool clearToken = false}) async {}

  @override
  void dispose() {
    genCompleteCtrl.close();
    replayCompleteCtrl.close();
    spokenLinesCtrl.close();
    instanceLoadedCtrl.close();
  }
}

class FakeMediaRepository extends Fake implements MediaRepository {
  @override
  Future<MediaUsage?> getUsage() async => null;
}

class FakeAudioPlaybackController extends Fake implements AudioPlaybackController {
  @override
  bool isLinePlaying(String eventId, String lineId) => false;
  @override
  Future<void> stop() async {}
}

Widget _testHost(Widget child) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(width: 380, child: child),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Live-arrived spoken lines', () {
    late TestWsManager ws;

    PlayCubit createCubit(String instanceId) => PlayCubit(
          instanceId: instanceId,
          ws: ws,
          mediaRepo: FakeMediaRepository(),
          audio: FakeAudioPlaybackController(),
          onRefreshInk: () async {},
        );

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (call) async => null,
      );
      ws = TestWsManager();
    });

    tearDown(() {
      ws.dispose();
    });

    test('generation_complete carrying spoken_lines gives an event whose lines are set', () async {
      final cubit = createCubit('inst_live_1');

      // Seed an optimistic event in flight.
      final opt = GameEvent.optimistic(
        instanceId: 'inst_live_1',
        playerInput: 'Look toward the horizon',
      );
      cubit.emit(cubit.state.copyWith(events: [opt], isGenerating: true));

      const rawProse = 'She pointed north. "The citadel still stands," she said.';
      ws.genCompleteCtrl.add({
        'type': 'generation_complete',
        'instanceId': 'inst_live_1',
        'event': {
          'id': 'ev_gen_1',
          'sequence': 1,
          'narrative': rawProse,
          'spoken_lines': [
            {'line_id': 'line_citadel_1', 'start': 19, 'end': 45},
          ],
        },
      });

      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.events, isNotEmpty);
      final finalEvent = cubit.state.events.firstWhere((e) => e.id == 'ev_gen_1');
      expect(finalEvent.spokenLines, hasLength(1));
      expect(finalEvent.spokenLines.single.lineId, 'line_citadel_1');
      expect(finalEvent.spokenLines.single.start, 19);
      expect(finalEvent.spokenLines.single.end, 45);

      await cubit.close();
    });

    test('replay_complete carrying spoken_lines gives an event whose lines are set', () async {
      final cubit = createCubit('inst_live_1');

      const oldProse = 'The old narrative without dialogue.';
      final existingEvent = GameEvent(
        id: 'ev_replay_1',
        instanceId: 'inst_live_1',
        sequence: 1,
        type: 'narration',
        aiResponse: oldProse,
        spokenLines: const [],
        createdAt: DateTime.now(),
      );
      cubit.emit(cubit.state.copyWith(events: [existingEvent]));

      const replayedProse = 'The captain barked, "Hold your ground!" as the wind rose.';
      ws.replayCompleteCtrl.add({
        'type': 'replay_complete',
        'instanceId': 'inst_live_1',
        'eventId': 'ev_replay_1',
        'narrative': replayedProse,
        'spoken_lines': [
          {'line_id': 'line_replay_1', 'start': 20, 'end': 39},
        ],
        'variants': [
          {'id': 'var_1', 'narrative': replayedProse},
        ],
        'selected_index': 0,
      });

      await Future<void>.delayed(Duration.zero);

      final updatedEvent =
          cubit.state.events.firstWhere((e) => e.id == 'ev_replay_1');
      expect(updatedEvent.aiResponse, replayedProse);
      expect(updatedEvent.spokenLines, hasLength(1));
      expect(updatedEvent.spokenLines.single.lineId, 'line_replay_1');
      expect(updatedEvent.spokenLines.single.start, 20);
      expect(updatedEvent.spokenLines.single.end, 39);

      // And replay_complete without lines clears lines:
      ws.replayCompleteCtrl.add({
        'type': 'replay_complete',
        'instanceId': 'inst_live_1',
        'eventId': 'ev_replay_1',
        'narrative': 'No speech in this variant.',
        'spoken_lines': [],
        'variants': [
          {'id': 'var_2', 'narrative': 'No speech in this variant.'},
        ],
        'selected_index': 0,
      });

      await Future<void>.delayed(Duration.zero);
      final clearedEvent =
          cubit.state.events.firstWhere((e) => e.id == 'ev_replay_1');
      expect(clearedEvent.spokenLines, isEmpty);

      await cubit.close();
    });

    test('an early spoken_lines frame followed by generation_complete without lines still ends with the lines set', () async {
      final cubit = createCubit('inst_live_1');

      // Optimistic event before generation_complete
      final opt = GameEvent.optimistic(
        instanceId: 'inst_live_1',
        playerInput: 'Ask for directions',
      );
      cubit.emit(cubit.state.copyWith(events: [opt], isGenerating: true));

      // 1. Worker inserts event and immediately sends spoken_lines frame BEFORE generation_complete.
      // At this moment, the event is not yet in state.events.
      ws.spokenLinesCtrl.add({
        'type': 'spoken_lines',
        'instanceId': 'inst_live_1',
        'eventId': 'ev_early_target',
        'lines': [
          {'line_id': 'line_early_1', 'start': 15, 'end': 35},
        ],
      });

      await Future<void>.delayed(Duration.zero);

      // Spoken lines should be held briefly
      expect(
        cubit.heldSpokenLinesForTesting.containsKey('ev_early_target'),
        isTrue,
      );
      expect(
        cubit.heldSpokenLinesForTesting['ev_early_target']?.single.lineId,
        'line_early_1',
      );

      // 2. Later, generation_complete lands WITHOUT spoken_lines
      const narrativeText = '*He muttered,* "Follow the old canal," *and walked off.*';
      ws.genCompleteCtrl.add({
        'type': 'generation_complete',
        'instanceId': 'inst_live_1',
        'event': {
          'id': 'ev_early_target',
          'sequence': 1,
          'narrative': narrativeText,
          // omitted or empty spoken_lines
        },
      });

      await Future<void>.delayed(Duration.zero);

      // Event now has the spoken lines from the held frame
      final landedEvent =
          cubit.state.events.firstWhere((e) => e.id == 'ev_early_target');
      expect(landedEvent.spokenLines, hasLength(1));
      expect(landedEvent.spokenLines.single.lineId, 'line_early_1');
      expect(landedEvent.spokenLines.single.start, 15);
      expect(landedEvent.spokenLines.single.end, 35);

      // The hold is consumed
      expect(
        cubit.heldSpokenLinesForTesting.containsKey('ev_early_target'),
        isFalse,
      );

      await cubit.close();
    });

    testWidgets('widget test: long-press on a line of a live-arrived turn opens the line menu', (
      tester,
    ) async {
      const rawProse = '*He whispered,* "Listen carefully," *before slipping away.*';
      final liveEvent = GameEvent(
        id: 'ev_live_turn',
        instanceId: 'inst_live_1',
        sequence: 1,
        type: 'narration',
        aiResponse: rawProse,
        spokenLines: const [
          SpokenLine(lineId: 'line_voiceable_1', start: 16, end: 35),
        ],
        createdAt: DateTime.now(),
      );

      SpokenLine? lineMenuTarget;
      bool turnMenuOpened = false;

      // Pump the NarrativeBubble with the live-arrived turn
      await tester.pumpWidget(
        _testHost(
          Builder(
            builder: (ctx) => NarrativeBubble(
              event: liveEvent,
              onLongPress: () => turnMenuOpened = true,
              onSpokenLineLongPress: (line) {
                lineMenuTarget = line;
                showSpokenLineMenu(
                  context: ctx,
                  onHearIt: () {},
                  onSeeThemSayIt: () {},
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final proseRichTextFinder = find.byWidgetPredicate(
        (w) =>
            w is RichText && w.text.toPlainText().contains('Listen carefully'),
      );
      expect(proseRichTextFinder, findsOneWidget);

      final renderParagraph =
          tester.renderObject<RenderParagraph>(proseRichTextFinder);

      // Rendered text is 'He whispered, "Listen carefully," before slipping away.'
      // The spoken line occupies rendered offsets 16 to 30.
      final boxes = renderParagraph.getBoxesForSelection(
        const TextSelection(baseOffset: 16, extentOffset: 30),
      );
      expect(boxes, isNotEmpty);

      final lineCenter =
          renderParagraph.localToGlobal(boxes.first.toRect().center);

      // Long press directly on the spoken line
      await tester.longPressAt(lineCenter);
      await tester.pumpAndSettle();

      expect(lineMenuTarget?.lineId, 'line_voiceable_1');
      // The line menu bottom sheet opens!
      expect(find.text('Hear it'), findsOneWidget);
      expect(find.text('See them say it'), findsOneWidget);
      expect(turnMenuOpened, isFalse);

      // Dismiss the bottom sheet so navigator is clean
      Navigator.of(tester.element(find.text('Hear it'))).pop();
      await tester.pumpAndSettle();
    });
  });
}
