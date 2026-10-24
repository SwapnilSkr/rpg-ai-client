import 'dart:async';
import 'package:everlore/core/network/ws_manager.dart';
import 'package:everlore/core/rating/rating_prompt.dart';
import 'package:everlore/features/play/state/play_cubit.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeReviewClient implements RatingReviewClient {
  int isAvailableCalls = 0;
  int requestReviewCalls = 0;
  bool isAvailableResult = true;
  bool throwOnAvailable = false;
  bool throwOnRequest = false;

  @override
  Future<bool> isAvailable() async {
    isAvailableCalls++;
    if (throwOnAvailable) {
      throw Exception('Play core library missing or unavailable');
    }
    return isAvailableResult;
  }

  @override
  Future<void> requestReview() async {
    requestReviewCalls++;
    if (throwOnRequest) {
      throw Exception('Play review flow failed');
    }
  }
}

class _TestWsManager extends Fake implements WsManager {
  final _genCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _errCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _emptyCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _boolCtrl = StreamController<bool>.broadcast();

  @override
  Stream<Map<String, dynamic>> get onGenerationDelta => _emptyCtrl.stream;
  @override
  Stream<Map<String, dynamic>> get onGenerationStarted => _emptyCtrl.stream;
  @override
  Stream<Map<String, dynamic>> get onGenerationComplete => _genCtrl.stream;
  @override
  Stream<Map<String, dynamic>> get onGenerationStreamEnd => _emptyCtrl.stream;
  @override
  Stream<Map<String, dynamic>> get onAck => const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get onChoicesReady => _emptyCtrl.stream;
  @override
  Stream<Map<String, dynamic>> get onGenerationRetrying => _emptyCtrl.stream;
  @override
  Stream<Map<String, dynamic>> get onGenerationReset => _emptyCtrl.stream;
  @override
  Stream<Map<String, dynamic>> get onMemoriesCurated => _emptyCtrl.stream;
  @override
  Stream<Map<String, dynamic>> get onError => _errCtrl.stream;
  @override
  Stream<bool> get onConnectionState => _boolCtrl.stream;
  @override
  Stream<Map<String, dynamic>> get onInstanceLoaded => _emptyCtrl.stream;
  @override
  Stream<Map<String, dynamic>> get onCharacterCodexUpdated => _emptyCtrl.stream;
  @override
  Stream<Map<String, dynamic>> get onReplayDelta => _emptyCtrl.stream;
  @override
  Stream<Map<String, dynamic>> get onReplayComplete => _emptyCtrl.stream;
  @override
  Stream<Map<String, dynamic>> get onWorldProjectionUpdated =>
      _emptyCtrl.stream;
  @override
  Stream<Map<String, dynamic>> get onMilestoneUnlocked => _emptyCtrl.stream;
  @override
  Stream<Map<String, dynamic>> get onSpokenLines => _emptyCtrl.stream;
  @override
  Stream<Map<String, dynamic>> get onMediaReady => _emptyCtrl.stream;
  @override
  Stream<Map<String, dynamic>> get onMediaUnseen => _emptyCtrl.stream;
  @override
  Stream<Map<String, dynamic>> get onMediaFailed => _emptyCtrl.stream;

  @override
  Future<void> disconnect({bool clearToken = false}) async {}

  void emitGenerationComplete(Map<String, dynamic> msg) => _genCtrl.add(msg);
  void emitError(Map<String, dynamic> msg) => _errCtrl.add(msg);
}

class _RecordingRatingPrompt extends Fake implements RatingPrompt {
  int recordSuccessfulTurnCalls = 0;
  int recordSetbackCalls = 0;

  @override
  Future<void> recordSuccessfulTurn() async {
    recordSuccessfulTurnCalls++;
  }

