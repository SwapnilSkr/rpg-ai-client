import 'dart:async';

import 'package:everlore/features/group_chat/data/group_chat_repository.dart';
import 'package:everlore/features/group_chat/models/group_chat_models.dart';
import 'package:everlore/features/group_chat/state/chats_cubit.dart';
import 'package:everlore/features/group_chat/state/chats_read_marks.dart';
import 'package:everlore/shared/models/world_template.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repo implements GroupChatRepository {
  final List<Future<List<GroupChatRow>> Function()> script = [];
  int calls = 0;

  @override
  Future<List<GroupChatRow>> chats() =>
      script[calls++ < script.length ? calls - 1 : script.length - 1]();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _BrokenStorage implements FlutterSecureStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('storage');
}

final _t0 = DateTime.utc(2026, 11, 4, 12);
String _iso(int minutes) =>
    _t0.add(Duration(minutes: minutes)).toIso8601String();

Map<String, dynamic> _line(int minutes, {bool player = false}) => {
  'from': player ? 'player' : 'member',
  if (!player) 'name': 'Ana',
  'text': 'hi',
  'at': _iso(minutes),
};

Map<String, dynamic> _row(
  String id, {
  String template = 't',
  Map<String, dynamic>? last,
  List<Map<String, dynamic>> threads = const [],
  List<String> pending = const [],
}) => {
  'instance_id': id,
  'template_id': template,
  'title': 'Group $id',
  'members': [
    {'id': 'a', 'name': 'Ana', 'role': 'friend'},
    {'id': 'b', 'name': 'Ben'},
  ],
  'last': ?last,
  'pending_from': pending,
  'threads': threads,
};

List<GroupChatRow> _rows(List<Map<String, dynamic>> raw) => [
  for (final r in raw) ?GroupChatRow.parse(r),
];

WorldTemplate _template(String id) => WorldTemplate(
  id: id,
  creatorId: '',
  title: 'T$id',
  slug: id,
  description: '',
  kind: 'group',
);

