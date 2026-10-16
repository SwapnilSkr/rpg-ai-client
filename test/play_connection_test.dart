import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everlore/core/network/ws_manager.dart';
import 'package:everlore/features/media/data/media_repository.dart';
import 'package:everlore/features/media/models/media_usage.dart';
import 'package:everlore/features/media/services/audio_playback_controller.dart';
import 'package:everlore/features/play/state/play_cubit.dart';

class MockableWsManager extends Fake implements WsManager {
  final connectionStateCtrl = StreamController<bool>.broadcast();
  final genCompleteCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final replayCompleteCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final spokenLinesCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final instanceLoadedCtrl = StreamController<Map<String, dynamic>>.broadcast();

  bool shouldThrowOnConnect = false;
  bool shouldThrowOnLoadInstance = false;
  bool simulatedConnected = false;
  String? connectedToken;
  String? loadedInstanceId;

  @override
  Stream<bool> get onConnectionState => connectionStateCtrl.stream;

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
  bool get isConnected => simulatedConnected;

  @override
  void loadInstance(String instanceId) {
    if (shouldThrowOnLoadInstance) {
      throw Exception('Socket write error on loadInstance');
    }
    loadedInstanceId = instanceId;
  }

  @override
  Future<void> connect(String token, {bool force = false}) async {
    if (shouldThrowOnConnect) {
      throw Exception('Failed to connect to WebSocket: connection refused');
    }
    connectedToken = token;
    connectionStateCtrl.add(simulatedConnected);
  }

  @override
  Future<void> disconnect({bool clearToken = false}) async {
    simulatedConnected = false;
    connectionStateCtrl.add(false);
  }

  @override
  void dispose() {
    connectionStateCtrl.close();
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

class FakeAudioPlaybackController extends Fake
    with ChangeNotifier
    implements AudioPlaybackController {
  @override
  bool isLinePlaying(String eventId, String lineId) => false;
  @override
  Future<void> stop() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Play session connection and authentication', () {
    late MockableWsManager ws;
    String? storageTokenResult;
    bool storageShouldThrow = false;

    PlayCubit createCubit(String instanceId) => PlayCubit(
          instanceId: instanceId,
          ws: ws,
          mediaRepo: FakeMediaRepository(),
          audio: FakeAudioPlaybackController(),
          onRefreshInk: () async {},
        );

    setUp(() {
      storageTokenResult = null;
      storageShouldThrow = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (call) async {
          if (storageShouldThrow) {
            throw PlatformException(
              code: 'SECURE_STORAGE_ERROR',
              message: 'Failed to access keystore',
            );
          }
          if (call.method == 'read') {
            return storageTokenResult;
          }
          return null;
        },
      );
      ws = MockableWsManager();
    });

    tearDown(() {
      ws.dispose();
    });

    test('a missing token emits the sign-in error', () async {
      storageTokenResult = null;
      final cubit = createCubit('inst_conn_1');

      // Allow _connectAndLoad async frame to settle
      await pumpEventQueue();

      expect(cubit.state.error, 'Please sign in to load this world.');
      expect(cubit.state.isLoading, isFalse);
      expect(ws.connectedToken, isNull);

      await cubit.close();
    });

    test('an empty token emits the sign-in error', () async {
      storageTokenResult = '';
      final cubit = createCubit('inst_conn_2');

      await pumpEventQueue();

      expect(cubit.state.error, 'Please sign in to load this world.');
      expect(cubit.state.isLoading, isFalse);
      expect(ws.connectedToken, isNull);

      await cubit.close();
    });

    test('storage read exception emits the sign-in error', () async {
      storageShouldThrow = true;
      final cubit = createCubit('inst_conn_3');

      await pumpEventQueue();

      expect(cubit.state.error, 'Please sign in to load this world.');
      expect(cubit.state.isLoading, isFalse);
      expect(ws.connectedToken, isNull);

      await cubit.close();
    });

    test('a connect failure (dropped network) does not emit the sign-in error', () async {
      storageTokenResult = 'auth-token-valid';
      ws.simulatedConnected = false;

      final cubit = createCubit('inst_conn_4');

      await pumpEventQueue();

      // Successfully attempted connect with token
      expect(ws.connectedToken, 'auth-token-valid');
      // Connection failed / dropped, but NO sign-in error is emitted
      expect(cubit.state.error, isNull);
      expect(cubit.state.isConnected, isFalse);

      await cubit.close();
    });

    test('a connect failure where connect throws does not emit the sign-in error', () async {
      storageTokenResult = 'auth-token-valid';
      ws.shouldThrowOnConnect = true;

      final cubit = createCubit('inst_conn_5');

      await pumpEventQueue();

      // Connection threw, but NO sign-in error is emitted
      expect(cubit.state.error, isNull);
      expect(cubit.state.isConnected, isFalse);

      await cubit.close();
    });

    test('a failure in loadInstance does not emit the sign-in error', () async {
      storageTokenResult = 'auth-token-valid';
      ws.simulatedConnected = true;
      ws.shouldThrowOnLoadInstance = true;

      final cubit = createCubit('inst_conn_6');

      await pumpEventQueue();

      // loadInstance threw, but NO sign-in error is emitted
      expect(cubit.state.error, isNull);

      await cubit.close();
    });
  });
}
