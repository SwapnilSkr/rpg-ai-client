import 'dart:async';

import 'package:everlore/core/notifications/notification_opener.dart';
import 'package:everlore/core/notifications/on_screen.dart';
import 'package:everlore/features/notifications/data/notifications_repository.dart';
import 'package:everlore/features/notifications/models/app_notification.dart';
import 'package:everlore/features/notifications/state/notifications_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime.utc(2026, 11, 6, 12);

Map<String, dynamic> _raw(
  String id, {
  int minutes = 0,
  String type = 'group_direct',
  String instance = 'inst',
  String? character = 'c',
  String? thread,
  String? media,
  bool read = false,
}) => {
  'id': id,
  'type': type,
  'instance_id': instance,
  'character_id': ?character,
  'thread': ?thread,
  'media_id': ?media,
  'title': 'Title $id',
  'body': 'Body',
  'created_at': _t0.add(Duration(minutes: minutes)).toIso8601String(),
  if (read) 'read_at': _t0.toIso8601String(),
};

class _Repo implements NotificationsRepository {
  final pages = <String?, NotificationsPage>{};
  final calls = <String?>[];
  final marked = <List<String>>[];
  final mediaMarked = <String>[];
  int markAllCalls = 0;
  bool failMarks = false;
  bool failPage = false;
  int unreadAfterMark = 0;
  Completer<void>? markGate;

  @override
  Future<NotificationsPage> page({String? before}) async {
    calls.add(before);
    if (failPage) throw Exception('offline');
    return pages[before] ??
        const NotificationsPage(items: [], unread: 0, hasMore: false);
  }

  Future<int> _result() async {
    await markGate?.future;
    if (failMarks) throw Exception('refused');
    return unreadAfterMark;
  }

  @override
  Future<int> markIds(List<String> ids) {
    marked.add(ids);
    return _result();
  }

  @override
  Future<int> markAll() {
    markAllCalls++;
    return _result();
  }

  @override
  Future<int> markMedia(String mediaId) {
    mediaMarked.add(mediaId);
    return _result();
  }
}

class _Rig {
  _Rig({this.foreground = true}) {
    cubit = NotificationsCubit(
      repository: repo,
      opener: NotificationOpener(
        saveExists: (_) async => saveThere,
        push: pushed.add,
        openFilm: (id) async => filmThere,
        notice: notices.add,
      ),
      onScreen: screens,
      frames: frames.stream,
      connection: connection.stream,
      isForeground: () => foreground,
      now: () => _t0.add(const Duration(hours: 1)),
    );
  }

  final repo = _Repo();
  final screens = OnScreen();
  final frames = StreamController<Map<String, dynamic>>.broadcast();
  final connection = StreamController<bool>.broadcast();
  final pushed = <String>[];
  final notices = <String>[];
  bool foreground;
  bool saveThere = true;
  bool filmThere = true;
  late final NotificationsCubit cubit;

  Future<void> tick() => Future<void>.delayed(Duration.zero);

  Future<void> frame(Map<String, dynamic> item, int unread) async {
    frames.add({'type': 'notification', 'item': item, 'unread': unread});
    await tick();
  }

  List<String> get ids => [for (final i in cubit.state.items) i.id];
}

List<Map<String, dynamic>> _thirty(int from) => [
  for (var i = 0; i < 30; i++) _raw('n${from - i}', minutes: from - i),
];

NotificationsPage _page(
  List<Map<String, dynamic>> raw,
  int unread, {
  bool more = false,
}) => NotificationsPage(
  items: [for (final r in raw) AppNotification.parse(r)!],
  unread: unread,
  hasMore: more,
);

