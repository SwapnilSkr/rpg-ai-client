import 'dart:async';
import 'dart:convert';

import 'package:everlore/features/group_chat/data/group_chat_repository.dart';
import 'package:everlore/features/group_chat/models/group_chat_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fakes.dart';
import 'group_chat_cubit_test.dart' show Harness, completeFrame, linesFrame;

Map<String, dynamic> withSelfie(
  Map<String, dynamic> line,
  String lineId, [
  Map<String, dynamic>? selfie,
]) => {...line, 'line_id': lineId, if (selfie != null) 'selfie': selfie};

/// A room with one saved line of Jess's, `L1`, in event `e1`.
Future<Harness> room({
  Map<String, dynamic>? selfie,
  bool hidden = false,
  bool open = true,
}) async {
  final h = Harness();
  final at = hidden ? h.ahead(30) : h.ago(60);
  await h.open(
    frame: loadedFrame(
      events: [
        eventRow(
          id: 'e1',
          sequence: 1,
          lines: [withSelfie(storedLine(jess, 'look at me', at), 'L1', selfie)],
        ),
      ],
    ),
  );
  return h;
}

Map<String, dynamic> started(Map<String, dynamic> selfie, {String? directWith, String lineId = 'L1'}) => {
  'type': 'selfie_started',
  'instanceId': instanceId,
  'eventId': 'e1',
  'line_id': lineId,
  'character_id': jess,
  if (directWith != null) 'directWith': directWith,
  'selfie': selfie,
};

Map<String, dynamic> media(
  String type, {
  String kind = 'picture',
  String? lineId = 'L1',
  String? directWith,
  String instance = instanceId,
}) => {
  'type': type,
  'instanceId': instance,
  'eventId': 'e1',
  'media_id': 'm9',
  'kind': kind,
  if (type == 'media_ready') 'url': 'https://cdn/x.png',
  if (lineId != null) 'line_id': lineId,
  if (directWith != null) 'directWith': directWith,
};

GroupLine line(Harness h, [String? directWith]) =>
    h.state.thread(directWith).lines.firstWhere((l) => l.lineId == 'L1');

SelfieStatus? status(Harness h, [String? directWith]) =>
    line(h, directWith).selfie?.status;

