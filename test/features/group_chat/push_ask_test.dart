import 'package:everlore/core/reminders/push_ask.dart';
import 'package:everlore/core/reminders/reminder_record.dart';
import 'package:everlore/features/group_chat/state/group_chat_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'group_chat_cubit_test.dart' show completeFrame;

/// A [PushAsk] over plain fields, with the same rules as production.
class _Rig {
  _Rig({this.signedIn = true, this.granted = false, this.asked = false});

  bool signedIn;
  bool granted;
  bool asked;
  int systemAsks = 0;
  int records = 0;

  late final ask = PushAsk(
    signedIn: () async => signedIn,
    permissionGranted: () async => granted,
    stillOpen: () => !asked,
    record: () async {
      records++;
      asked = true;
    },
    askSystem: () async {
      systemAsks++;
      return true;
    },
  );
}

Future<int> _dueCount(
  _Rig rig,
  Future<void> Function(GroupChatCubit, FakeGateway) play,
) async {
  final gateway = FakeGateway()..connected = true;
  final cubit = GroupChatCubit(
    instanceId: instanceId,
    gateway: gateway,
    repository: FakeRepository(),
    clock: FakeClock(),
    pushAsk: rig.ask,
  );
  var due = 0;
  final sub = cubit.pushAskDue.listen((_) => due++);
  await cubit.start();
  gateway.pushLoaded(loadedFrame());
  await play(cubit, gateway);
  await Future<void>.delayed(Duration.zero);
  await sub.cancel();
  await cubit.close();
  return due;
}

Future<void> _reply(
  GroupChatCubit cubit,
  FakeGateway gateway,
  String job, {
  bool lines = true,
}) async {
  cubit.send('hello $job');
  gateway.pushAck(job);
  gateway.pushComplete(
    completeFrame(
      jobId: job,
      eventId: 'e$job',
      sequence: job.hashCode.abs() % 1000,
      playerInput: 'hello $job',
      lines: lines ? [storedLine(jess, 'hi back', DateTime.now())] : [],
    ),
  );
}

void main() {
  group('when the ask is due', () {
    test('once, after the first character reply to the player', () async {
      final due = await _dueCount(_Rig(), (c, g) async {
        await _reply(c, g, 'j1');
        await _reply(c, g, 'j2');
      });
      expect(due, 1);
    });

    test('not when the turn brought no character line', () async {
      final due = await _dueCount(_Rig(), (c, g) async {
        await _reply(c, g, 'j1', lines: false);
      });
      expect(due, 0);
    });

    test('not for a message that was waiting (no send of ours)', () async {
      final due = await _dueCount(_Rig(), (c, g) async {
        g.pushLines({
          'type': 'group_lines',
          'instanceId': instanceId,
          'lines': [storedLine(jess, 'hey you', DateTime.now())],
        });
      });
      expect(due, 0);
    });

    test('not when the phone already allows it', () async {
      final due = await _dueCount(
        _Rig(granted: true),
        (c, g) => _reply(c, g, 'j1'),
      );
      expect(due, 0);
    });

    test('not after an earlier answer, from either sheet', () async {
      final due = await _dueCount(
        _Rig(asked: true),
        (c, g) => _reply(c, g, 'j1'),
      );
      expect(due, 0);
    });

    test('not for a guest', () async {
      final due = await _dueCount(
        _Rig(signedIn: false),
        (c, g) => _reply(c, g, 'j1'),
      );
      expect(due, 0);
    });
  });

  group('the answer', () {
    test('yes is stored, then the system dialog is shown', () async {
      final rig = _Rig();
      await rig.ask.answer(yes: true);
      expect(rig.records, 1);
      expect(rig.systemAsks, 1);
      expect(await rig.ask.due(), isFalse);
    });

    test('not now is stored and shows nothing', () async {
      final rig = _Rig();
      await rig.ask.answer(yes: false);
      expect(rig.records, 1);
      expect(rig.systemAsks, 0);
    });

    test('only one screen can claim the sheet', () {
      final rig = _Rig();
      expect(rig.ask.claim(), isTrue);
      expect(rig.ask.claim(), isFalse);
    });
  });

  group('the stored answer', () {
    test('round-trips with the story ask state', () {
      final record = const ReminderRecord(
        askCount: 1,
      ).copyWith(pushAsked: true);
      final back = ReminderRecord.decode(record.encode());
      expect(back.pushAsked, isTrue);
      expect(back.askCount, 1);
      expect(
        ReminderRecord.decode(const ReminderRecord().encode()).pushAsked,
        isFalse,
      );
    });
  });
}
