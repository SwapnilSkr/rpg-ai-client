import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everlore/core/network/ws_manager.dart';
import 'package:everlore/features/media/data/media_repository.dart';
import 'package:everlore/features/media/models/media_usage.dart';
import 'package:everlore/features/media/services/audio_playback_controller.dart';
import 'package:everlore/features/play/state/play_cubit.dart';

const _iid = 'inst_fast';

/// A socket whose frames the test pushes in exact server order, and which
/// records every send the cubit makes.
class FrameWs extends Fake implements WsManager {
  final ctrls = <String, StreamController<Map<String, dynamic>>>{};
  final connectionCtrl = StreamController<bool>.broadcast();
  final sends = <String>[];

  StreamController<Map<String, dynamic>> _c(String name) =>
      ctrls.putIfAbsent(name, () => StreamController.broadcast());
  void push(String name, Map<String, dynamic> frame) => _c(name).add(frame);

  @override
  Stream<bool> get onConnectionState => connectionCtrl.stream;
  @override
  Stream<Map<String, dynamic>> get onAck => _c('ack').stream;
  @override
  Stream<Map<String, dynamic>> get onGenerationStarted => _c('started').stream;
  @override
  Stream<Map<String, dynamic>> get onGenerationDelta => _c('delta').stream;
  @override
  Stream<Map<String, dynamic>> get onGenerationStreamEnd =>
      _c('stream_end').stream;
  @override
  Stream<Map<String, dynamic>> get onChoicesReady => _c('choices').stream;
  @override
  Stream<Map<String, dynamic>> get onGenerationComplete =>
      _c('complete').stream;
  @override
  Stream<Map<String, dynamic>> get onGenerationReset => _c('reset').stream;
  @override
  Stream<Map<String, dynamic>> get onGenerationRetrying =>
      _c('retrying').stream;
  @override
  Stream<Map<String, dynamic>> get onError => _c('error').stream;
  @override
  Stream<Map<String, dynamic>> get onInstanceLoaded => _c('loaded').stream;
  @override
  Stream<Map<String, dynamic>> get onMemoriesCurated => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> get onCharacterCodexUpdated =>
      const Stream.empty();
  @override
  Stream<Map<String, dynamic>> get onReplayDelta => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> get onReplayComplete => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> get onMilestoneUnlocked => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> get onSpokenLines => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> get onMediaReady => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> get onMediaUnseen => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> get onMediaFailed => const Stream.empty();
  @override
  bool get isConnected => true;
  @override
  void loadInstance(String instanceId) {}
  @override
  Future<void> connect(String token, {bool force = false}) async {}
  @override
  Future<void> disconnect({bool clearToken = false}) async {}
  @override
  void sendChatMessage(String instanceId, String message) =>
      sends.add('chat:$message');
  @override
  void sendContinue(String instanceId, {String? advance}) =>
      sends.add('continue');
  @override
  void sendWorldAction(String instanceId, Map<String, dynamic> payload) =>
      sends.add('world:${payload['kind']}');
  @override
  void dispose() {
    for (final c in ctrls.values) {
      c.close();
    }
    connectionCtrl.close();
  }
}

class FakeMediaRepository extends Fake implements MediaRepository {
  @override
  Future<MediaUsage?> getUsage() async => null;
}

class FakeAudioPlaybackController extends Fake
    with ChangeNotifier
    implements AudioPlaybackController {
  @override
  bool isLinePlaying(String eventId, String lineId) => false;
  @override
  Future<void> stop() async {}
}

Map<String, dynamic> f([String? jobId, Map<String, dynamic> extra = const {}]) =>
    {'instanceId': _iid, if (jobId != null) 'jobId': jobId, ...extra};

Map<String, dynamic> complete(String? jobId, String id, int seq, String text) =>
    f(jobId, {
      'event': {
        'id': id,
        'sequence': seq,
        'narrative': text,
        'choices': [
          {'label': 'Choice of $id', 'value': 'v'},
        ],
      },
    });

