import 'dart:async';

import 'package:everlore/core/push/push_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGateway implements PushGateway {
  String? current = 'tok-1';
  Map<String, Object?>? launch;
  final refreshes = StreamController<String>.broadcast();
  final opened = StreamController<Map<String, Object?>>.broadcast();
  int channels = 0;

  @override
  Future<String?> token() async => current;
  @override
  Stream<String> get tokenRefreshes => refreshes.stream;
  @override
  Future<Map<String, Object?>?> launchMessage() async => launch;
  @override
  Stream<Map<String, Object?>> get openedMessages => opened.stream;
  @override
  Future<void> createChannel() async => channels++;
  @override
  Future<bool> permissionGranted() async => false;
  @override
  Future<bool> askPermission() async => false;
}

class _Router extends ChangeNotifier {
  Uri? at = Uri.parse('/splash');
  void go(String location) {
    at = Uri.parse(location);
    notifyListeners();
  }
}

class _Rig {
  _Rig({this.signedIn = true, this.session = true}) {
    service = PushService(
      gateway: gateway,
      register: (token, tz) async {
        if (registerFails) throw Exception('offline');
        registered.add((token, tz));
      },
      unregister: (token) async {
        events.add('delete');
        await deleteGate?.future;
        deleted.add(token);
      },
      signedIn: () async => signedIn,
      hasSession: () async => session,
      tzOffsetMinutes: () => offset,
      locate: () => router.at,
      open: opened.add,
      trackOpened: () => tapsTracked++,
      routerChanges: router,
      signOutBudget: const Duration(milliseconds: 50),
    );
  }

  final gateway = _FakeGateway();
  final router = _Router();
  final registered = <(String, int)>[];
  final deleted = <String>[];
  final opened = <String>[];
  final events = <String>[];
  late final PushService service;
  bool signedIn;
  bool session;
  int offset = 330;
  int tapsTracked = 0;
  bool registerFails = false;
  Completer<void>? deleteGate;

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 10));
}

