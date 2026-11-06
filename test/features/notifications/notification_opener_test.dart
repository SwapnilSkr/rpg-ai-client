import 'package:everlore/core/notifications/notification_opener.dart';
import 'package:everlore/core/notifications/on_screen.dart';
import 'package:flutter_test/flutter_test.dart';

class _Rig {
  final pushed = <String>[];
  final films = <String>[];
  final notices = <String>[];
  final gone = <String>[];
  bool saveThere = true;
  bool filmThere = true;

  late final opener = NotificationOpener(
    saveExists: (_) async => saveThere,
    push: pushed.add,
    openFilm: (id) async {
      films.add(id);
      return filmThere;
    },
    notice: notices.add,
    onGone: gone.add,
  );
}

NotificationTap _tap(
  String type, {
  String? character,
  String? thread,
  String? media,
}) => NotificationTap(
  type: type,
  instanceId: 'inst',
  characterId: character,
  thread: thread,
  mediaId: media,
);

void main() {
  group('where each type goes', () {
    final table = <String, (NotificationTap, String)>{
      'group_direct': (
        _tap('group_direct', character: 'c'),
        '/group/inst?member=c',
      ),
      'selfie in a direct thread': (
        _tap('group_selfie', character: 'c', thread: 'direct'),
        '/group/inst?member=c',
      ),
      'selfie in the room': (
        _tap('group_selfie', character: 'c', thread: 'room'),
        '/group/inst',
      ),
      'selfie, no thread': (
        _tap('group_selfie', character: 'c'),
        '/group/inst',
      ),
      'reply in the room': (_tap('story_reply', thread: 'room'), '/group/inst'),
      'reply in a direct thread': (
        _tap('story_reply', character: 'c', thread: 'direct'),
        '/group/inst?member=c',
      ),
      'direct reply without a character': (
        _tap('story_reply', thread: 'direct'),
        '/group/inst',
      ),
      'reply in a normal world': (_tap('story_reply'), '/play/inst'),
    };
    table.forEach((name, row) {
      test(name, () async {
        final rig = _Rig();
        expect(await rig.opener.open(row.$1), OpenResult.opened);
        expect(rig.pushed, [row.$2]);
        expect(rig.films, isEmpty);
      });
    });

    test('film_ready opens the film, not a screen', () async {
      final rig = _Rig();
      expect(
        await rig.opener.open(_tap('film_ready', media: 'm')),
        OpenResult.opened,
      );
      expect(rig.films, ['m']);
      expect(rig.pushed, isEmpty);
    });

    test('an unknown type opens nothing and says nothing', () async {
      final rig = _Rig();
      expect(await rig.opener.open(_tap('mystery')), OpenResult.nothing);
      expect(rig.pushed, isEmpty);
      expect(rig.notices, isEmpty);
    });
  });

  group('a save that is gone', () {
    test('is explained once, reported, and not opened', () async {
      final rig = _Rig()..saveThere = false;
      expect(await rig.opener.open(_tap('story_reply')), OpenResult.gone);
      expect(rig.pushed, isEmpty);
      expect(rig.notices, hasLength(1));
      expect(rig.gone, ['inst']);
    });

    test('a film that is gone is explained too', () async {
      final rig = _Rig()..filmThere = false;
      expect(
        await rig.opener.open(_tap('film_ready', media: 'm')),
        OpenResult.gone,
      );
      expect(rig.notices, hasLength(1));
    });
  });

  group('push data', () {
    test('needs a text instance id, and what its type needs', () {
      expect(NotificationTap.fromPush({'type': 'group_direct'}), isNull);
      expect(
        NotificationTap.fromPush({'type': 'group_direct', 'instanceId': 'i'}),
        isNull,
      );
      expect(
        NotificationTap.fromPush({'type': 'film_ready', 'instanceId': 'i'}),
        isNull,
      );
      expect(
        NotificationTap.fromPush({'type': 'x', 'instanceId': 'i'}),
        isNull,
      );
      expect(
        NotificationTap.fromPush({'type': 'story_reply', 'instanceId': 7}),
        isNull,
      );
      expect(
        NotificationTap.fromPush({'type': 'story_reply', 'instanceId': 'i'}),
        isNotNull,
      );
    });
  });

  group('on screen', () {
    test('the newest screen is the one on screen, and leaving restores', () {
      final screens = OnScreen();
      final room = Object();
      final direct = Object();
      screens.enter(room, const Place.room('i'));
      screens.enter(direct, const Place.direct('i', 'c'));
      expect(screens.isShowing(const Place.direct('i', 'c')), isTrue);
      expect(screens.isShowing(const Place.room('i')), isFalse);
      expect(screens.isShowing(const Place.direct('i', 'other')), isFalse);
      screens.leave(direct);
      expect(screens.isShowing(const Place.room('i')), isTrue);
      screens.leave(room);
      expect(screens.current, isNull);
      expect(screens.isShowing(null), isFalse);
    });
  });
}