/// Lets the 18 ms reveal loop paint everything it has.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 250));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FrameWs ws;
  late PlayCubit cubit;

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
    ws = FrameWs();
    cubit = PlayCubit(
      instanceId: _iid,
      ws: ws,
      mediaRepo: FakeMediaRepository(),
      audio: FakeAudioPlaybackController(),
      onRefreshInk: () async {},
    );
    ws.connectionCtrl.add(true);
    await pumpEventQueue();
  });

  tearDown(() async {
    await cubit.close();
    ws.dispose();
  });

  /// Turn N, sent and streamed to its prose end; still settling server-side.
  Future<void> streamFirstTurn({String? jobId = 'jobN'}) async {
    await cubit.sendMessage('first line');
    if (jobId != null) ws.push('ack', {'type': 'ack', 'jobId': jobId});
    ws.push('started', f(jobId));
    ws.push('delta', f(jobId, {'delta': 'The door creaks.'}));
    ws.push('stream_end', f(jobId, {'narrative': 'The door creaks.'}));
    await settle();
  }

  GameEventView bubbles() => GameEventView(cubit.state.events);

  test('(a) a reply after the prose ends sends at once, with no hold', () async {
    await streamFirstTurn();
    expect(cubit.state.isGenerating, isTrue);
    expect(cubit.state.nextTurnReady, isTrue);
    await cubit.sendMessage('second line');
    expect(ws.sends, ['chat:first line', 'chat:second line']);
    expect(cubit.state.hasQueuedSend, isFalse);
    expect(cubit.state.notice, isNot('Sending when this scene settles…'));
    // N stays on screen as a settling bubble; N+1 is the in-flight one.
    expect(bubbles().optimisticInputs, ['second line']);
    expect(bubbles().settledTexts, contains('The door creaks.'));
  });

  test('(b) N finishes on its own bubble while N+1 keeps loading, then streams',
      () async {
    await streamFirstTurn();
    await cubit.sendMessage('second line');
    ws.push('ack', {'type': 'ack', 'jobId': 'jobN1'});
    ws.push('started', f('jobN1'));
    ws.push('choices', f('jobN', {'choices': [{'label': 'Late chip', 'value': 'x'}]}));
    ws.push('complete', complete('jobN', 'evN', 10, 'The door creaks.'));
    await settle();
    final n = cubit.state.events.firstWhere((e) => e.id == 'evN');
    expect(n.isOptimistic, isFalse);
    expect(n.choices.map((c) => c.label), ['Choice of evN']);
    expect(n.playerInput, 'first line');
    // N+1 untouched: still generating, its bubble still pending and chip-free.
    expect(cubit.state.isGenerating, isTrue);
    expect(cubit.state.narrativeStreaming, isTrue);
    final next = cubit.state.events.last;
    expect(next.isOptimistic, isTrue);
    expect(next.playerInput, 'second line');
    expect(next.choices, isEmpty);

    ws.push('delta', f('jobN1', {'delta': 'A voice answers.'}));
    ws.push('stream_end', f('jobN1', {'narrative': 'A voice answers.'}));
    ws.push('complete', complete('jobN1', 'evN1', 11, 'A voice answers.'));
    await settle();
    expect(cubit.state.isGenerating, isFalse);
    expect(cubit.state.events.map((e) => e.id).where((id) => id.startsWith('ev')),
        ['evN', 'evN1']);
    expect(cubit.state.events.where((e) => e.isOptimistic), isEmpty);
  });

  test('(c) N+1 started before its ack is safe', () async {
    await streamFirstTurn();
    await cubit.sendMessage('second line');
    ws.push('started', f('jobN1'));
    ws.push('ack', {'type': 'ack', 'jobId': 'jobN1'});
    ws.push('complete', complete('jobN', 'evN', 10, 'The door creaks.'));
    ws.push('delta', f('jobN1', {'delta': 'A voice answers.'}));
    await settle();
    expect(cubit.state.events.firstWhere((e) => e.id == 'evN').aiResponse,
        'The door creaks.');
    expect(cubit.state.events.last.aiResponse, 'A voice answers.');
  });

  test('(d) N fails after its prose: N becomes the retryable draft, N+1 text '
      'returns to the composer, N+1 frames are ignored', () async {
    await streamFirstTurn();
    await cubit.sendMessage('second line');
    ws.push('ack', {'type': 'ack', 'jobId': 'jobN1'});
    ws.push('reset', f('jobN'));
    ws.push('error', f('jobN', {'type': 'generation_failed', 'message': 'x'}));
    await settle();
    expect(cubit.state.isGenerating, isFalse);
    expect(cubit.state.lastFailedInput, 'first line');
    expect(cubit.state.restoreComposerText, 'second line');
    expect(bubbles().optimisticInputs, ['first line']);
    expect(cubit.state.events.last.aiResponse, 'The door creaks.');
    final errorBefore = cubit.state.error;
    // The server fails N+1 too; that must not wipe N's draft.
    ws.push('reset', f('jobN1'));
    ws.push('error', f('jobN1', {'type': 'generation_failed', 'message': 'y'}));
    await settle();
    expect(cubit.state.error, errorBefore);
    expect(bubbles().optimisticInputs, ['first line']);
  });

  test('(d2) N+1 fails with no prose while N is fine: N survives and completes',
      () async {
    await streamFirstTurn();
    await cubit.sendMessage('second line');
    ws.push('ack', {'type': 'ack', 'jobId': 'jobN1'});
    ws.push('reset', f('jobN1'));
    ws.push('error', f('jobN1', {'type': 'generation_failed', 'message': 'y'}));
    await settle();
    expect(cubit.state.isGenerating, isFalse);
    expect(cubit.state.lastFailedInput, 'second line');
    expect(bubbles().settledTexts, contains('The door creaks.'));
    ws.push('complete', complete('jobN', 'evN', 10, 'The door creaks.'));
    await settle();
    expect(cubit.state.events.where((e) => e.id == 'evN'), hasLength(1));
  });

  test('(e) a third send while N+1 is pending is held, not sent', () async {
    await streamFirstTurn();
    await cubit.sendMessage('second line');
    ws.push('ack', {'type': 'ack', 'jobId': 'jobN1'});
    await cubit.sendMessage('third line');
    expect(ws.sends, ['chat:first line', 'chat:second line']);
    // N+1 is still writing, so the composer stays locked and nothing queues.
    expect(cubit.state.narrativeStreaming, isTrue);
  });

  test('(f) frames without jobId keep the hold until completion', () async {
    await streamFirstTurn(jobId: null);
    expect(cubit.state.nextTurnReady, isFalse);
    await cubit.sendMessage('second line');
    expect(ws.sends, ['chat:first line']);
    expect(cubit.state.hasQueuedSend, isTrue);
    ws.push('complete', complete(null, 'evN', 10, 'The door creaks.'));
    await settle();
    expect(ws.sends, ['chat:first line', 'chat:second line']);
  });

  test('(g) a frame with a foreign jobId is ignored', () async {
    await streamFirstTurn();
    ws.push('delta', f('someone-else', {'delta': ' STRAY'}));
    ws.push('complete', complete('someone-else', 'evX', 99, 'stray'));
    await settle();
    expect(cubit.state.isGenerating, isTrue);
    expect(cubit.state.events.where((e) => e.id == 'evX'), isEmpty);
    expect(cubit.state.events.last.aiResponse, 'The door creaks.');
  });

  test('(h) Continue after the prose ends dispatches at once', () async {
    await streamFirstTurn();
    expect(cubit.state.worldActionsLocked, isFalse);
    await cubit.continueStory();
    expect(ws.sends, ['chat:first line', 'continue']);
  });

  test('(i) before the prose ends, Continue and sends stay locked', () async {
    await cubit.sendMessage('first line');
    ws.push('ack', {'type': 'ack', 'jobId': 'jobN'});
    ws.push('delta', f('jobN', {'delta': 'Still writing'}));
    await settle();
    expect(cubit.state.worldActionsLocked, isTrue);
    await cubit.continueStory();
    await cubit.sendMessage('too soon');
    expect(ws.sends, ['chat:first line']);
  });

  test('(j) after a snapshot replaces the bubbles, N still lands by server id',
      () async {
    await streamFirstTurn();
    await cubit.sendMessage('second line');
    ws.push('ack', {'type': 'ack', 'jobId': 'jobN1'});
    ws.push('complete', complete('jobN', 'evN', 10, 'The door creaks.'));
    await settle();
    expect(cubit.state.events.where((e) => e.id == 'evN'), hasLength(1));
  });
}

/// Small read helpers over the event list.
class GameEventView {
  GameEventView(this.events);
  final List<dynamic> events;
  List<String?> get optimisticInputs =>
      events.where((e) => e.isOptimistic).map((e) => e.playerInput as String?).toList();
  List<String?> get settledTexts =>
      events.where((e) => !e.isOptimistic).map((e) => e.aiResponse as String?).toList();
}
