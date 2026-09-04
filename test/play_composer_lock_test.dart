import 'package:everlore/features/play/state/play_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('composer vs world-action locks', () {
    test('prose still revealing keeps the composer closed', () {
      const state = PlayState(
        isConnected: true,
        isGenerating: true,
        narrativeStreaming: true,
      );
      expect(state.composerLocked, isTrue);
      expect(state.worldActionsLocked, isTrue);
    });

    test('visible prose unlocks the composer before the turn persists', () {
      const state = PlayState(
        isConnected: true,
        isGenerating: true,
        narrativeStreaming: false,
      );
      expect(state.composerLocked, isFalse);
      expect(state.worldActionsLocked, isTrue);
    });

    test('continue and travel stay locked until generation_complete', () {
      const state = PlayState(
        isConnected: true,
        isGenerating: true,
        narrativeStreaming: false,
        hasQueuedSend: true,
      );
      expect(state.worldActionsLocked, isTrue);
      expect(state.composerLocked, isFalse);
    });

    test('rewind and replay keep both surfaces locked', () {
      const rewind = PlayState(isConnected: true, isRewinding: true);
      expect(rewind.composerLocked, isTrue);
      expect(rewind.worldActionsLocked, isTrue);

      const replay = PlayState(
        isConnected: true,
        replayingEventId: 'evt-1',
      );
      expect(replay.composerLocked, isTrue);
      expect(replay.worldActionsLocked, isTrue);
    });

    test('a settled turn unlocks everything', () {
      const state = PlayState(isConnected: true);
      expect(state.composerLocked, isFalse);
      expect(state.worldActionsLocked, isFalse);
    });
  });
}
