import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'group_chat_cubit_test.dart' show Harness, completeFrame;

Map<String, dynamic> ideasFrame(
  String eventId,
  List<String> ideas, {
  String? directWith,
}) => {
  'type': 'group_ideas',
  'instanceId': instanceId,
  if (directWith != null) 'directWith': directWith,
  'eventId': eventId,
  'ideas': ideas,
};

Map<String, dynamic> withIdeas(String id, List<String> ideas, {String? who}) =>
    loadedFrame(
      directWith: who,
      events: [
        eventRow(id: 'e1', sequence: 1, playerInput: 'old'),
        eventRow(id: id, sequence: 2, replyIdeas: ideas),
      ],
    );

void main() {
  group('reply ideas', () {
    test('history gives the newest event ideas', () async {
      final h = Harness();
      await h.open(frame: withIdeas('e2', ['a', 'b', 'c']));
      expect(h.state.replyIdeasFor(), ['a', 'b', 'c']);
    });

    test('a frame for the newest event is applied', () async {
      final h = Harness();
      await h.open(frame: withIdeas('e2', []));
      expect(h.state.replyIdeasFor(), isEmpty);
      h.gateway.pushIdeas(ideasFrame('e2', ['x', 'y']));
      expect(h.state.replyIdeasFor(), ['x', 'y']);
    });

    test('a stale eventId is ignored', () async {
      final h = Harness();
      await h.open(frame: withIdeas('e2', ['a']));
      h.gateway.pushIdeas(ideasFrame('e1', ['stale']));
      expect(h.state.replyIdeasFor(), ['a']);
    });

    test('a frame for another thread leaves this one alone', () async {
      final h = Harness();
      await h.open(frame: withIdeas('e2', ['room']));
      h.gateway.pushLoaded(withIdeas('d2', ['dm'], who: jess));
      expect(h.state.replyIdeasFor(jess), ['dm']);
      h.gateway.pushIdeas(ideasFrame('e2', ['new'], directWith: jess));
      expect(h.state.replyIdeasFor(), ['room']);
      expect(h.state.replyIdeasFor(jess), ['dm']);
      h.gateway.pushIdeas(ideasFrame('d2', ['more'], directWith: jess));
      expect(h.state.replyIdeasFor(jess), ['more']);
      expect(h.state.replyIdeasFor(), ['room']);
    });

    test(
      'sending clears at once, a failed send does not bring them back',
      () async {
        final h = Harness();
        await h.open(frame: withIdeas('e2', ['a', 'b']));
        expect(h.cubit.sendIdea('a'), isTrue);
        expect(h.state.replyIdeasFor(), isEmpty);
        expect(h.gateway.chats.single['text'], 'a');
        // A late frame for the event the send answered is ignored.
        h.gateway.pushIdeas(ideasFrame('e2', ['late']));
        expect(h.state.replyIdeasFor(), isEmpty);
        h.gateway.pushError({'type': 'error', 'code': 'insufficient_ink'});
        expect(h.state.replyIdeasFor(), isEmpty);
      },
    );

    test('the reply of a send takes its own ideas', () async {
      final h = Harness();
      await h.open(frame: withIdeas('e2', ['a']));
      h.cubit.send('hello');
      h.gateway.pushAck('j1');
      h.gateway.pushComplete(
        completeFrame(
          jobId: 'j1',
          eventId: 'e3',
          sequence: 3,
          playerInput: 'hello',
          lines: [],
        ),
      );
      h.gateway.pushIdeas(ideasFrame('e3', ['next']));
      expect(h.state.replyIdeasFor(), ['next']);
    });

    test('a reload after a rewind takes the newest event only', () async {
      final h = Harness();
      await h.open(frame: withIdeas('e2', ['a']));
      h.repo.threadRows = const [];
      await h.cubit.rewind(2);
      expect(h.state.replyIdeasFor(), isEmpty);
      h.gateway.pushLoaded(
        loadedFrame(
          events: [
            eventRow(id: 'e1', sequence: 1, replyIdeas: ['kept']),
          ],
        ),
      );
      expect(h.state.replyIdeasFor(), ['kept']);
      h.gateway.pushIdeas(ideasFrame('e2', ['removed']));
      expect(h.state.replyIdeasFor(), ['kept']);
    });
  });

  group('first text ideas', () {
    final cards = [
      {
        '_id': jess,
        'canonical_name': 'Jess',
        'status': 'at the market',
        'first_texts': ['one', 'two', 'three'],
      },
      {'_id': tom, 'canonical_name': 'Tom'},
    ];

    test(
      'offered for an empty direct thread, gone after the first send',
      () async {
        final h = Harness();
        await h.open(frame: loadedFrame(characters: cards));
        expect(h.state.member(jess)!.status, 'at the market');
        expect(h.state.firstTextIdeas(jess), isEmpty); // thread not read yet
        h.gateway.pushLoaded(loadedFrame(characters: cards, directWith: jess));
        expect(h.state.firstTextIdeas(jess), ['one', 'two', 'three']);
        expect(h.state.firstTextIdeas(tom), isEmpty);
        h.cubit.sendIdea('one', directWith: jess);
        expect(h.state.firstTextIdeas(jess), isEmpty);
        h.gateway.pushError({'type': 'error', 'code': 'insufficient_ink'});
        expect(h.state.firstTextIdeas(jess), isEmpty);
      },
    );

    test('none while a message waits, none with lines', () async {
      final h = Harness();
      await h.open(
        frame: loadedFrame(characters: cards, pendingFrom: [jess]),
      );
      h.gateway.pushLoaded(
        loadedFrame(characters: cards, directWith: jess, pendingFrom: [jess]),
      );
      expect(h.state.firstTextIdeas(jess), isEmpty);
      final g = Harness();
      await g.open(frame: loadedFrame(characters: cards));
      g.gateway.pushLoaded(
        loadedFrame(
          characters: cards,
          directWith: jess,
          events: [eventRow(id: 'e1', sequence: 1, playerInput: 'hi')],
        ),
      );
      expect(g.state.firstTextIdeas(jess), isEmpty);
    });

    test('missing fields parse', () async {
      final h = Harness();
      await h.open();
      expect(h.state.member(jess)!.status, isNull);
      expect(h.state.member(jess)!.firstTexts, isEmpty);
      expect(h.state.replyIdeasFor(), isEmpty);
    });
  });
}