void main() {
  late _Repo repo;
  late List<WorldTemplate> templates;
  var clock = _t0.add(const Duration(minutes: 100));

  ChatsCubit make({ChatsReadMarks? marks}) => ChatsCubit(
    repository: repo,
    marks: marks ?? const ChatsReadMarks(),
    loadTemplates: () async => templates,
    now: () => clock,
  );

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    repo = _Repo();
    templates = [];
    clock = _t0.add(const Duration(minutes: 100));
  });

  test('a malformed row is dropped, not thrown', () {
    final rows = _rows([
      _row('ok'),
      {'title': 'no id'},
      {
        'instance_id': 'x',
        'members': 'nope',
        'last': 7,
        'threads': [3],
      },
    ]);
    expect(rows.map((r) => r.instanceId), ['ok', 'x']);
    expect(rows.last.members, isEmpty);
    expect(rows.last.last, isNull);
    expect(GroupChatRow.parse('junk'), isNull);
    expect(GroupLastLine.parse({'from': 'member', 'text': 'x'}), isNull);
  });

  test(
    'conversations without last stay listed, with no preview or dot',
    () async {
      repo.script.add(
        () async => _rows([
          _row(
            'g',
            threads: [
              {'member_id': 'a', 'message_count': 3},
            ],
          ),
        ]),
      );
      final cubit = make();
      await cubit.refresh();
      final list = cubit.state.conversations;
      expect(list.map((c) => c.key), ['g', 'g|a']);
      expect(list.every((c) => c.last == null && !c.unread), isTrue);
      expect(list.last.title, 'Ana');
      expect(list.last.groupTitle, 'Group g');
      expect(list.first.faces.length, 2);
      await cubit.close();
    },
  );

  test('sorted newest first; undated after dated, in server order', () async {
    repo.script.add(
      () async => _rows([
        _row('undated1'),
        _row('old', last: _line(1)),
        _row(
          'new',
          last: _line(9),
          threads: [
            {'member_id': 'b', 'last': _line(20), 'message_count': 1},
          ],
        ),
        _row('undated2'),
      ]),
    );
    final cubit = make();
    await cubit.refresh();
    expect(cubit.state.conversations.map((c) => c.key), [
      'new|b',
      'new',
      'old',
      'undated1',
      'undated2',
    ]);
    await cubit.close();
  });

  test(
    'unread: member line newer than mark; player line never; markOpened clears',
    () async {
      repo.script.add(
        () async => _rows([
          _row('m', last: _line(5)),
          _row('p', last: _line(6, player: true)),
        ]),
      );
      final cubit = make();
      await cubit.refresh();
      bool unread(String k) =>
          cubit.state.conversations.firstWhere((c) => c.key == k).unread;
      expect(unread('m'), isTrue);
      expect(unread('p'), isFalse);

      await cubit.markOpened('m');
      expect(unread('m'), isFalse);
      expect(cubit.state.unreadCount, 0);

      // Persisted: a fresh cubit sees the mark; a newer line is unread again.
      repo.script
        ..clear()
        ..add(() async => _rows([_row('m', last: _line(5))]));
      repo.calls = 0;
      final again = make();
      await again.refresh();
      expect(again.state.conversations.single.unread, isFalse);
      repo.script
        ..clear()
        ..add(() async => _rows([_row('m', last: _line(500))]));
      repo.calls = 0;
      await again.refresh();
      expect(again.state.conversations.single.unread, isTrue);
      await cubit.close();
      await again.close();
    },
  );

  test(
    'older than the mark is read, even when the phone clock is behind',
    () async {
      clock = _t0; // behind the line below
      repo.script.add(() async => _rows([_row('m', last: _line(30))]));
      final cubit = make();
      await cubit.refresh();
      await cubit.markOpened('m');
      expect(cubit.state.conversations.single.unread, isFalse);
      await cubit.close();
    },
  );

  test(
    'pending shows an unread thread with no rows, until it is opened',
    () async {
      repo.script.add(
        () async => _rows([
          _row('g', pending: ['b']),
        ]),
      );
      final cubit = make();
      await cubit.refresh();
      var thread = cubit.state.conversations.firstWhere((c) => c.key == 'g|b');
      expect(thread.unread, isTrue);
      expect(thread.last, isNull);
      expect(
        cubit.state.conversations.firstWhere((c) => c.key == 'g').unread,
        isFalse,
      );

      await cubit.markOpened('g', memberId: 'b');
      thread = cubit.state.conversations.firstWhere((c) => c.key == 'g|b');
      expect(thread.unread, isFalse);

      // Still listed as waiting on the next read: stays read.
      await cubit.refresh();
      expect(
        cubit.state.conversations.firstWhere((c) => c.key == 'g|b').unread,
        isFalse,
      );
      await cubit.close();
    },
  );

  test('a failed refresh keeps the rows and flags the error', () async {
    repo.script
      ..add(() async => _rows([_row('g', last: _line(1))]))
      ..add(() async => throw Exception('offline'));
    final cubit = make();
    await cubit.refresh();
    expect(cubit.state.hasError, isFalse);
    await cubit.refresh();
    expect(cubit.state.hasError, isTrue);
    expect(cubit.state.hasLoaded, isTrue);
    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.conversations.single.key, 'g');
    await cubit.close();
  });

  test(
    'overlapping refreshes join; the newest response is the one drawn',
    () async {
      final first = Completer<List<GroupChatRow>>();
      repo.script
        ..add(() => first.future)
        ..add(() async => _rows([_row('newer')]));
      final cubit = make();
      final a = cubit.refresh();
      final b = cubit.refresh();
      // The read marks load first; wait until the first read is in flight.
      while (repo.calls == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(repo.calls, 1);
      first.complete(_rows([_row('older')]));
      await Future.wait([a, b]);
      expect(repo.calls, 2);
      expect(cubit.state.conversations.single.key, 'newer');
      expect(cubit.state.isLoading, isFalse);
      await cubit.close();
    },
  );

  test(
    'joinable leaves out groups with a save, and waits for the saves',
    () async {
      templates = [_template('t'), _template('free')];
      repo.script
        ..add(() async => throw Exception('offline'))
        ..add(() async => _rows([_row('g', template: 't')]));
      final cubit = make();
      await cubit.refresh();
      expect(cubit.state.joinable, isEmpty);
      await cubit.refresh();
      expect(cubit.state.joinable.map((t) => t.id), ['free']);
      await cubit.close();
    },
  );

  test('storage failure never breaks the list', () async {
    repo.script.add(() async => _rows([_row('g', last: _line(5))]));
    final cubit = make(marks: ChatsReadMarks(_BrokenStorage()));
    await cubit.refresh();
    expect(cubit.state.conversations.single.unread, isTrue);
    await cubit.markOpened('g');
    expect(cubit.state.conversations.single.unread, isFalse);
    await cubit.close();
  });

  test('template members parse; other kinds have none', () {
    final t = WorldTemplate.fromJson({
      'id': 'x',
      'kind': 'group',
      'members': [
        {'name': 'Ana', 'role': 'friend', 'portrait_url': 'u'},
        {'name': 'Ben'},
        {'role': 'no name'},
        'junk',
      ],
    });
    expect(t.members.map((m) => m.name), ['Ana', 'Ben']);
    expect(t.members.first.portraitUrl, 'u');
    expect(t.members.last.portraitUrl, isNull);
    expect(WorldTemplate.fromJson({'id': 'w'}).members, isEmpty);
  });

  test('reset forgets the rows and the marks', () async {
    repo.script.add(() async => _rows([_row('m', last: _line(5))]));
    templates = [_template('other')];
    final cubit = make();
    await cubit.refresh();
    await cubit.markOpened('m');
    expect(cubit.state.conversations, isNotEmpty);
    expect(cubit.state.joinable, isNotEmpty);

    cubit.reset();
    expect(cubit.state.conversations, isEmpty);
    expect(cubit.state.joinable, isEmpty);
    expect(cubit.state.hasLoaded, isFalse);

    // The next account's read starts clean: the old mark is gone from memory
    // (the device store is keyed by save id, so it is not read back here).
    repo.script
      ..clear()
      ..add(() async => _rows([_row('n', last: _line(5))]));
    repo.calls = 0;
    await cubit.refresh();
    expect(cubit.state.conversations.map((c) => c.key), ['n']);
    await cubit.close();
  });

  test('a read still running at reset is dropped, not drawn', () async {
    final gate = Completer<List<GroupChatRow>>();
    repo.script.add(() => gate.future);
    final cubit = make();
    final read = cubit.refresh();
    await Future<void>.delayed(Duration.zero);

    cubit.reset();
    gate.complete(_rows([_row('old', last: _line(5))]));
    await read;

    expect(cubit.state.conversations, isEmpty);
    expect(cubit.state.hasLoaded, isFalse);
    expect(cubit.state.isLoading, isFalse);
    await cubit.close();
  });

  test('a refresh asked for after reset is read and drawn', () async {
    final gate = Completer<List<GroupChatRow>>();
    repo.script
      ..add(() => gate.future)
      ..add(() async => _rows([_row('new', last: _line(5))]));
    final cubit = make();
    final read = cubit.refresh();
    await Future<void>.delayed(Duration.zero);

    cubit.reset();
    final again = cubit.refresh();
    gate.complete(_rows([_row('old', last: _line(5))]));
    await Future.wait([read, again]);

    expect(cubit.state.conversations.map((c) => c.key), ['new']);
    await cubit.close();
  });
}
