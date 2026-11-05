import 'dart:async';

import 'package:everlore/core/network/api_client.dart';
import 'package:everlore/features/group_chat/models/group_chat_models.dart';
import 'package:everlore/features/group_chat/state/group_chat_cubit.dart';
import 'package:everlore/features/group_chat/state/group_chat_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

class Harness {
  final clock = FakeClock();
  final gateway = FakeGateway();
  final repo = FakeRepository();
  late final GroupChatCubit cubit;

  Harness({bool connected = true}) {
    gateway.connected = connected;
    cubit = GroupChatCubit(
      instanceId: instanceId,
      gateway: gateway,
      repository: repo,
      clock: clock,
    );
  }

  GroupChatState get state => cubit.state;

  /// Starts the chat and answers its first load.
  Future<void> open({Map<String, dynamic>? frame}) async {
    await cubit.start();
    gateway.pushLoaded(frame ?? loadedFrame());
  }

  List<String> texts([String? directWith]) => [
    for (final l in state.thread(directWith).lines) l.text,
  ];

  DateTime ago(int seconds) => clock.now().subtract(Duration(seconds: seconds));
  DateTime ahead(int seconds) => clock.now().add(Duration(seconds: seconds));
}

Map<String, dynamic> linesFrame(
  List<Map<String, dynamic>> lines, {
  String? directWith,
  String? turnId,
  String? eventId,
  bool partial = false,
}) => {
  'type': 'group_lines',
  'instanceId': instanceId,
  if (directWith != null) 'directWith': directWith,
  if (turnId != null) 'turnId': turnId,
  if (eventId != null) 'eventId': eventId,
  if (partial) 'partial': true,
  'lines': lines,
};

Map<String, dynamic> completeFrame({
  required String jobId,
  required String eventId,
  required int sequence,
  String playerInput = '',
  bool action = false,
  required List<Map<String, dynamic>> lines,
}) => {
  'type': 'generation_complete',
  'instanceId': instanceId,
  'jobId': jobId,
  'event': {
    'id': eventId,
    'sequence': sequence,
    'player_input': playerInput,
    if (action) 'player_action': true,
    'narrative': '',
    'origin': 'player',
    'lines': lines,
  },
};