void main() {
  test('registers once for a signed-in player, with the offset', () async {
    final rig = _Rig();
    await rig.service.init();
    await rig.settle();
    await rig.service.onSessionStarted();
    expect(rig.gateway.channels, 1);
    expect(rig.registered, [('tok-1', 330)]);
  });

  test('never registers a guest', () async {
    final rig = _Rig(signedIn: false);
    await rig.service.init();
    await rig.settle();
    await rig.service.onSessionStarted();
    expect(rig.registered, isEmpty);
  });

  test('a guest who signs in is registered in the same run', () async {
    final rig = _Rig(signedIn: false);
    await rig.service.init();
    await rig.settle();
    rig.signedIn = true;
    await rig.service.onSessionStarted();
    expect(rig.registered, [('tok-1', 330)]);
  });

  test(
    'a refreshed token registers again; a changed offset does too',
    () async {
      final rig = _Rig();
      await rig.service.init();
      await rig.settle();
      rig.gateway.refreshes.add('tok-2');
      await rig.settle();
      expect(rig.registered.last, ('tok-2', 330));
      rig.offset = 60;
      await rig.service.onSessionStarted();
      // The gateway still answers tok-1, which is a new pair at this offset.
      expect(rig.registered.last, ('tok-1', 60));
    },
  );

  test(
    'a failed register does not throw and is retried on the next start',
    () async {
      final rig = _Rig()..registerFails = true;
      await rig.service.init();
      await rig.settle();
      expect(rig.registered, isEmpty);
      rig.registerFails = false;
      await rig.service.onSessionStarted();
      expect(rig.registered, [('tok-1', 330)]);
    },
  );

  test('init never throws when the messaging plugin is unavailable', () async {
    final service = PushService(gateway: _ThrowingGateway());
    await service.init();
    await service.onSessionStarted();
    await service.onSigningOut();
  });

  test('sign-out deletes the registered token', () async {
    final rig = _Rig();
    await rig.service.init();
    await rig.settle();
    await rig.service.onSigningOut();
    expect(rig.deleted, ['tok-1']);
    // Forgotten for the run: the next player on this phone registers afresh.
    await rig.service.onSessionStarted();
    expect(rig.registered.length, 2);
  });

  test('a hanging delete does not hold sign-out up', () async {
    final rig = _Rig()..deleteGate = Completer<void>();
    await rig.service.init();
    await rig.settle();
    final watch = Stopwatch()..start();
    await rig.service.onSigningOut();
    expect(watch.elapsedMilliseconds, lessThan(500));
    expect(rig.events, ['delete']);
    expect(rig.deleted, isEmpty);
  });

  test('a guest signing out sends nothing', () async {
    final rig = _Rig(signedIn: false);
    await rig.service.init();
    await rig.settle();
    await rig.service.onSigningOut();
    expect(rig.events, isEmpty);
  });

  group('taps', () {
    const good = {
      'type': 'group_direct',
      'instanceId': 'inst1',
      'characterId': 'char1',
    };

    for (final bad in <Map<String, Object?>>[
      {'type': 'something_else', 'instanceId': 'a', 'characterId': 'b'},
      {'type': 'group_direct', 'instanceId': '', 'characterId': 'b'},
      {'type': 'group_direct', 'instanceId': 'a'},
      {'type': 'group_direct', 'instanceId': 'a', 'characterId': 7},
      <String, Object?>{},
    ]) {
      test('ignores $bad', () async {
        final rig = _Rig();
        await rig.service.init();
        rig.router.go('/discover');
        rig.gateway.opened.add(bad);
        await rig.settle();
        expect(rig.opened, isEmpty);
      });
    }

    test(
      'a cold-start tap waits for the splash, then opens the thread',
      () async {
        final rig = _Rig();
        rig.gateway.launch = good;
        await rig.service.init();
        await rig.settle();
        expect(rig.opened, isEmpty);
        rig.router.go('/discover');
        await rig.settle();
        expect(rig.opened, ['/group/inst1?member=char1']);
      },
    );

    test('a background tap opens at once, with the ids encoded', () async {
      final rig = _Rig();
      await rig.service.init();
      rig.router.go('/discover');
      rig.gateway.opened.add({
        'type': 'group_direct',
        'instanceId': 'a/b c',
        'characterId': 'x&y=z',
      });
      await rig.settle();
      expect(rig.opened, ['/group/a%2Fb%20c?member=x%26y%3Dz']);
    });

    test('a signed-out player stays where they are', () async {
      final rig = _Rig(session: false);
      await rig.service.init();
      rig.router.go('/welcome');
      rig.gateway.opened.add(good);
      await rig.settle();
      expect(rig.opened, isEmpty);

      final rig2 = _Rig(session: false);
      await rig2.service.init();
      rig2.router.go('/discover');
      rig2.gateway.opened.add(good);
      await rig2.settle();
      expect(rig2.opened, isEmpty);
    });

    test('the same thread already on screen is not pushed again', () async {
      final rig = _Rig();
      await rig.service.init();
      rig.router.go('/group/inst1?member=char1');
      rig.gateway.opened.add(good);
      await rig.settle();
      expect(rig.opened, isEmpty);
    });

    test('another thread of the same group is opened', () async {
      final rig = _Rig();
      await rig.service.init();
      rig.router.go('/group/inst1?member=other');
      rig.gateway.opened.add(good);
      await rig.settle();
      expect(rig.opened, ['/group/inst1?member=char1']);
    });

    test('a tap opens once even if the router keeps changing', () async {
      final rig = _Rig();
      rig.gateway.launch = good;
      await rig.service.init();
      await rig.settle();
      rig.router.go('/discover');
      rig.router.go('/');
      rig.router.go('/discover');
      await rig.settle();
      expect(rig.opened.length, 1);
    });
  });
}

class _ThrowingGateway extends _FakeGateway {
  @override
  Future<void> createChannel() async => throw StateError('no firebase');
}