void main() {
  group('reading', () {
    test('loads the first page with the server\'s unread count', () async {
      final rig = _Rig();
      rig.repo.pages[null] = _page([
        _raw('b', minutes: 2),
        _raw('a', minutes: 1),
      ], 7);
      await rig.cubit.load();
      expect(rig.ids, ['b', 'a']);
      expect(rig.cubit.state.unread, 7);
      expect(rig.cubit.state.hasLoaded, isTrue);
      expect(rig.cubit.state.hasMore, isFalse);
    });

    test('a failed first read says so and keeps nothing', () async {
      final rig = _Rig();
      rig.repo.failPage = true;
      await rig.cubit.load();
      expect(rig.cubit.state.hasError, isTrue);
      expect(rig.cubit.state.items, isEmpty);
    });

    test(
      'pages with before=<last id> and drops repeats, newest first',
      () async {
        final rig = _Rig();
        rig.repo.pages[null] = _page(_thirty(100), 5, more: true);
        // The older page repeats one row already held.
        rig.repo.pages['n71'] = _page([
          _raw('n71', minutes: 71),
          _raw('n70', minutes: 70),
          _raw('n69', minutes: 69),
        ], 4);
        await rig.cubit.load();
        expect(rig.cubit.state.hasMore, isTrue);
        await rig.cubit.loadMore();
        expect(rig.repo.calls, [null, 'n71']);
        expect(rig.ids.length, 32);
        expect(rig.ids.toSet().length, 32);
        expect(rig.ids.last, 'n69');
        expect(rig.cubit.state.hasMore, isFalse);
        expect(rig.cubit.state.unread, 4);
        // At the end, asking again reads nothing.
        await rig.cubit.loadMore();
        expect(rig.repo.calls.length, 2);
      },
    );
  });

  group('live', () {
    test(
      'a frame inserts at the front and sets unread from the server',
      () async {
        final rig = _Rig();
        rig.repo.pages[null] = _page([_raw('a', minutes: 1)], 1);
        await rig.cubit.load();
        await rig.frame(_raw('b', minutes: 5), 9);
        expect(rig.ids, ['b', 'a']);
        expect(rig.cubit.state.unread, 9);
      },
    );

    test('a frame for a held id replaces it and moves it up', () async {
      final rig = _Rig();
      rig.repo.pages[null] = _page([
        _raw('b', minutes: 3),
        _raw('a', minutes: 1),
      ], 2);
      await rig.cubit.load();
      await rig.frame(_raw('a', minutes: 9), 2);
      expect(rig.ids, ['a', 'b']);
      expect(
        rig.cubit.state.items.first.createdAt,
        _t0.add(const Duration(minutes: 9)),
      );
    });

    test(
      "a story's newer reply drops its older unread row, not other saves'",
      () async {
        final rig = _Rig();
        rig.repo.pages[null] = _page([
          _raw('old', minutes: 3, type: 'story_reply', instance: 's1'),
          _raw('other', minutes: 2, type: 'story_reply', instance: 's2'),
          _raw('dm', minutes: 1, instance: 's1'),
        ], 3);
        await rig.cubit.load();
        await rig.frame(
          _raw('new', minutes: 9, type: 'story_reply', instance: 's1'),
          3,
        );
        expect(rig.ids, ['new', 'other', 'dm']);
      },
    );

    test('a bad frame is ignored', () async {
      final rig = _Rig();
      rig.repo.pages[null] = _page([_raw('a')], 1);
      await rig.cubit.load();
      rig.frames.add({
        'type': 'notification',
        'item': {'id': 'x'},
        'unread': 3,
      });
      await rig.tick();
      expect(rig.ids, ['a']);
      expect(rig.cubit.state.unread, 1);
    });

    test('a row that arrives during the first read is kept', () async {
      final rig = _Rig();
      rig.repo.pages[null] = _page([_raw('a', minutes: 1)], 1);
      final loading = rig.cubit.load();
      await rig.frame(_raw('late', minutes: 8), 2);
      await loading;
      expect(rig.ids, ['late', 'a']);
    });

    test('a reconnect reads the list again', () async {
      final rig = _Rig();
      rig.repo.pages[null] = _page([_raw('a')], 1);
      await rig.cubit.load();
      rig.repo.pages[null] = _page([_raw('z', minutes: 4), _raw('a')], 2);
      rig.connection.add(true);
      await rig.tick();
      await rig.tick();
      expect(rig.ids, ['z', 'a']);
    });
  });

  group('banner', () {
    test('shows for an arrival while the app is open', () async {
      final rig = _Rig();
      await rig.cubit.load();
      await rig.frame(_raw('a'), 1);
      expect(rig.cubit.state.banner?.item.id, 'a');
    });

    test('not when the app is in the background', () async {
      final rig = _Rig(foreground: false);
      await rig.cubit.load();
      await rig.frame(_raw('a'), 1);
      expect(rig.cubit.state.banner, isNull);
      expect(rig.ids, ['a']);
    });

    test('not when the direct thread it points at is on screen', () async {
      final rig = _Rig();
      await rig.cubit.load();
      final screen = Object();
      rig.screens.enter(screen, const Place.direct('inst', 'c'));
      await rig.frame(_raw('a'), 1);
      expect(rig.cubit.state.banner, isNull);
      // Another character's thread is not the one on screen.
      await rig.frame(_raw('b', character: 'other', minutes: 1), 2);
      expect(rig.cubit.state.banner?.item.id, 'b');
    });

    test('not when the room, or the story, is on screen', () async {
      final rig = _Rig();
      await rig.cubit.load();
      final room = Object();
      rig.screens.enter(room, const Place.room('inst'));
      await rig.frame(_raw('a', type: 'group_selfie', thread: 'room'), 1);
      expect(rig.cubit.state.banner, isNull);
      rig.screens.leave(room);
      rig.screens.enter(room, const Place.play('inst'));
      await rig.frame(
        _raw('b', type: 'story_reply', character: null, minutes: 1),
        2,
      );
      expect(rig.cubit.state.banner, isNull);
    });

    test('a film is shown even from inside its story', () async {
      final rig = _Rig();
      await rig.cubit.load();
      rig.screens.enter(Object(), const Place.play('inst'));
      await rig.frame(
        _raw('f', type: 'film_ready', character: null, media: 'm'),
        1,
      );
      expect(rig.cubit.state.banner?.item.id, 'f');
    });

    test(
      'a second event replaces the first; an old exit does not clear the new',
      () async {
        final rig = _Rig();
        await rig.cubit.load();
        await rig.frame(_raw('a'), 1);
        final first = rig.cubit.state.banner!;
        await rig.frame(_raw('b', minutes: 1), 2);
        final second = rig.cubit.state.banner!;
        expect(second.item.id, 'b');
        expect(second.seq, isNot(first.seq));
        rig.cubit.dismissBanner(first.seq);
        expect(rig.cubit.state.banner, second);
        rig.cubit.dismissBanner(second.seq);
        expect(rig.cubit.state.banner, isNull);
      },
    );

    test(
      'a kind this build cannot open gets no banner but is listed',
      () async {
        final rig = _Rig();
        await rig.cubit.load();
        await rig.frame(_raw('x', type: 'mystery'), 1);
        expect(rig.cubit.state.banner, isNull);
        expect(rig.ids, ['x']);
      },
    );
  });

  group('taps', () {
    Future<_Rig> held(List<Map<String, dynamic>> rows, int unread) async {
      final rig = _Rig();
      rig.repo.pages[null] = _page(rows, unread);
      await rig.cubit.load();
      return rig;
    }

    test('a row is marked read first, then opened', () async {
      final rig = await held([_raw('a')], 1);
      rig.repo.unreadAfterMark = 0;
      final result = await rig.cubit.open(rig.cubit.state.items.first);
      expect(result, OpenResult.opened);
      expect(rig.pushed, ['/group/inst?member=c']);
      expect(rig.repo.marked, [
        ['a'],
      ]);
      expect(rig.cubit.state.items.first.isUnread, isFalse);
      expect(rig.cubit.state.unread, 0);
    });

    test('an unknown type is only marked read', () async {
      final rig = await held([_raw('x', type: 'mystery')], 1);
      expect(
        await rig.cubit.open(rig.cubit.state.items.first),
        OpenResult.nothing,
      );
      expect(rig.pushed, isEmpty);
      expect(rig.repo.marked, [
        ['x'],
      ]);
      expect(rig.cubit.state.items.first.isUnread, isFalse);
    });

    test('a tapped banner clears itself', () async {
      final rig = await held([], 0);
      await rig.frame(_raw('a'), 1);
      await rig.cubit.open(rig.cubit.state.banner!.item);
      expect(rig.cubit.state.banner, isNull);
    });

    test('a gone save is explained and takes its rows with it', () async {
      final rig = await held([
        _raw('a', minutes: 2, instance: 'dead'),
        _raw('b', minutes: 1, instance: 'dead'),
        _raw('c', instance: 'alive'),
      ], 3);
      rig.saveThere = false;
      // The server's count when the tap was marked, before the save's rows
      // were dropped here.
      rig.repo.unreadAfterMark = 2;
      final result = await rig.cubit.open(rig.cubit.state.items.first);
      expect(result, OpenResult.gone);
      expect(rig.notices, hasLength(1));
      expect(rig.pushed, isEmpty);
      expect(rig.ids, ['c']);
      expect(rig.cubit.state.unread, 1);
    });

    test('a gone film removes just its row', () async {
      final rig = await held([
        _raw('f', minutes: 2, type: 'film_ready', media: 'm', character: null),
        _raw('g', minutes: 1, type: 'film_ready', media: 'n', character: null),
      ], 2);
      rig.filmThere = false;
      await rig.cubit.open(rig.cubit.state.items.first);
      expect(rig.ids, ['g']);
    });
  });

  group('marking', () {
    test('mark all is optimistic, and the server\'s count wins', () async {
      final rig = _Rig();
      rig.repo.pages[null] = _page([_raw('a', minutes: 1), _raw('b')], 12);
      await rig.cubit.load();
      rig.repo.markGate = Completer<void>();
      rig.repo.unreadAfterMark = 3;
      final done = rig.cubit.markAllRead();
      await rig.tick();
      expect(rig.cubit.state.unread, 0);
      expect(rig.cubit.state.items.every((i) => !i.isUnread), isTrue);
      rig.repo.markGate!.complete();
      await done;
      expect(rig.cubit.state.unread, 3);
    });

    test('mark all rolls back when refused', () async {
      final rig = _Rig();
      rig.repo.pages[null] = _page([
        _raw('a', minutes: 1),
        _raw('b', read: true),
      ], 12);
      await rig.cubit.load();
      rig.repo.failMarks = true;
      await rig.cubit.markAllRead();
      expect(rig.cubit.state.unread, 12);
      expect(rig.cubit.state.items.map((i) => i.isUnread), [true, false]);
    });

    test('one row rolls back when refused', () async {
      final rig = _Rig();
      rig.repo.pages[null] = _page([_raw('a')], 4);
      await rig.cubit.load();
      rig.repo.failMarks = true;
      await rig.cubit.markRead('a');
      expect(rig.cubit.state.unread, 4);
      expect(rig.cubit.state.items.single.isUnread, isTrue);
    });

    test('a row already read costs no request', () async {
      final rig = _Rig();
      rig.repo.pages[null] = _page([_raw('a', read: true)], 0);
      await rig.cubit.load();
      await rig.cubit.markRead('a');
      expect(rig.repo.marked, isEmpty);
    });

    test('opening a film marks its row; a failure is silent', () async {
      final rig = _Rig();
      rig.repo.pages[null] = _page([
        _raw('f', type: 'film_ready', media: 'm', character: null),
      ], 1);
      await rig.cubit.load();
      rig.repo.unreadAfterMark = 0;
      await rig.cubit.filmOpened('m');
      expect(rig.repo.mediaMarked, ['m']);
      expect(rig.cubit.state.unread, 0);
      expect(rig.cubit.state.items.single.isUnread, isFalse);

      rig.repo.failMarks = true;
      await rig.cubit.filmOpened('other');
      expect(rig.cubit.state.unread, 0);
    });
  });

  group('sign-out', () {
    test('clears everything and drops a read still in flight', () async {
      final rig = _Rig();
      rig.repo.pages[null] = _page([_raw('a')], 1);
      await rig.cubit.load();
      await rig.frame(_raw('b', minutes: 1), 2);
      expect(rig.cubit.state.banner, isNotNull);
      rig.cubit.reset();
      expect(rig.cubit.state.items, isEmpty);
      expect(rig.cubit.state.unread, 0);
      expect(rig.cubit.state.hasLoaded, isFalse);
      expect(rig.cubit.state.banner, isNull);

      // The next account's list is not mixed with an old answer.
      final slow = Completer<NotificationsPage>();
      final rig2 = _Rig();
      final repo = _SlowRepo(slow);
      final cubit = NotificationsCubit(
        repository: repo,
        onScreen: rig2.screens,
        frames: rig2.frames.stream,
        connection: rig2.connection.stream,
      );
      final loading = cubit.load();
      cubit.reset();
      slow.complete(_page([_raw('old')], 1));
      await loading;
      expect(cubit.state.items, isEmpty);
      await cubit.close();
    });
  });
}

class _SlowRepo extends _Repo {
  _SlowRepo(this.gate);
  final Completer<NotificationsPage> gate;
  @override
  Future<NotificationsPage> page({String? before}) => gate.future;
}