void main() {
  group('loading', () {
    test('reads members, history, pending_from and the mature state', () async {
      final h = Harness();
      await h.open(
        frame: loadedFrame(
          matureCapable: true,
          pendingFrom: [tom],
          events: [
            eventRow(
              id: 'e1',
              sequence: 1,
              lines: [storedLine(jess, 'hi all', h.ago(100))],
            ),
            eventRow(
              id: 'e2',
              sequence: 2,
              playerInput: 'hey',
              lines: [storedLine(tom, 'yo', h.ago(60))],
            ),
          ],
        ),
      );
      expect(h.state.load, GroupChatLoad.ready);
      expect([for (final m in h.state.members) m.name], ['Jess', 'Tom']);
      expect(h.state.matureCapable, isTrue);
      expect(h.state.pendingFrom, [tom]);
      expect(h.texts(), ['hi all', 'hey', 'yo']);
      expect(h.state.thread().lines.first.name, 'Jess');
    });

    test('a missing pending_from means none, and odd fields do not throw', () async {
      final h = Harness();
      await h.open(
        frame: {
          'data': {
            'instance': {'id': instanceId},
            'recentEvents': [
              {'_id': 'e1', 'sequence': 1, 'data': {'lines': 'nonsense'}},
              'junk',
            ],
          },
        },
      );
      expect(h.state.pendingFrom, isEmpty);
      expect(h.state.matureCapable, isFalse);
      expect(h.state.load, GroupChatLoad.ready);
    });

    test('a load that never answers fails', () async {
      final h = Harness();
      await h.cubit.start();
      h.clock.advance(const Duration(seconds: 30));
      expect(h.state.load, GroupChatLoad.failed);
    });

    test('lists the direct threads', () async {
      final h = Harness();
      h.repo.threadRows = [
        const GroupThreadSummary(memberId: jess, lastLine: 'x', messageCount: 3),
      ];
      await h.open();
      await Future<void>.delayed(Duration.zero);
      expect(h.state.threadSummaries.single.memberId, jess);
    });
  });

  group('threads', () {
    test('a direct thread loads by direct_with and stays out of the group', () async {
      final h = Harness();
      await h.open(
        frame: loadedFrame(
          events: [
            eventRow(id: 'e1', sequence: 1, lines: [storedLine(jess, 'group line', h.ago(50))]),
          ],
        ),
      );
      h.cubit.selectThread(jess);
      expect(h.gateway.loads.last['direct_with'], jess);
      h.gateway.pushLoaded(
        loadedFrame(
          directWith: jess,
          events: [
            eventRow(
              id: 'e2',
              sequence: 2,
              playerInput: 'psst',
              lines: [storedLine(jess, 'private reply', h.ago(40))],
            ),
          ],
        ),
      );
      expect(h.texts(), ['group line']);
      expect(h.texts(jess), ['psst', 'private reply']);
      expect(h.state.thread(jess).loaded, isTrue);
    });

    test('lines go to the thread named by directWith, whichever is on screen', () async {
      final h = Harness();
      await h.open();
      h.cubit.selectThread(tom);
      h.gateway.pushLoaded(loadedFrame(directWith: tom));
      h.gateway.pushLines(linesFrame([wireLine(jess, 'to you', h.ago(1))], directWith: jess));
      h.gateway.pushLines(linesFrame([wireLine(tom, 'to everyone', h.ago(1))]));
      expect(h.texts(), ['to everyone']);
      expect(h.texts(jess), ['to you']);
      expect(h.texts(tom), isEmpty);
    });

    test('answers to loads sent together land in their threads in either order', () async {
      final h = Harness();
      await h.cubit.start();
      h.cubit.selectThread(jess);
      // Group and direct loads are both out; the direct answer overtakes.
      h.gateway.pushLoaded(
        loadedFrame(
          directWith: jess,
          events: [eventRow(id: 'e2', sequence: 2, playerInput: 'psst', lines: [storedLine(jess, 'private', h.ago(9))])],
        ),
      );
      h.gateway.pushLoaded(
        loadedFrame(events: [eventRow(id: 'e1', sequence: 1, lines: [storedLine(tom, 'public', h.ago(20))])]),
      );
      expect(h.texts(), ['public']);
      expect(h.texts(jess), ['psst', 'private']);
    });

    test('a line for another chat is ignored', () async {
      final h = Harness();
      await h.open();
      h.gateway.pushLines({...linesFrame([wireLine(jess, 'x', h.ago(1))]), 'instanceId': 'other'});
      expect(h.texts(), isEmpty);
    });

    test('a refused thread load does not shift the answers that follow', () async {
      final h = Harness();
      await h.open();
      h.cubit.selectThread('ghost');
      h.gateway.pushError({'code': 'BAD_REQUEST'});
      h.cubit.selectThread(jess);
      h.gateway.pushLoaded(
        loadedFrame(directWith: jess, events: [eventRow(id: 'e9', sequence: 9, lines: [storedLine(jess, 'mine', h.ago(5))])]),
      );
      expect(h.texts(jess), ['mine']);
      expect(h.texts('ghost'), isEmpty);
    });
  });

  group('sending', () {
    test('the line shows at once and goes out with direct_with and kind', () async {
      final h = Harness();
      await h.open();
      expect(h.cubit.send('  hello  '), isTrue);
      expect(h.texts(), ['hello']);
      expect(h.state.thread().lines.single.status, GroupLineStatus.sending);
      expect(h.gateway.chats.single, {
        'action': 'chat',
        'instance_id': instanceId,
        'text': 'hello',
      });
      h.cubit.send('psst', directWith: jess);
      expect(h.texts(jess), ['psst']);
      h.cubit.send('waves', action: true);
      expect(h.state.thread().lines.last.isAction, isTrue);
      h.cubit.send('empty'.replaceAll('empty', '   '));
      expect(h.texts(), ['hello', 'waves']);
    });

    test('an action to one person is refused locally', () async {
      final h = Harness();
      await h.open();
      expect(h.cubit.send('waves', directWith: jess, action: true), isFalse);
      expect(h.gateway.chats, isEmpty);
    });

    test('one turn at a time: later sends wait, in order, across threads', () async {
      final h = Harness();
      await h.open();
      h.cubit.send('one');
      h.cubit.send('two', directWith: jess);
      h.cubit.send('three', action: true);
      expect(h.gateway.chats.length, 1);
      expect(h.state.queuedSends, 2);
      expect(h.state.thread(jess).lines.single.status, GroupLineStatus.queued);

      h.gateway.pushAck('j1');
      h.gateway.pushComplete(completeFrame(jobId: 'j1', eventId: 'e10', sequence: 10, playerInput: 'one', lines: []));
      expect(h.gateway.chats.length, 2);
      expect(h.gateway.chats[1]['direct_with'], jess);
      expect(h.state.turnInFlight, isTrue);

      h.gateway.pushAck('j2');
      h.gateway.pushComplete(completeFrame(jobId: 'j2', eventId: 'e11', sequence: 11, playerInput: 'two', lines: []));
      expect(h.gateway.chats.length, 3);
      expect(h.gateway.chats[2]['kind'], 'action');
      h.gateway.pushAck('j3');
      h.gateway.pushComplete(completeFrame(jobId: 'j3', eventId: 'e12', sequence: 12, playerInput: 'three', action: true, lines: []));
      expect(h.state.turnInFlight, isFalse);
      expect(h.state.queuedSends, 0);
      expect(h.state.thread().lines.every((l) => l.status == GroupLineStatus.sent), isTrue);
    });

    test('the saved line replaces the one shown while sending', () async {
      final h = Harness();
      await h.open();
      h.cubit.send('hi');
      h.gateway.pushAck('j1');
      h.gateway.pushComplete(
        completeFrame(jobId: 'j1', eventId: 'e5', sequence: 5, playerInput: 'hi', lines: [storedLine(jess, 'hello', h.ago(1))]),
      );
      expect(h.texts(), ['hi', 'hello']);
      expect(h.state.thread().lines.first.key, 'p:e5');
      expect(h.state.thread().lines.first.eventId, 'e5');
    });

    test('a failed turn keeps the text and the queue moves on', () async {
      final h = Harness();
      await h.open();
      h.cubit.send('first');
      h.cubit.send('second');
      h.gateway.pushError({'type': 'error', 'code': 'INTERNAL'});
      expect(h.state.failedSends.single.text, 'first');
      expect(h.state.failedSends.single.error, GroupChatError.failed);
      expect(h.texts(), ['second']);
      expect(h.gateway.chats.length, 2);
      expect(h.state.turnInFlight, isTrue);
      h.gateway.pushAck('j2');
      h.gateway.pushComplete(completeFrame(jobId: 'j2', eventId: 'e2', sequence: 2, playerInput: 'second', lines: []));
      expect(h.state.turnInFlight, isFalse);
    });

    test('a turn that fails after its ack names itself', () async {
      final h = Harness();
      await h.open();
      h.cubit.send('first');
      h.gateway.pushAck('j1');
      h.gateway.pushError({'type': 'generation_failed', 'jobId': 'someone-else'});
      expect(h.state.turnInFlight, isTrue);
      h.gateway.pushError({'type': 'generation_failed', 'instanceId': instanceId, 'jobId': 'j1'});
      expect(h.state.turnInFlight, isFalse);
      expect(h.state.failedSends.single.text, 'first');
    });

    test('a refusal that would hit every send fails the whole queue', () async {
      final h = Harness();
      await h.open();
      h.cubit.send('a');
      h.cubit.send('b');
      h.cubit.send('c', directWith: tom);
      h.gateway.pushError({'code': 'INSUFFICIENT_INK'});
      expect([for (final f in h.state.failedSends) f.text], ['a', 'b', 'c']);
      expect(h.state.failedSends.every((f) => f.error == GroupChatError.insufficientInk), isTrue);
      expect(h.state.turnInFlight, isFalse);
      expect(h.texts(), isEmpty);
    });

    test('retrying a failed send queues it again', () async {
      final h = Harness();
      await h.open();
      h.cubit.send('again');
      h.gateway.pushError({'code': 'RATE_LIMITED'});
      final id = h.state.failedSends.single.id;
      expect(h.cubit.retryFailed(id), isTrue);
      expect(h.state.failedSends, isEmpty);
      expect(h.gateway.chats.length, 2);
      expect(h.texts(), ['again']);
    });

    test('error codes reach the state as a small enum', () async {
      final cases = {
        'GENERATION_IN_PROGRESS': GroupChatError.busy,
        'RATE_LIMITED': GroupChatError.rateLimited,
        'SIGN_IN_REQUIRED': GroupChatError.signInRequired,
        'STORY_RESTING': GroupChatError.resting,
        'NOT_FOUND': GroupChatError.notFound,
        'BAD_REQUEST': GroupChatError.rejected,
        null: GroupChatError.failed,
      };
      for (final entry in cases.entries) {
        final h = Harness();
        await h.open();
        h.cubit.send('x');
        h.gateway.pushError({if (entry.key != null) 'code': entry.key});
        expect(h.state.failedSends.first.error, entry.value, reason: '${entry.key}');
      }
    });

    test('nothing is sent while the socket is down; it goes out on reconnect', () async {
      final h = Harness();
      await h.open();
      h.gateway.setConnected(false);
      h.cubit.send('later');
      expect(h.gateway.chats, isEmpty);
      expect(h.texts(), ['later']);
      h.gateway.setConnected(true);
      expect(h.gateway.chats.length, 1);
    });
  });

  group('reveal', () {
    test('lines show at their time, in order, with the next speaker typing', () async {
      final h = Harness();
      await h.open();
      h.gateway.pushLines(
        linesFrame([
          wireLine(jess, 'one', h.ahead(0)),
          wireLine(tom, 'two', h.ahead(3)),
          wireLine(jess, 'three', h.ahead(6)),
        ]),
      );
      expect(h.texts(), ['one']);
      expect(h.state.thread().typingId, tom);
      h.clock.advance(const Duration(seconds: 2));
      expect(h.texts(), ['one']);
      h.clock.advance(const Duration(seconds: 1));
      expect(h.texts(), ['one', 'two']);
      expect(h.state.thread().typingId, jess);
      h.clock.advance(const Duration(seconds: 3));
      expect(h.texts(), ['one', 'two', 'three']);
      expect(h.state.thread().typingId, isNull);
    });

    test('a line whose time has passed shows at once', () async {
      final h = Harness();
      await h.open();
      h.gateway.pushLines(linesFrame([wireLine(jess, 'late', h.ago(30)), wireLine(tom, 'later', h.ago(2))]));
      expect(h.texts(), ['late', 'later']);
      expect(h.state.thread().typingId, isNull);
    });

    test('a line stamped far ahead shows after the cap', () async {
      final h = Harness();
      await h.open();
      h.gateway.pushLines(linesFrame([wireLine(jess, 'skewed', h.ahead(600))]));
      expect(h.texts(), isEmpty);
      h.clock.advance(const Duration(seconds: 21));
      h.clock.advance(const Duration(seconds: 1));
      expect(h.texts(), isEmpty); // the clock only moved 22s; still ahead
      h.clock.advance(const Duration(minutes: 10));
      expect(h.texts(), ['skewed']);
    });

    test('the player sending shows what is still being revealed, above their line', () async {
      final h = Harness();
      await h.open();
      h.gateway.pushLines(linesFrame([wireLine(jess, 'now', h.ahead(0)), wireLine(tom, 'soon', h.ahead(4))]));
      h.cubit.send('interrupting');
      expect(h.texts(), ['now', 'soon', 'interrupting']);
      h.clock.advance(const Duration(seconds: 10));
      expect(h.texts(), ['now', 'soon', 'interrupting']);
    });

    test('closing stops reveal timers and later frames do nothing', () async {
      final h = Harness();
      await h.open();
      h.gateway.pushLines(linesFrame([wireLine(jess, 'x', h.ahead(5))]));
      expect(h.clock.pendingTimers, greaterThan(0));
      await h.cubit.close();
      expect(h.clock.pendingTimers, 0);
      h.clock.advance(const Duration(minutes: 5));
      h.gateway.pushLines(linesFrame([wireLine(jess, 'y', h.ago(1))]));
      expect(h.cubit.isClosed, isTrue);
    });
  });

  group('n-way partial frames: each line exactly once, in any order', () {
    final orders = <List<String>>[
      ['P', 'F', 'C'],
      ['P', 'C', 'F'],
      ['F', 'P', 'C'],
      ['F', 'C', 'P'],
      ['C', 'P', 'F'],
      ['C', 'F', 'P'],
    ];

    for (final order in orders) {
      test(order.join(' '), () async {
        final h = Harness();
        await h.open();
        final a = wireLine(jess, 'A', h.ago(9));
        final b = wireLine(tom, 'B', h.ago(7));
        final c = wireLine(jess, 'C', h.ago(5));
        h.cubit.send('go');
        h.gateway.pushAck('j1');
        final frames = {
          'P': linesFrame([a, b], turnId: 'j1', partial: true),
          'F': linesFrame([c], turnId: 'j1', eventId: 'e7'),
          'C': completeFrame(
            jobId: 'j1',
            eventId: 'e7',
            sequence: 7,
            playerInput: 'go',
            lines: [
              storedLine(jess, 'A', h.ago(9)),
              storedLine(tom, 'B', h.ago(7)),
              storedLine(jess, 'C', h.ago(5)),
            ],
          ),
        };
        for (final name in order) {
          if (name == 'C') {
            h.gateway.pushComplete(frames[name]!);
          } else {
            h.gateway.pushLines(frames[name]!);
          }
        }
        expect(h.texts(), ['go', 'A', 'B', 'C']);
        expect(h.state.turnInFlight, isFalse);
        expect(h.state.thread().lines.every((l) => l.eventId == 'e7'), isTrue);
      });
    }

    test('a duplicate delivery of every frame changes nothing', () async {
      final h = Harness();
      await h.open();
      final a = wireLine(jess, 'A', h.ago(9));
      final partial = linesFrame([a], turnId: 'j1', partial: true);
      h.cubit.send('go');
      h.gateway.pushAck('j1');
      h.gateway.pushLines(partial);
      h.gateway.pushLines(partial);
      final done = completeFrame(
        jobId: 'j1',
        eventId: 'e7',
        sequence: 7,
        playerInput: 'go',
        lines: [storedLine(jess, 'A', h.ago(9))],
      );
      h.gateway.pushComplete(done);
      h.gateway.pushComplete(done);
      h.gateway.pushLines(partial);
      expect(h.texts(), ['go', 'A']);
    });

    test('frames with future times still reveal each line once', () async {
      final h = Harness();
      await h.open();
      final a = wireLine(jess, 'A', h.ahead(0));
      final b = wireLine(tom, 'B', h.ahead(3));
      h.cubit.send('go');
      h.gateway.pushAck('j1');
      h.gateway.pushLines(linesFrame([a], turnId: 'j1', partial: true));
      h.gateway.pushComplete(
        completeFrame(
          jobId: 'j1',
          eventId: 'e7',
          sequence: 7,
          playerInput: 'go',
          lines: [storedLine(jess, 'A', DateTime.parse(a['shownAt'] as String)), storedLine(tom, 'B', DateTime.parse(b['shownAt'] as String))],
        ),
      );
      h.gateway.pushLines(linesFrame([b], turnId: 'j1', eventId: 'e7'));
      h.clock.advance(const Duration(seconds: 10));
      expect(h.texts(), ['go', 'A', 'B']);
    });

    test('a reconnect mid-turn: the partial lines stay, the rest arrive once', () async {
      final h = Harness();
      await h.open();
      h.cubit.send('go');
      h.gateway.pushAck('j1');
      h.gateway.pushLines(linesFrame([wireLine(jess, 'A', h.ago(9))], turnId: 'j1', partial: true));
      h.gateway.setConnected(false);
      h.gateway.setConnected(true);
      // History does not hold the turn yet: the server is still on it.
      h.gateway.pushLoaded(loadedFrame(operation: 'generation'));
      expect(h.texts(), ['go', 'A']);
      expect(h.state.turnInFlight, isTrue);
      h.gateway.pushLines(linesFrame([wireLine(tom, 'B', h.ago(5))], turnId: 'j1', eventId: 'e7'));
      h.gateway.pushComplete(
        completeFrame(
          jobId: 'j1',
          eventId: 'e7',
          sequence: 7,
          playerInput: 'go',
          lines: [storedLine(jess, 'A', h.ago(9)), storedLine(tom, 'B', h.ago(5))],
        ),
      );
      expect(h.texts(), ['go', 'A', 'B']);
      expect(h.state.turnInFlight, isFalse);
    });

    test('a reconnect after the turn was saved: history adds no duplicates', () async {
      final h = Harness();
      await h.open();
      h.cubit.send('go');
      h.gateway.pushAck('j1');
      final shownA = h.ago(9);
      h.gateway.pushLines(linesFrame([wireLine(jess, 'A', shownA)], turnId: 'j1', partial: true));
      h.gateway.setConnected(false);
      h.gateway.setConnected(true);
      h.gateway.pushLoaded(
        loadedFrame(
          events: [
            eventRow(
              id: 'e7',
              sequence: 7,
              playerInput: 'go',
              lines: [storedLine(jess, 'A', shownA), storedLine(tom, 'B', h.ago(5))],
            ),
          ],
        ),
      );
      expect(h.texts(), ['go', 'A', 'B']);
      expect(h.state.turnInFlight, isFalse);
    });
  });

  group('reconnect', () {
    test('queued sends survive, and go out once the lost turn is settled', () async {
      final h = Harness();
      await h.open();
      h.cubit.send('first');
      h.cubit.send('second');
      h.gateway.pushAck('j1');
      h.gateway.setConnected(false);
      expect(h.state.queuedSends, 1);
      h.gateway.setConnected(true);
      expect(h.gateway.chats.length, 1);
      h.gateway.pushLoaded(
        loadedFrame(
          events: [
            eventRow(id: 'e3', sequence: 3, playerInput: 'first', lines: [storedLine(jess, 'ok', h.ago(2))]),
          ],
        ),
      );
      expect(h.texts(), ['first', 'ok', 'second']);
      expect(h.gateway.chats.length, 2);
      expect(h.gateway.chats.last['text'], 'second');
    });

    test('a send that never reached the server fails and keeps its text', () async {
      final h = Harness();
      await h.open();
      h.cubit.send('lost');
      h.cubit.send('next');
      h.gateway.setConnected(false);
      h.gateway.setConnected(true);
      h.gateway.pushLoaded(loadedFrame());
      expect(h.state.failedSends.single.text, 'lost');
      expect(h.texts(), ['next']);
      expect(h.gateway.chats.last['text'], 'next');
    });

    test('while the server is still busy it waits, then reads again', () async {
      final h = Harness();
      await h.open();
      h.cubit.send('slow');
      h.gateway.setConnected(false);
      h.gateway.setConnected(true);
      h.gateway.pushLoaded(loadedFrame(operation: 'generation'));
      expect(h.state.turnInFlight, isTrue);
      final loads = h.gateway.loads.length;
      h.clock.advance(const Duration(seconds: 3));
      expect(h.gateway.loads.length, loads + 1);
      h.gateway.pushLoaded(
        loadedFrame(events: [eventRow(id: 'e2', sequence: 2, playerInput: 'slow', lines: [storedLine(tom, 'sorry', h.ago(1))])]),
      );
      expect(h.state.turnInFlight, isFalse);
      expect(h.texts(), ['slow', 'sorry']);
    });

    test('a turn the server never settles fails after the attempts', () async {
      final h = Harness();
      await h.open();
      h.cubit.send('stuck');
      h.gateway.setConnected(false);
      h.gateway.setConnected(true);
      for (var i = 0; i < 12 && h.state.turnInFlight; i++) {
        h.gateway.pushLoaded(loadedFrame(operation: 'generation'));
        h.clock.advance(const Duration(seconds: 3));
      }
      expect(h.state.turnInFlight, isFalse);
      expect(h.state.failedSends.single.text, 'stuck');
    });

    test('a silent turn is checked against the history', () async {
      final h = Harness();
      await h.open();
      h.cubit.send('quiet');
      h.gateway.pushAck('j1');
      final loads = h.gateway.loads.length;
      h.clock.advance(const Duration(seconds: 91));
      expect(h.gateway.loads.length, loads + 1);
      h.gateway.pushLoaded(loadedFrame(events: [eventRow(id: 'e2', sequence: 2, playerInput: 'quiet', lines: [storedLine(jess, 'hi', h.ago(1))])]));
      expect(h.state.turnInFlight, isFalse);
      expect(h.texts(), ['quiet', 'hi']);
    });

    test('a completion for a turn we do not hold reads the history', () async {
      final h = Harness();
      await h.open();
      final loads = h.gateway.loads.length;
      h.gateway.pushComplete(completeFrame(jobId: 'x', eventId: 'e2', sequence: 2, lines: []));
      expect(h.gateway.loads.length, loads + 1);
    });
  });

  group('opening a pending thread', () {
    Future<Harness> pending() async {
      final h = Harness();
      await h.open(frame: loadedFrame(pendingFrom: [jess]));
      return h;
    }

    test('calls the open route once, however often it is opened', () async {
      final h = await pending();
      h.cubit.selectThread(jess);
      h.cubit.selectThread(jess);
      await Future<void>.delayed(Duration.zero);
      h.cubit.selectThread(null);
      h.cubit.selectThread(jess);
      await Future<void>.delayed(Duration.zero);
      expect(h.repo.opened, [jess]);
      expect(h.state.pendingFrom, isEmpty);
    });

    test('the same character can have another message waiting later', () async {
      final h = await pending();
      h.cubit.selectThread(jess);
      h.gateway.pushLoaded(loadedFrame(directWith: jess));
      await Future<void>.delayed(Duration.zero);
      // Opened again while the first turn is still running: still one call.
      h.cubit.selectThread(null);
      h.cubit.selectThread(jess);
      await Future<void>.delayed(Duration.zero);
      // A read taken before the claim still lists her: the turn holds it.
      h.gateway.pushLoaded(loadedFrame(directWith: jess, pendingFrom: [jess]));
      await Future<void>.delayed(Duration.zero);
      expect(h.repo.opened, [jess]);
      h.gateway.pushComplete(completeFrame(jobId: 'd1', eventId: 'e5', sequence: 5, lines: [storedLine(jess, 'one', h.ago(1))]));
      expect(h.state.turnInFlight, isFalse);

      // Her next message is waiting.
      h.cubit.selectThread(null);
      h.gateway.pushLoaded(loadedFrame(pendingFrom: [jess]));
      h.cubit.selectThread(jess);
      await Future<void>.delayed(Duration.zero);
      expect(h.repo.opened, [jess, jess]);
    });

    test('a thread that is not pending is not opened', () async {
      final h = await pending();
      h.cubit.selectThread(tom);
      await Future<void>.delayed(Duration.zero);
      expect(h.repo.opened, isEmpty);
    });

    test('writing: true shows the character typing until lines arrive', () async {
      final h = await pending();
      h.cubit.selectThread(jess);
      h.gateway.pushLoaded(loadedFrame(directWith: jess));
      await Future<void>.delayed(Duration.zero);
      expect(h.state.thread(jess).typingId, jess);
      expect(h.state.turnInFlight, isTrue);
      h.gateway.pushLines(linesFrame([wireLine(jess, 'hey you', h.ago(1))], directWith: jess, eventId: 'e5'));
      expect(h.state.thread(jess).typingId, isNull);
      expect(h.texts(jess), ['hey you']);
      h.gateway.pushComplete(completeFrame(jobId: 'direct-1', eventId: 'e5', sequence: 5, lines: [storedLine(jess, 'hey you', h.ago(1))]));
      expect(h.state.turnInFlight, isFalse);
      expect(h.texts(jess), ['hey you']);
    });

    test('typing stops when the timeout passes with no words', () async {
      final h = await pending();
      h.cubit.selectThread(jess);
      h.gateway.pushLoaded(loadedFrame(directWith: jess));
      await Future<void>.delayed(Duration.zero);
      h.clock.advance(const Duration(seconds: 26));
      expect(h.state.thread(jess).typingId, isNull);
    });

    test('writing: false shows nothing unusual and keeps the message waiting', () async {
      final h = await pending();
      h.repo.openWriting = false;
      h.cubit.selectThread(jess);
      h.gateway.pushLoaded(loadedFrame(directWith: jess, pendingFrom: [jess]));
      await Future<void>.delayed(Duration.zero);
      expect(h.state.thread(jess).typingId, isNull);
      expect(h.state.turnInFlight, isFalse);
      expect(h.state.pendingFrom, [jess]);
    });

    test('a failed open request changes nothing', () async {
      final h = await pending();
      h.repo.openError = ApiException(statusCode: 500, message: 'x');
      h.cubit.selectThread(jess);
      await Future<void>.delayed(Duration.zero);
      expect(h.state.pendingFrom, [jess]);
      expect(h.state.turnInFlight, isFalse);
    });

    test('a send during the waiting turn queues behind it', () async {
      final h = await pending();
      h.cubit.selectThread(jess);
      h.gateway.pushLoaded(loadedFrame(directWith: jess));
      await Future<void>.delayed(Duration.zero);
      h.cubit.send('hello', directWith: jess);
      expect(h.gateway.chats, isEmpty);
      expect(h.state.queuedSends, 1);
      h.gateway.pushComplete(completeFrame(jobId: 'direct-1', eventId: 'e5', sequence: 5, lines: [storedLine(jess, 'hey', h.ago(1))]));
      expect(h.gateway.chats.length, 1);
    });
  });

  group('bonds', () {
    test('load, then set shows the server answer', () async {
      final h = Harness();
      await h.open();
      h.repo.bondRows = [
        const GroupBond(characterId: jess, name: 'Jess', meters: BondMeters(trust: 40)),
      ];
      await h.cubit.loadBonds();
      expect(h.state.bonds.single.meters.trust, 40);
      h.repo.setResult = const BondMeters(trust: 90, affection: 80);
      final ok = await h.cubit.setBond(jess, {'trust': 100, 'affection': 80});
      expect(ok, isTrue);
      // The server's numbers, not the ones asked for.
      expect(h.state.bonds.single.meters, const BondMeters(trust: 90, affection: 80));
    });

    test('an out-of-range value is not sent; a refusal reaches the state', () async {
      final h = Harness();
      await h.open();
      expect(await h.cubit.setBond(jess, {'trust': 101}), isFalse);
      expect(h.repo.setCalls, isEmpty);
      h.repo.setError = ApiException(statusCode: 400, message: 'x');
      expect(await h.cubit.setBond(jess, {'trust': 5}), isFalse);
      expect(h.state.bondsError, GroupChatError.rejected);
    });

    test('a failed load reaches the state', () async {
      final h = Harness();
      await h.open();
      h.repo.bondsError = ApiException(statusCode: 404, message: 'x');
      await h.cubit.loadBonds();
      expect(h.state.bondsError, GroupChatError.notFound);
      expect(h.state.bondsLoading, isFalse);
    });
  });

  group('actions', () {
    test('pages with before, newest first', () async {
      final h = Harness();
      await h.open();
      h.repo.actionPages
        ..add(GroupActionsPage(actions: [
          const GroupAction(eventId: 'a3', sequence: 9, text: 'three'),
          const GroupAction(eventId: 'a2', sequence: 7, text: 'two'),
        ], next: 7))
        ..add(GroupActionsPage(actions: [
          const GroupAction(eventId: 'a1', sequence: 3, text: 'one'),
        ]));
      await h.cubit.loadActions();
      expect(h.state.actionsNext, 7);
      await h.cubit.loadMoreActions();
      expect(h.repo.actionBefore, [null, 7]);
      expect([for (final a in h.state.actions) a.text], ['three', 'two', 'one']);
      expect(h.state.actionsNext, isNull);
      await h.cubit.loadMoreActions();
      expect(h.repo.actionBefore.length, 2);
    });

    test('player_action on a history event marks the line', () async {
      final h = Harness();
      await h.open(
        frame: loadedFrame(
          events: [
            eventRow(id: 'e2', sequence: 2, playerInput: 'waves', action: true, lines: [storedLine(jess, 'hi', h.ago(3))]),
            eventRow(id: 'e3', sequence: 3, playerInput: 'says hi'),
          ],
        ),
      );
      final lines = h.state.thread().lines;
      expect(lines[0].isAction, isTrue);
      expect(lines[1].isAction, isFalse);
      expect(lines[2].isAction, isFalse);
    });
  });

  group('rewind', () {
    // The room holds turns 1, 2 and 4; Jess's thread holds 3 and 5. Sequence
    // numbers are shared, so rewinding to 2 empties her thread.
    Future<Harness> twoThreads() async {
      final h = Harness();
      await h.open(
        frame: loadedFrame(
          events: [
            eventRow(id: 'e1', sequence: 1, lines: [storedLine(jess, 'opening', h.ago(90))]),
            eventRow(id: 'e2', sequence: 2, playerInput: 'two', lines: [storedLine(tom, 'room two', h.ago(80))]),
            eventRow(id: 'e4', sequence: 4, playerInput: 'four', lines: [storedLine(tom, 'room four', h.ago(60))]),
          ],
        ),
      );
      h.cubit.selectThread(jess);
      h.gateway.pushLoaded(
        loadedFrame(
          directWith: jess,
          events: [
            eventRow(id: 'e3', sequence: 3, playerInput: 'psst', lines: [storedLine(jess, 'dm three', h.ago(70))]),
            eventRow(id: 'e5', sequence: 5, playerInput: 'again', lines: [storedLine(jess, 'dm five', h.ago(50))]),
          ],
        ),
      );
      return h;
    }

    Map<String, dynamic> afterRewind({String? directWith, List<Map<String, dynamic>> events = const []}) =>
        loadedFrame(directWith: directWith, events: events);

    test('lines carry the sequence of their turn, from history', () async {
      final h = await twoThreads();
      expect({for (final l in h.state.thread().lines) l.text: l.sequence}, {
        'opening': 1,
        'two': 2,
        'room two': 2,
        'four': 4,
        'room four': 4,
      });
      expect(h.state.thread(jess).lines.last.sequence, 5);
    });

    test('removes later lines from the room AND a direct thread, even an empty one', () async {
      final h = await twoThreads();
      final loadsBefore = h.gateway.loads.length;
      await h.cubit.rewind(2);
      expect(h.repo.rewindCalls, [2]);
      // Every thread held is read again, and the veil stays until they answer.
      expect(h.gateway.loads.length - loadsBefore, 2);
      expect(h.state.rewinding, isTrue);
      // The server's truth: the room keeps only turn 1, her thread is empty.
      h.gateway.pushLoaded(
        afterRewind(events: [eventRow(id: 'e1', sequence: 1, lines: [storedLine(jess, 'opening', h.ago(90))])]),
      );
      expect(h.state.rewinding, isTrue);
      h.gateway.pushLoaded(afterRewind(directWith: jess));
      expect(h.state.rewinding, isFalse);
      expect(h.texts(), ['opening']);
      expect(h.texts(jess), isEmpty);
      expect(h.state.thread(jess).loaded, isTrue);
      expect(h.state.rewindError, isNull);
    });

    test('a line still waiting to be revealed does not come back', () async {
      final h = Harness();
      await h.open(
        frame: loadedFrame(
          events: [
            eventRow(id: 'e2', sequence: 2, lines: [storedLine(jess, 'later', h.ahead(5))]),
          ],
        ),
      );
      expect(h.texts(), isEmpty);
      await h.cubit.rewind(2);
      h.gateway.pushLoaded(afterRewind());
      h.clock.advance(const Duration(seconds: 30));
      expect(h.texts(), isEmpty);
      expect(h.state.thread().typingId, isNull);
    });

    test('a lingering line with no saved turn is dropped too (history must replace, not merge)', () async {
      final h = await twoThreads();
      // A line that arrived by frame and was never tied to a saved turn.
      h.gateway.pushLines(linesFrame([wireLine(jess, 'ghost', h.ago(55))]));
      expect(h.texts(), contains('ghost'));
      await h.cubit.rewind(2);
      h.gateway.pushLoaded(afterRewind());
      h.gateway.pushLoaded(afterRewind(directWith: jess));
      expect(h.texts(), isEmpty);
    });

    test('the opening can not be rewound to, and lines keep their order after', () async {
      final h = await twoThreads();
      await h.cubit.rewind(1);
      expect(h.repo.rewindCalls, isEmpty);
      expect(h.state.rewinding, isFalse);
    });

    test('a line saved live in this session can be rewound', () async {
      final h = Harness();
      await h.open(frame: loadedFrame(events: [eventRow(id: 'e1', sequence: 1)]));
      h.cubit.send('hi');
      h.gateway.pushAck('j1');
      // The reply's words arrived first, with no turn number yet.
      h.gateway.pushLines(linesFrame([wireLine(jess, 'hello', h.ago(1))]));
      expect(h.state.thread().lines.last.sequence, isNull);
      h.gateway.pushComplete(
        completeFrame(jobId: 'j1', eventId: 'e7', sequence: 7, playerInput: 'hi', lines: [storedLine(jess, 'hello', h.ago(1))]),
      );
      final lines = h.state.thread().lines;
      expect([for (final l in lines) l.sequence], [7, 7]);
      expect([for (final l in lines) l.eventId], ['e7', 'e7']);
      await h.cubit.rewind(lines.first.sequence!);
      expect(h.repo.rewindCalls, [7]);
    });

    test('a completion without a number asks for the history to learn it', () async {
      final h = Harness();
      await h.open();
      h.cubit.send('hi');
      h.gateway.pushAck('j1');
      final loads = h.gateway.loads.length;
      final frame = completeFrame(jobId: 'j1', eventId: 'e7', sequence: 7, playerInput: 'hi', lines: []);
      (frame['event'] as Map).remove('sequence');
      h.gateway.pushComplete(frame);
      expect(h.state.thread().lines.single.sequence, isNull);
      expect(h.gateway.loads.length, loads + 1);
      h.gateway.pushLoaded(loadedFrame(events: [eventRow(id: 'e7', sequence: 7, playerInput: 'hi')]));
      expect(h.state.thread().lines.single.sequence, 7);
    });

    test('is refused while a turn runs or waits, and while another rewind runs', () async {
      final h = await twoThreads();
      h.cubit.send('x');
      await h.cubit.rewind(2);
      expect(h.repo.rewindCalls, isEmpty);

      final g = await twoThreads();
      g.repo.rewindGate = Completer<void>();
      final first = g.cubit.rewind(2);
      await g.cubit.rewind(4);
      expect(g.repo.rewindCalls, [2]);
      g.repo.rewindGate!.complete();
      await first;
    });

    test('sends are blocked during a rewind, and the chat is idle after', () async {
      final h = await twoThreads();
      h.repo.rewindGate = Completer<void>();
      final done = h.cubit.rewind(2);
      expect(h.state.rewinding, isTrue);
      expect(h.cubit.send('quick'), isFalse);
      expect(h.cubit.send('quick', directWith: jess), isFalse);
      expect(h.gateway.chats, isEmpty);
      h.repo.rewindGate!.complete();
      await done;
      h.gateway.pushLoaded(afterRewind());
      h.gateway.pushLoaded(afterRewind(directWith: jess));
      expect(h.state.rewinding, isFalse);
      expect(h.cubit.send('now'), isTrue);
    });

    test('failed sends are dropped after a rewind', () async {
      final h = await twoThreads();
      h.cubit.send('first');
      h.gateway.pushError({'type': 'error', 'code': 'INTERNAL'});
      expect(h.state.failedSends, hasLength(1));
      await h.cubit.rewind(2);
      expect(h.state.failedSends, isEmpty);
    });

    test('a failure clears the state, keeps the lines and resyncs', () async {
      final h = await twoThreads();
      h.repo.rewindError = ApiException(statusCode: 500, message: 'boom');
      final loads = h.gateway.loads.length;
      await h.cubit.rewind(2);
      expect(h.state.rewindError, GroupChatError.failed);
      expect(h.gateway.loads.length - loads, 2);
      // The reread says nothing was removed.
      h.gateway.pushLoaded(
        loadedFrame(events: [
          eventRow(id: 'e1', sequence: 1, lines: [storedLine(jess, 'opening', h.ago(90))]),
          eventRow(id: 'e2', sequence: 2, playerInput: 'two', lines: [storedLine(tom, 'room two', h.ago(80))]),
          eventRow(id: 'e4', sequence: 4, playerInput: 'four', lines: [storedLine(tom, 'room four', h.ago(60))]),
        ]),
      );
      h.gateway.pushLoaded(
        loadedFrame(directWith: jess, events: [
          eventRow(id: 'e3', sequence: 3, playerInput: 'psst', lines: [storedLine(jess, 'dm three', h.ago(70))]),
          eventRow(id: 'e5', sequence: 5, playerInput: 'again', lines: [storedLine(jess, 'dm five', h.ago(50))]),
        ]),
      );
      expect(h.state.rewinding, isFalse);
      expect(h.texts(), ['opening', 'two', 'room two', 'four', 'room four']);
      expect(h.texts(jess), ['psst', 'dm three', 'again', 'dm five']);
    });

    test('a 409 reads as busy, changes nothing on screen and clears the state', () async {
      final h = await twoThreads();
      h.repo.rewindError = ApiException(statusCode: 409, message: 'busy');
      await h.cubit.rewind(2);
      expect(h.state.rewindError, GroupChatError.busy);
      expect(h.state.rewinding, isFalse);
      expect(h.texts(), hasLength(5));
      expect(h.texts(jess), hasLength(4));
      // The same failure again still raises a new notice.
      await h.cubit.rewind(2);
      expect(h.state.rewindError, GroupChatError.busy);
      expect(h.repo.rewindCalls, [2, 2]);
    });

    test('a late frame of a removed turn does not bring its line back', () async {
      final h = await twoThreads();
      await h.cubit.rewind(2);
      // During the rewind and after it.
      h.gateway.pushLines(linesFrame([wireLine(tom, 'room four', h.ago(60))], eventId: 'e4'));
      h.gateway.pushLoaded(
        afterRewind(events: [eventRow(id: 'e1', sequence: 1, lines: [storedLine(jess, 'opening', h.ago(90))])]),
      );
      h.gateway.pushLoaded(afterRewind(directWith: jess));
      h.gateway.pushLines(linesFrame([wireLine(tom, 'room four', h.ago(60))], eventId: 'e4'));
      h.gateway.pushLines(linesFrame([wireLine(jess, 'dm five', h.ago(50))], directWith: jess, eventId: 'e5'));
      h.clock.advance(const Duration(seconds: 30));
      expect(h.texts(), ['opening']);
      expect(h.texts(jess), isEmpty);
    });

    test('bonds, actions and the thread list are read again', () async {
      final h = await twoThreads();
      h.repo.bondRows = [
        const GroupBond(characterId: jess, name: 'Jess', meters: BondMeters(trust: 40)),
      ];
      await h.cubit.loadBonds();
      h.repo.actionPages.add(GroupActionsPage(actions: [
        const GroupAction(eventId: 'a1', sequence: 4, text: 'wave'),
      ]));
      await h.cubit.loadActions();
      h.repo.bondRows = [
        const GroupBond(characterId: jess, name: 'Jess', meters: BondMeters(trust: 10)),
      ];
      h.repo.actionPages.add(GroupActionsPage());
      h.repo.threadRows = const [];
      await h.cubit.rewind(2);
      await Future<void>.delayed(Duration.zero);
      expect(h.state.bonds.single.meters.trust, 10);
      expect(h.state.actions, isEmpty);
    });
  });
}
