import 'package:everlore/core/guest/guest_limit.dart';
import 'package:everlore/core/guest/guest_session.dart';
import 'package:everlore/features/play/state/play_cubit.dart';
import 'package:everlore/shared/models/user.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fast_reply_send_test.dart'
    show FakeAudioPlaybackController, FakeMediaRepository, FrameWs, settle;

const _iid = 'inst_limit';

User _user({bool guest = true, int turns = 0}) => User(
  id: 'u1',
  email: '',
  username: 'wanderer',
  tier: 'free',
  guest: guest,
  guestTurns: turns,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('pure helpers', () {
    test('prompts only at the limit, after streaming, once', () {
      bool p(int used, {bool streaming = false, bool done = false}) =>
          shouldPromptKeepStory(
            used: used,
            limit: kGuestTurnLimit,
            streaming: streaming,
            alreadyPrompted: done,
          );
      expect(p(kGuestTurnLimit - 1), isFalse);
      expect(p(kGuestTurnLimit, streaming: true), isFalse);
      expect(p(kGuestTurnLimit), isTrue);
      expect(p(kGuestTurnLimit, done: true), isFalse);
    });

    test('guide gating for each condition', () {
      bool may({
        bool guest = true,
        int used = 0,
        bool focused = false,
        bool empty = true,
        bool sheet = false,
      }) => mayAutoStartGuide(
        isGuest: guest,
        used: used,
        limit: kGuestTurnLimit,
        inputFocused: focused,
        draftEmpty: empty,
        keepStoryShowing: sheet,
      );
      expect(may(), isTrue);
      expect(may(used: kGuestTurnLimit), isFalse, reason: 'spent guest');
      expect(may(sheet: true), isFalse, reason: 'sheet showing');
      expect(may(focused: true), isFalse, reason: 'typing');
      expect(may(empty: false), isFalse, reason: 'draft present');
      // Signed-in players are unchanged by the count and the sheet.
      expect(may(guest: false, used: 99, sheet: true), isTrue);
      expect(may(guest: false, focused: true), isFalse);
    });

    test('a refusal hands the typed line back, else the held one', () {
      expect(
        draftAfterRefusal(droppedInput: 'open it', queued: 'x'),
        'open it',
      );
      expect(draftAfterRefusal(droppedInput: '  ', queued: 'held'), 'held');
      expect(draftAfterRefusal(), isNull);
    });
  });

  group('GuestSession count', () {
    late GuestSession session;
    late int raised;
    // The sign-in signal is global, so each group removes its own listener.
    void bump() => raised++;

    // The sheet waits a reading pause after the last reply; here a single
    // event-loop turn stands in for it.
    Future<void> pause() => Future<void>.delayed(Duration.zero);

    setUp(() {
      GuestSession.keepStoryReadingPause = Duration.zero;
      session = GuestSession();
      raised = 0;
      session.signInRequired.addListener(bump);
    });

    tearDown(() => session.signInRequired.removeListener(bump));

    test('seeds from the user and prompts once at the last reply', () async {
      session.noteUser(_user(turns: 3));
      expect(session.turnsUsed, 3);
      session.noteTurnCompleted(); // 4th
      await pause();
      expect(raised, 0);
      session.noteTurnCompleted(); // 5th
      expect(raised, 0, reason: 'not before the reading pause');
      await pause();
      expect(raised, 1);
      expect(session.turnsSpent, isTrue);
      session.noteTurnCompleted();
      await pause();
      expect(raised, 1);
    });

    test(
      'a reply still streaming does not raise it; the next landing does',
      () async {
        session.noteUser(_user(turns: 3));
        session.noteTurnCompleted(streaming: true); // 4th
        session.noteTurnCompleted(streaming: true); // 5th, mid-stream
        await pause();
        expect(raised, 0);
        session.noteTurnCompleted();
        await pause();
        expect(raised, 1);
      },
    );

    test('claimed or merged guests are never counted or prompted', () async {
      session.noteUser(_user(guest: false, turns: 4));
      for (var i = 0; i < 8; i++) {
        session.noteTurnCompleted();
      }
      await pause();
      expect(session.turnsUsed, 0);
      expect(raised, 0);
      session.noteUser(_user(turns: 4));
      session.noteUser(_user(guest: false));
      expect(session.turnsUsed, 0);
    });

    test('a stale user never lowers the count', () {
      session.noteUser(_user(turns: 2));
      session.noteTurnCompleted();
      session.noteUser(_user(turns: 2));
      expect(session.turnsUsed, 3);
      session.clear();
      expect(session.turnsUsed, 0);
    });
  });

  group('PlayCubit', () {
    late FrameWs ws;
    late PlayCubit cubit;
    late GuestSession session;
    late int raised;
    var n = 0;
    void bump() => raised++;

    setUp(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (call) async => null,
          );
      session = GuestSession();
      GuestSession.replaceInstance(session);
      raised = 0;
      session.signInRequired.addListener(bump);
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
      session.signInRequired.removeListener(bump);
      await cubit.close();
      ws.dispose();
      GuestSession.replaceInstance(GuestSession());
    });

    Map<String, dynamic> frame(String job, [Map<String, dynamic>? extra]) => {
      'instanceId': _iid,
      'jobId': job,
      ...?extra,
    };

    /// One whole turn: send, stream, and (unless [finish] is false) complete.
    Future<void> turn(String text, {bool finish = true}) async {
      final job = 'job${++n}';
      await cubit.sendMessage(text);
      ws.push('ack', {'type': 'ack', 'jobId': job});
      ws.push('started', frame(job));
      ws.push('delta', frame(job, {'delta': 'Prose $n.'}));
      ws.push('stream_end', frame(job, {'narrative': 'Prose $n.'}));
      if (!finish) {
        await settle();
        return;
      }
      ws.push(
        'complete',
        frame(job, {
          'event': {'id': 'ev$n', 'sequence': n, 'narrative': 'Prose $n.'},
        }),
      );
      await settle();
    }

    test(
      'the sheet comes with the 5th reply, not the 4th or mid-stream',
      () async {
        session.noteUser(_user(turns: 0));
        for (var i = 0; i < 3; i++) {
          await turn('line $i');
        }
        await turn('line 3');
        expect(session.turnsUsed, 4);
        expect(raised, 0);

        await turn('line 4', finish: false);
        expect(raised, 0, reason: 'the 5th reply is still streaming');
        ws.push(
          'complete',
          frame('job$n', {
            'event': {'id': 'ev$n', 'sequence': n, 'narrative': 'Prose $n.'},
          }),
        );
        await settle();
        expect(session.turnsUsed, 5);
        expect(raised, 1);
        expect(cubit.state.isGenerating, isFalse);
      },
    );

    test(
      'a refused or failed turn is not counted and keeps the draft',
      () async {
        session.noteUser(_user(turns: 2));
        await cubit.sendMessage('a line I typed');
        ws.push('error', {
          'type': 'error',
          'code': 'SIGN_IN_REQUIRED',
          'message': 'Keep your story.',
        });
        await settle();
        expect(session.turnsUsed, 2);
        expect(cubit.state.restoreComposerText, 'a line I typed');

        await cubit.sendMessage('another');
        ws.push('ack', {'type': 'ack', 'jobId': 'jobF'});
        ws.push(
          'error',
          frame('jobF', {'type': 'generation_failed', 'message': 'x'}),
        );
        await settle();
        expect(session.turnsUsed, 2);
      },
    );

    test('a signed-in player is never counted', () async {
      session.noteUser(_user(guest: false));
      final before = raised;
      for (var i = 0; i < 6; i++) {
        await turn('line $i');
      }
      expect(session.turnsUsed, 0);
      expect(raised, before);
    });
  });
}