void main() {
  group('parsing', () {
    test('every status, and an unknown one is no selfie', () async {
      for (final s in SelfieStatus.values) {
        final h = await room(selfie: {'status': s.name, 'media_id': 'm1'});
        expect(status(h), s, reason: s.name);
        await h.cubit.close();
      }
      final h = await room(selfie: {'status': 'dreaming', 'media_id': 'm1'});
      expect(line(h).selfie, isNull);
      expect(line(h).lineId, 'L1');
    });

    test('ready keeps its url; resting keeps its time; others drop them', () {
      final ready = GroupSelfie.parse({'status': 'ready', 'media_id': 'a', 'url': 'u'})!;
      expect((ready.mediaId, ready.url), ('a', 'u'));
      final queued = GroupSelfie.parse({'status': 'queued', 'url': 'u'})!;
      expect(queued.url, isNull);
      final resting = GroupSelfie.parse({
        'status': 'resting',
        'resets_at': '2026-11-05T00:00:00.000Z',
      })!;
      expect(resting.resetsAt, DateTime.utc(2026, 11, 5));
      expect(GroupSelfie.parse(null), isNull);
      expect(GroupSelfie.parse('ready'), isNull);
    });

    test('resetsAtLocal is the same moment in local time, in any zone', () {
      final resting = GroupSelfie.parse({
        'status': 'resting',
        'resets_at': '2026-11-05T00:00:00.000Z',
      })!;
      final local = resting.resetsAtLocal!;
      expect(local.isUtc, isFalse);
      expect(local.isAtSameMomentAs(DateTime.utc(2026, 11, 5)), isTrue);
    });

    test('history, the completion frame and group_lines all carry them', () async {
      final h = await room(selfie: {'status': 'queued', 'media_id': 'm1'});
      expect(status(h), SelfieStatus.queued);

      h.cubit.send('hi');
      h.gateway.pushAck('j1');
      h.gateway.pushComplete(
        completeFrame(
          jobId: 'j1',
          eventId: 'e2',
          sequence: 2,
          playerInput: 'hi',
          lines: [withSelfie(storedLine(tom, 'hello', h.ago(1)), 'L2', {'status': 'ready', 'media_id': 'm2', 'url': 'u2'})],
        ),
      );
      final tomLine = h.state.thread().lines.firstWhere((l) => l.lineId == 'L2');
      expect(tomLine.selfie!.url, 'u2');

      h.gateway.pushLines(
        linesFrame(
          [withSelfie(wireLine(jess, 'again', h.ago(1)), 'L3', {'status': 'failed'})],
          eventId: 'e3',
        ),
      );
      expect(h.state.thread().lines.last.selfie!.status, SelfieStatus.failed);
    });

    test('a later frame of a line already shown adds its id and picture', () async {
      final h = await room();
      final at = h.ago(5);
      h.gateway.pushLines(linesFrame([wireLine(tom, 'psst', at)], partial: true));
      expect(h.state.thread().lines.last.lineId, isNull);
      h.gateway.pushLines(
        linesFrame(
          [withSelfie(wireLine(tom, 'psst', at), 'L9', {'status': 'queued', 'media_id': 'm3'})],
          eventId: 'e5',
        ),
      );
      final l = h.state.thread().lines.last;
      expect((l.lineId, l.selfie!.status), ('L9', SelfieStatus.queued));
    });
  });

  group('frames', () {
    test('selfie_started, ready, unseen and failed land on the line', () async {
      final h = await room();
      h.gateway.pushSelfie(started({'status': 'queued', 'media_id': 'm9'}));
      expect(status(h), SelfieStatus.queued);
      h.gateway.pushSelfie(started({'status': 'processing', 'media_id': 'm9'}));
      expect(status(h), SelfieStatus.processing);
      h.gateway.pushSelfie(media('media_ready'));
      expect(line(h).selfie!.url, 'https://cdn/x.png');
      expect(line(h).selfie!.mediaId, 'm9');

      h.gateway.pushSelfie(media('media_unseen'));
      expect(status(h), SelfieStatus.unseen);
      h.gateway.pushSelfie(media('media_failed'));
      expect(status(h), SelfieStatus.failed);
    });

    test('a resting start carries its time', () async {
      final h = await room();
      h.gateway.pushSelfie(
        started({'status': 'resting', 'resets_at': '2026-11-05T00:00:00.000Z'}),
      );
      expect(line(h).selfie!.resetsAt, DateTime.utc(2026, 11, 5));
    });

    test('a finished picture is not undone by an older word', () async {
      final h = await room();
      h.gateway.pushSelfie(media('media_ready'));
      h.gateway.pushSelfie(started({'status': 'queued', 'media_id': 'm9'}));
      h.gateway.pushSelfie(started({'status': 'processing', 'media_id': 'm9'}));
      expect(status(h), SelfieStatus.ready);
    });

    test('other pictures, other chats and unknown words do nothing', () async {
      final h = await room();
      final before = h.state.thread().lines;
      h.gateway.pushSelfie(media('media_ready', lineId: null));
      h.gateway.pushSelfie(media('media_ready', kind: 'video'));
      h.gateway.pushSelfie(media('media_ready', instance: 'other'));
      h.gateway.pushSelfie(started({'status': 'dreaming'}));
      h.gateway.pushSelfie(media('media_ready', lineId: 'nope'));
      expect(h.state.thread().lines, before);
    });

    test('a frame for a line not loaded makes no line, and a reload shows it', () async {
      final h = await room();
      h.gateway.pushSelfie(started({'status': 'queued', 'media_id': 'm5'}, lineId: 'LX'));
      expect(h.state.thread().lines.where((l) => l.lineId == 'LX'), isEmpty);
      expect(h.state.thread().lines.length, 1);
    });

    test('only the thread it names changes, even when another is on screen', () async {
      final h = await room();
      h.cubit.selectThread(jess);
      h.gateway.pushLoaded(
        loadedFrame(
          directWith: jess,
          events: [
            eventRow(
              id: 'e1',
              sequence: 1,
              lines: [withSelfie(storedLine(jess, 'dm look', h.ago(30)), 'L1')],
            ),
          ],
        ),
      );
      h.cubit.selectThread(null);

      // Same line id in the room and in Jess's thread: the thread decides.
      h.gateway.pushSelfie(media('media_ready', directWith: jess));
      expect(status(h, jess), SelfieStatus.ready);
      expect(status(h), isNull);

      h.gateway.pushSelfie(media('media_failed'));
      expect(status(h), SelfieStatus.failed);
      expect(status(h, jess), SelfieStatus.ready);
    });

    test('a line still held back gets its picture, shown when revealed', () async {
      final h = await room(hidden: true);
      expect(h.state.thread().lines, isEmpty);
      h.gateway.pushSelfie(started({'status': 'queued', 'media_id': 'm9'}));
      h.gateway.pushSelfie(media('media_ready'));
      h.clock.advance(const Duration(seconds: 31));
      expect(line(h).selfie!.status, SelfieStatus.ready);
    });

    test('a frame during a rewind is ignored', () async {
      final h = await room();
      h.repo.rewindGate = Completer<void>();
      final done = h.cubit.rewind(2);
      h.gateway.pushSelfie(media('media_ready'));
      expect(status(h), isNull);
      h.repo.rewindGate!.complete();
      await done;
    });
  });

  group('tap', () {
    test('queues at once, then applies the answer', () async {
      final h = await room();
      final gate = Completer<GroupSelfie>();
      h.repo.selfieAnswers.add(gate);
      final done = h.cubit.requestSelfie(line(h));
      expect(status(h), SelfieStatus.queued);
      expect(h.repo.selfieCalls.single, {'event': 'e1', 'who': jess, 'text': 'look at me'});
      gate.complete(const GroupSelfie(status: SelfieStatus.queued, mediaId: 'm7'));
      await done;
      expect(line(h).selfie, const GroupSelfie(status: SelfieStatus.queued, mediaId: 'm7'));
    });

    test('a ready answer shows the picture', () async {
      final h = await room();
      h.repo.selfieAnswers.add(
        const GroupSelfie(status: SelfieStatus.ready, mediaId: 'm7', url: 'u'),
      );
      await h.cubit.requestSelfie(line(h));
      expect(line(h).selfie!.url, 'u');
    });

    test('a repeat while queued or processing does nothing', () async {
      final h = await room();
      final gate = Completer<GroupSelfie>();
      h.repo.selfieAnswers.add(gate);
      final first = h.cubit.requestSelfie(line(h));
      await h.cubit.requestSelfie(line(h));
      expect(h.repo.selfieCalls, hasLength(1));
      gate.complete(const GroupSelfie(status: SelfieStatus.queued, mediaId: 'm7'));
      await first;
      h.gateway.pushSelfie(started({'status': 'processing', 'media_id': 'm7'}));
      await h.cubit.requestSelfie(line(h));
      expect(h.repo.selfieCalls, hasLength(1));
    });

    test('a ready or unseen picture is not asked for again', () async {
      final ready = await room(selfie: {'status': 'ready', 'media_id': 'a', 'url': 'u'});
      await ready.cubit.requestSelfie(line(ready));
      final unseen = await room(selfie: {'status': 'unseen', 'media_id': 'a'});
      await unseen.cubit.requestSelfie(line(unseen));
      expect(ready.repo.selfieCalls, isEmpty);
      expect(unseen.repo.selfieCalls, isEmpty);
    });

    test('resting before the reset does nothing; after it, asks the server', () async {
      final h = await room(
        selfie: {'status': 'resting', 'resets_at': h0.add(const Duration(hours: 2)).toIso8601String()},
      );
      await h.cubit.requestSelfie(line(h));
      expect(h.repo.selfieCalls, isEmpty);
      expect(status(h), SelfieStatus.resting);

      h.clock.advance(const Duration(hours: 2, seconds: 1));
      h.repo.selfieAnswers.add(const GroupSelfie(status: SelfieStatus.queued, mediaId: 'm8'));
      await h.cubit.requestSelfie(line(h));
      expect(h.repo.selfieCalls, hasLength(1));
      expect(status(h), SelfieStatus.queued);
    });

    test('a resting answer is kept with its time', () async {
      final h = await room();
      final reset = DateTime.utc(2026, 11, 5);
      h.repo.selfieAnswers.add(GroupSelfie(status: SelfieStatus.resting, resetsAt: reset));
      await h.cubit.requestSelfie(line(h));
      expect(line(h).selfie, GroupSelfie(status: SelfieStatus.resting, resetsAt: reset));
    });

    test('a failure with no answer reverts to failed, and a tap retries', () async {
      final h = await room();
      h.repo.selfieAnswers.add(Exception('offline'));
      await h.cubit.requestSelfie(line(h));
      expect(status(h), SelfieStatus.failed);

      h.repo.selfieAnswers.add(const GroupSelfie(status: SelfieStatus.queued, mediaId: 'm7'));
      await h.cubit.requestSelfie(line(h));
      expect(h.repo.selfieCalls, hasLength(2));
      expect(status(h), SelfieStatus.queued);
    });

    test('a frame that beats the answer is not undone by it', () async {
      final h = await room();
      final gate = Completer<GroupSelfie>();
      h.repo.selfieAnswers.add(gate);
      final done = h.cubit.requestSelfie(line(h));
      h.gateway.pushSelfie(media('media_ready'));
      gate.complete(const GroupSelfie(status: SelfieStatus.queued, mediaId: 'm9'));
      await done;
      expect(status(h), SelfieStatus.ready);
    });

    test('is refused during a rewind', () async {
      final h = await room();
      h.repo.rewindGate = Completer<void>();
      final r = h.cubit.rewind(2);
      await h.cubit.requestSelfie(line(h));
      expect(h.repo.selfieCalls, isEmpty);
      h.repo.rewindGate!.complete();
      await r;
    });

    test('a line not yet saved cannot ask', () async {
      final h = await room();
      h.gateway.pushLines(linesFrame([wireLine(tom, 'unsaved', h.ago(1))]));
      await h.cubit.requestSelfie(h.state.thread().lines.last);
      expect(h.repo.selfieCalls, isEmpty);
    });
  });

  group('rewind and reload', () {
    test('a rewind clears the state and a late answer does not return', () async {
      final h = await room();
      final gate = Completer<GroupSelfie>();
      h.repo.selfieAnswers.add(gate);
      final ask = h.cubit.requestSelfie(line(h));
      await h.cubit.rewind(2);
      h.gateway.pushLoaded(
        loadedFrame(
          events: [
            eventRow(id: 'e1', sequence: 1, lines: [withSelfie(storedLine(jess, 'look at me', h.ago(60)), 'L1')]),
          ],
        ),
      );
      expect(status(h), isNull);
      gate.complete(const GroupSelfie(status: SelfieStatus.ready, mediaId: 'm7', url: 'u'));
      await ask;
      expect(status(h), isNull);
    });

    test('a reload shows the server state', () async {
      final h = await room(selfie: {'status': 'queued', 'media_id': 'm1'});
      h.gateway.pushLoaded(
        loadedFrame(
          events: [
            eventRow(
              id: 'e1',
              sequence: 1,
              lines: [withSelfie(storedLine(jess, 'look at me', h.ago(60)), 'L1', {'status': 'ready', 'media_id': 'm1', 'url': 'u'})],
            ),
          ],
        ),
      );
      expect(status(h), SelfieStatus.ready);
    });

    test('a read without the picture does not drop one already known', () async {
      final h = await room();
      h.gateway.pushSelfie(media('media_ready'));
      h.gateway.pushLoaded(
        loadedFrame(
          events: [
            eventRow(id: 'e1', sequence: 1, lines: [withSelfie(storedLine(jess, 'look at me', h.ago(60)), 'L1')]),
          ],
        ),
      );
      expect(status(h), SelfieStatus.ready);
    });

    test('a reconnect reads a thread with a pending picture, and only then', () async {
      final h = await room(selfie: {'status': 'processing', 'media_id': 'm1'});
      h.cubit.selectThread(jess);
      h.gateway.pushLoaded(
        loadedFrame(
          directWith: jess,
          events: [
            eventRow(id: 'e2', sequence: 2, lines: [withSelfie(storedLine(jess, 'dm', h.ago(30)), 'L2', {'status': 'queued'})]),
          ],
        ),
      );
      h.cubit.selectThread(null);
      final before = h.gateway.loads.length;
      h.gateway.setConnected(false);
      h.gateway.setConnected(true);
      final dms = h.gateway.loads.skip(before).where((m) => m['direct_with'] == jess);
      expect(dms, isNotEmpty);

      // The server says both finished: nothing is stuck, and the next
      // reconnect leaves the direct thread alone.
      h.gateway.pushLoaded(
        loadedFrame(
          events: [
            eventRow(id: 'e1', sequence: 1, lines: [withSelfie(storedLine(jess, 'look at me', h.ago(60)), 'L1', {'status': 'ready', 'media_id': 'm1', 'url': 'u'})]),
          ],
        ),
      );
      h.gateway.pushLoaded(
        loadedFrame(
          directWith: jess,
          events: [
            eventRow(id: 'e2', sequence: 2, lines: [withSelfie(storedLine(jess, 'dm', h.ago(30)), 'L2', {'status': 'unseen'})]),
          ],
        ),
      );
      expect(status(h), SelfieStatus.ready);
      final mid = h.gateway.loads.length;
      h.gateway.setConnected(false);
      h.gateway.setConnected(true);
      expect(h.gateway.loads.skip(mid).where((m) => m['direct_with'] == jess), isEmpty);
    });
  });

  group('requestSelfie over HTTP', () {
    HttpGroupChatRepository repoFor(http.Response Function(http.Request) answer, [List<http.Request>? seen]) =>
        HttpGroupChatRepository(
          baseUrl: 'https://api.test',
          tokenProvider: () async => 't',
          client: MockClient((r) async {
            seen?.add(r);
            return answer(r);
          }),
        );

    test('sends the pair and reads ready, queued and resting', () async {
      final seen = <http.Request>[];
      final ready = await repoFor(
        (_) => http.Response(jsonEncode({'status': 'ready', 'media_id': 'a', 'url': 'u'}), 200),
        seen,
      ).requestSelfie('i1', 'e1', 'c1', 'hi');
      expect(ready.status, SelfieStatus.ready);
      expect(seen.single.url.path, '/instances/i1/events/e1/selfie');
      expect(jsonDecode(seen.single.body), {'character_id': 'c1', 'text': 'hi'});
      expect(seen.single.headers['Authorization'], 'Bearer t');

      final queued = await repoFor(
        (_) => http.Response(jsonEncode({'status': 'queued', 'media_id': 'a'}), 202),
      ).requestSelfie('i1', 'e1', 'c1', 'hi');
      expect(queued.status, SelfieStatus.queued);

      final resting = await repoFor(
        (_) => http.Response(
          jsonEncode({'status': 'resting', 'kind': 'picture', 'resets_at': '2026-11-05T00:00:00.000Z'}),
          429,
        ),
      ).requestSelfie('i1', 'e1', 'c1', 'hi');
      expect(resting.resetsAt, DateTime.utc(2026, 11, 5));
    });

    test('any other failure throws', () async {
      for (final code in [404, 500]) {
        await expectLater(
          repoFor((_) => http.Response('{"error":"no"}', code)).requestSelfie('i1', 'e1', 'c1', 'hi'),
          throwsA(isA<Object>()),
        );
      }
      await expectLater(
        repoFor((_) => http.Response('{"error":"slow down"}', 429)).requestSelfie('i1', 'e1', 'c1', 'hi'),
        throwsA(isA<Object>()),
      );
    });
  });
}

/// The fake clock's start.
final h0 = DateTime.utc(2026, 11, 4, 12);