  @override
  Future<void> recordSetback() async {
    recordSetbackCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RatingPromptPolicy pure logic', () {
    const policy = RatingPromptPolicy();
    final now = DateTime(2026, 10, 21, 12, 0);

    test('refuses when successful turns < 20', () {
      const state = RatingPromptState(
        successfulTurns: 19,
        cleanStreak: 19,
        requested: false,
      );
      expect(policy.shouldAsk(state, now), isFalse);
      expect(policy.blocker(state, now), contains('successful turns (19/20)'));
    });

    test('refuses when clean streak < 3', () {
      const state = RatingPromptState(
        successfulTurns: 20,
        cleanStreak: 2,
        requested: false,
      );
      expect(policy.shouldAsk(state, now), isFalse);
      expect(policy.blocker(state, now), contains('clean streak (2/3)'));
    });

    test('refuses when already requested on this install', () {
      const state = RatingPromptState(
        successfulTurns: 50,
        cleanStreak: 50,
        requested: true,
      );
      expect(policy.shouldAsk(state, now), isFalse);
      expect(policy.blocker(state, now), contains('already requested'));
    });

    test('refuses during 60-day cooldown after prior attempt', () {
      final state = RatingPromptState(
        successfulTurns: 25,
        cleanStreak: 5,
        lastAttemptAt: now.subtract(const Duration(days: 30)),
        requested: false,
      );
      expect(policy.shouldAsk(state, now), isFalse);
      expect(policy.blocker(state, now), contains('in cooldown'));
    });

    test(
      'allows when all conditions met and cooldown elapsed (>= 60 days)',
      () {
        final state = RatingPromptState(
          successfulTurns: 20,
          cleanStreak: 3,
          lastAttemptAt: now.subtract(const Duration(days: 60)),
          requested: false,
        );
        expect(policy.shouldAsk(state, now), isTrue);
        expect(policy.blocker(state, now), isNull);
      },
    );

    test('allows on clean first-time qualification', () {
      const state = RatingPromptState(
        successfulTurns: 20,
        cleanStreak: 3,
        lastAttemptAt: null,
        requested: false,
      );
      expect(policy.shouldAsk(state, now), isTrue);
      expect(policy.blocker(state, now), isNull);
    });
  });

  group('RatingPromptStore', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('reads zero state when storage is empty', () async {
      const store = RatingPromptStore();
      final state = await store.read();
      expect(state, equals(RatingPromptState.zero));
    });

    test('persists and round-trips state', () async {
      const store = RatingPromptStore();
      final expected = RatingPromptState(
        successfulTurns: 22,
        cleanStreak: 5,
        lastAttemptAt: DateTime(2026, 10, 21, 10, 0),
        requested: true,
      );

      await store.write(expected);
      final read = await store.read();

      expect(read.successfulTurns, equals(22));
      expect(read.cleanStreak, equals(5));
      expect(read.lastAttemptAt, equals(expected.lastAttemptAt));
      expect(read.requested, isTrue);
    });

    test('corrupt stored value reads as zero state', () async {
      FlutterSecureStorage.setMockInitialValues({
        'rating_prompt_state': 'this is not valid json { [ ]',
      });
      const store = RatingPromptStore();
      final state = await store.read();
      expect(state, equals(RatingPromptState.zero));
    });

    test(
      'malformed field types in stored JSON read safely as zero state defaults',
      () async {
        FlutterSecureStorage.setMockInitialValues({
          'rating_prompt_state':
              '{"successful_turns":"corrupt","clean_streak":null,"requested":"not-bool"}',
        });
        const store = RatingPromptStore();
        final state = await store.read();
        expect(state.successfulTurns, equals(0));
        expect(state.cleanStreak, equals(0));
        expect(state.requested, isFalse);
        expect(state.lastAttemptAt, isNull);
      },
    );
  });

  group('RatingPrompt service requirements', () {
    late _FakeReviewClient client;
    late DateTime simulatedNow;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      client = _FakeReviewClient();
      simulatedNow = DateTime(2026, 10, 21, 12, 0);
    });

    RatingPrompt createService({RatingPromptStore? store}) {
      return RatingPrompt(
        store: store ?? const RatingPromptStore(),
        client: client,
        now: () => simulatedNow,
      );
    }

    test(
      '19 clean turns → no call; 20th → isAvailable + requestReview called once',
      () async {
        final service = createService();

        for (int i = 1; i <= 19; i++) {
          await service.recordSuccessfulTurn();
          expect(
            client.isAvailableCalls,
            0,
            reason: 'Turn $i should not prompt',
          );
          expect(client.requestReviewCalls, 0);
        }

        await service.recordSuccessfulTurn(); // 20th turn
        expect(
          client.isAvailableCalls,
          1,
          reason: '20th turn should check availability',
        );
        expect(
          client.requestReviewCalls,
          1,
          reason: '20th turn should request review',
        );

        final state = await service.getStateForTesting();
        expect(state.successfulTurns, 20);
        expect(state.cleanStreak, 20);
        expect(state.requested, isTrue);
        expect(state.lastAttemptAt, equals(simulatedNow));
      },
    );

    test('turn 21+ after a request → never called again', () async {
      final service = createService();

      for (int i = 1; i <= 20; i++) {
        await service.recordSuccessfulTurn();
      }
      expect(client.requestReviewCalls, 1);

      // Subsequent turns 21 to 25
      for (int i = 21; i <= 25; i++) {
        simulatedNow = simulatedNow.add(const Duration(days: 1));
        await service.recordSuccessfulTurn();
        expect(
          client.isAvailableCalls,
          1,
          reason: 'Should not re-query availability',
        );
        expect(
          client.requestReviewCalls,
          1,
          reason: 'Turn $i must not re-prompt',
        );
      }
    });

    test(
      'a setback on turn 19 → turn 20 and 21 don\'t ask, turn 22 (3rd clean) does',
      () async {
        final service = createService();

        // 19 clean turns
        for (int i = 1; i <= 19; i++) {
          await service.recordSuccessfulTurn();
        }
        expect(client.requestReviewCalls, 0);

        // Setback occurs (error, resting, refund, or paywall)
        await service.recordSetback();
        var state = await service.getStateForTesting();
        expect(state.cleanStreak, 0);
        expect(state.successfulTurns, 19);

        // Turn 20 (1st clean turn after setback)
        await service.recordSuccessfulTurn();
        expect(
          client.requestReviewCalls,
          0,
          reason: 'Turn 20 has clean streak 1 < 3',
        );

        // Turn 21 (2nd clean turn after setback)
        await service.recordSuccessfulTurn();
        expect(
          client.requestReviewCalls,
          0,
          reason: 'Turn 21 has clean streak 2 < 3',
        );

        // Turn 22 (3rd clean turn after setback) -> qualifies!
        await service.recordSuccessfulTurn();
        expect(
          client.isAvailableCalls,
          1,
          reason: 'Turn 22 has clean streak 3 and >= 20 turns',
        );
        expect(client.requestReviewCalls, 1);

        state = await service.getStateForTesting();
        expect(state.successfulTurns, 22);
        expect(state.cleanStreak, 3);
        expect(state.requested, isTrue);
      },
    );

    test(
      'unavailable on turn 20 → no request, no retry on turns 21..N until clock passes 60 days, then asks again',
      () async {
        client.isAvailableResult = false;
        final service = createService();

        // Turns 1 to 20
        for (int i = 1; i <= 20; i++) {
          await service.recordSuccessfulTurn();
        }

        expect(client.isAvailableCalls, 1);
        expect(
          client.requestReviewCalls,
          0,
          reason: 'No review request if unavailable',
        );

        var state = await service.getStateForTesting();
        expect(state.requested, isFalse);
        expect(state.lastAttemptAt, equals(simulatedNow));

        // Turns 21 to 25 within the 60-day window
        for (int i = 21; i <= 25; i++) {
          simulatedNow = simulatedNow.add(const Duration(days: 5));
          await service.recordSuccessfulTurn();
          expect(
            client.isAvailableCalls,
            1,
            reason: 'Cooldown active; turn $i should not query',
          );
          expect(client.requestReviewCalls, 0);
        }

        // Turn on day 59 after attempt (still in cooldown)
        simulatedNow = DateTime(
          2026,
          10,
          21,
          12,
          0,
        ).add(const Duration(days: 59));
        await service.recordSuccessfulTurn();
        expect(
          client.isAvailableCalls,
          1,
          reason: 'Day 59 is still in cooldown',
        );

        // Now Play becomes available and 60 days have passed
        client.isAvailableResult = true;
        simulatedNow = DateTime(
          2026,
          10,
          21,
          12,
          0,
        ).add(const Duration(days: 60));

        await service.recordSuccessfulTurn();
        expect(
          client.isAvailableCalls,
          2,
          reason: 'Cooldown elapsed; asks again',
        );
        expect(
          client.requestReviewCalls,
          1,
          reason: 'Review requested on eligible retry',
        );

        state = await service.getStateForTesting();
        expect(state.requested, isTrue);
      },
    );

    test('plugin throwing counts as an attempt and doesn\'t crash', () async {
      client.throwOnAvailable = true;
      final service = createService();

      // Turns 1 to 19
      for (int i = 1; i <= 19; i++) {
        await service.recordSuccessfulTurn();
      }

      // 20th turn triggers attempt, client throws, but service does not throw
      await expectLater(service.recordSuccessfulTurn(), completes);
      expect(client.isAvailableCalls, 1);
      expect(client.requestReviewCalls, 0);

      final state = await service.getStateForTesting();
      expect(state.successfulTurns, 20);
      expect(state.lastAttemptAt, equals(simulatedNow));
      expect(state.requested, isFalse);

      // Turn 21 right after does not throw and does not re-attempt (in cooldown)
      await expectLater(service.recordSuccessfulTurn(), completes);
      expect(
        client.isAvailableCalls,
        1,
        reason: 'Cooldown active after throwing attempt',
      );
    });

    test(
      'plugin throwing on requestReview counts as an attempt and doesn\'t crash',
      () async {
        client.throwOnRequest = true;
        final service = createService();

        for (int i = 1; i <= 19; i++) {
          await service.recordSuccessfulTurn();
        }

        await expectLater(service.recordSuccessfulTurn(), completes);
        expect(client.isAvailableCalls, 1);
        expect(client.requestReviewCalls, 1);

        final state = await service.getStateForTesting();
        expect(state.lastAttemptAt, equals(simulatedNow));
        expect(state.requested, isFalse);

        // Next turn is suppressed by cooldown
        await service.recordSuccessfulTurn();
        expect(client.isAvailableCalls, 1);
      },
    );

    test(
      'state survives a new store/service instance (persistence round-trip)',
      () async {
        final service1 = createService();

        for (int i = 1; i <= 20; i++) {
          await service1.recordSuccessfulTurn();
        }
        expect(client.requestReviewCalls, 1);

        // Fresh service instance with fresh store instance sharing same storage
        final service2 = createService();
        final reloadedState = await service2.getStateForTesting();

        expect(reloadedState.successfulTurns, 20);
        expect(reloadedState.cleanStreak, 20);
        expect(reloadedState.requested, isTrue);

        // Recording another turn on service2 does not prompt
        await service2.recordSuccessfulTurn();
        expect(
          client.requestReviewCalls,
          1,
          reason: 'Already requested state persisted',
        );
      },
    );

    test('rapid serialized turns do not double-request', () async {
      final service = createService();

      // Fast-forward to turn 19
      for (int i = 1; i <= 19; i++) {
        await service.recordSuccessfulTurn();
      }

      // Fire turn 20 and turn 21 concurrently without awaiting the first
      final f1 = service.recordSuccessfulTurn();
      final f2 = service.recordSuccessfulTurn();
      await Future.wait([f1, f2]);

      expect(
        client.isAvailableCalls,
        1,
        reason: 'Only one check made across concurrent calls',
      );
      expect(
        client.requestReviewCalls,
        1,
        reason: 'Only one request made across concurrent calls',
      );

      final state = await service.getStateForTesting();
      expect(state.successfulTurns, 21);
      expect(state.requested, isTrue);
    });
  });

  group('PlayCubit rating integration', () {
    late _TestWsManager ws;
    late _RecordingRatingPrompt rating;

    setUp(() {
      ws = _TestWsManager();
      rating = _RecordingRatingPrompt();
    });

    test('generation_complete invokes recordSuccessfulTurn()', () async {
      final cubit = PlayCubit(
        instanceId: 'test_inst',
        ws: ws,
        rating: rating,
        onRefreshInk: () async {},
      );

      expect(rating.recordSuccessfulTurnCalls, 0);

      ws.emitGenerationComplete({
        'instanceId': 'test_inst',
        'event': {
          'id': 'ev_1',
          'sequence': 1,
          'narrative': 'The gates open wide.',
          'event_type': 'narration',
        },
      });

      await pumpEventQueue();

      expect(rating.recordSuccessfulTurnCalls, 1);
      expect(rating.recordSetbackCalls, 0);

      await cubit.close();
    });

    test('error invokes recordSetback()', () async {
      final cubit = PlayCubit(
        instanceId: 'test_inst',
        ws: ws,
        rating: rating,
        onRefreshInk: () async {},
      );

      expect(rating.recordSetbackCalls, 0);

      ws.emitError({
        'instanceId': 'test_inst',
        'code': 'RATE_LIMITED',
        'message': 'Slow down, traveler.',
      });

      await pumpEventQueue();

      expect(rating.recordSetbackCalls, 1);
      expect(rating.recordSuccessfulTurnCalls, 0);

      await cubit.close();
    });
  });
}
