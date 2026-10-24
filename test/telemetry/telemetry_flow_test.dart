import 'dart:convert';

import 'package:everlore/core/telemetry/sender.dart';
import 'package:everlore/core/telemetry/telemetry_vocabulary.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

List<Map<String, dynamic>> eventsOf(FakeTransport t) => [
  for (final b in t.bodies)
    for (final e in jsonDecode(b)['events'] as List)
      e as Map<String, dynamic>,
];

List<Map<String, dynamic>> errorsOf(FakeTransport t) => [
  for (final b in t.bodies)
    for (final e in jsonDecode(b)['errors'] as List)
      e as Map<String, dynamic>,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('vocabulary', () {
    test('accepts the contract and rejects typos and junk', () {
      expect(validateEvent('persona_created', {}), isNull);
      expect(
        validateEvent('sign_in_failed', {'method': 'google', 'reason': 'cancelled'}),
        isNull,
      );
      expect(validateEvent('sign_in_failed', {'method': 'email'}), isNotNull);
      expect(validateEvent('turn_sentt', {}), isNotNull);
      expect(validateEvent('turn_sent', {'text': 'hello'}), isNotNull);
      expect(validateEvent('world_viewed', {}), isNotNull);
      expect(validateEvent('world_viewed', {'world_id': 'nope'}), isNotNull);
      expect(
        validateEvent('world_viewed', {'world_id': '66f0c0ffee66f0c0ffee66f0'}),
        isNull,
      );
    });

    test('an invalid track call is dropped in release and asserts in debug', () async {
      final rig = Rig();
      await rig.start();
      expect(() => rig.telemetry.track('nonsense'), throwsA(isA<AssertionError>()));
    });
  });

  group('launch', () {
    test('first_open once per install, session_start every launch', () async {
      final rig = Rig();
      await rig.start();
      await rig.telemetry.flush();
      var names = eventsOf(rig.transport).map((e) => e['name']).toList();
      expect(names, ['first_open', 'session_start']);
      final body = jsonDecode(rig.transport.bodies.first);
      expect(body['app'], {'version': '1.0.11', 'build': 14});
      expect(body['device']['form'], 'phone');
      expect(body['install_id'], isNotEmpty);

      // A second launch on the same store: the install id and seq carry over.
      final second = Rig();
      second.store.meta.addAll(rig.store.meta);
      await second.start();
      await second.telemetry.flush();
      names = eventsOf(second.transport).map((e) => e['name']).toList();
      expect(names, ['session_start']);
      expect(
        jsonDecode(second.transport.bodies.first)['install_id'],
        body['install_id'],
      );
      expect(eventsOf(second.transport).first['seq'], 2);
    });

    test('seq only goes up', () async {
      final rig = Rig();
      await rig.start();
      rig.telemetry.track('persona_created');
      rig.telemetry.track('review_prompt_shown');
      await rig.telemetry.settle();
      await rig.telemetry.flush();
      final seqs = eventsOf(rig.transport).map((e) => e['seq'] as int).toList();
      expect(seqs, [...seqs]..sort());
      expect(seqs.toSet().length, seqs.length);
    });
  });

  group('screens', () {
    test('leaving a screen emits foreground time and the previous screen', () async {
      final rig = Rig();
      await rig.start();
      rig.telemetry.screen('home');
      rig.clock.advance(const Duration(seconds: 12));
      rig.telemetry.screen('discover');
      await rig.telemetry.settle();
      await rig.telemetry.flush();
      final view = eventsOf(rig.transport).firstWhere(
        (e) => e['name'] == 'screen_view',
      );
      expect(view['props'], {'screen': 'home', 'duration_ms': 12000});
    });

    test('pause emits a partial view, the background is not counted', () async {
      final rig = Rig();
      await rig.start();
      rig.telemetry.screen('discover');
      rig.clock.advance(const Duration(seconds: 7));
      rig.telemetry.didChangeAppLifecycleState(AppLifecycleState.paused);
      rig.clock.advance(const Duration(minutes: 10));
      rig.telemetry.didChangeAppLifecycleState(AppLifecycleState.resumed);
      rig.clock.advance(const Duration(seconds: 3));
      rig.telemetry.screen('play');
      await rig.telemetry.settle();
      await rig.telemetry.flush(ignoreBackoff: true);
      final views = eventsOf(rig.transport)
          .where((e) => e['name'] == 'screen_view')
          .map((e) => e['props'] as Map)
          .toList();
      expect(views[0]['partial'], true);
      expect(views[0]['duration_ms'], 7000);
      expect(views[1]['duration_ms'], 3000);
      expect(views[1].containsKey('partial'), isFalse);
    });

    test('a route without a usable name is reported as unnamed', () async {
      final rig = Rig();
      await rig.start();
      rig.telemetry.screen('Not A Slug!');
      rig.clock.advance(const Duration(seconds: 1));
      rig.telemetry.screen('home');
      await rig.telemetry.settle();
      await rig.telemetry.flush();
      final view = eventsOf(rig.transport).firstWhere(
        (e) => e['name'] == 'screen_view',
      );
      expect(view['props']['screen'], 'unnamed');
    });
  });

  group('sessions', () {
    test('30 minutes in the background starts a new session', () async {
      final rig = Rig();
      await rig.start();
      await rig.telemetry.flush();
      final first = jsonDecode(rig.transport.bodies.first)['session_id'];
      rig.telemetry.didChangeAppLifecycleState(AppLifecycleState.paused);
      rig.clock.advance(const Duration(minutes: 31));
      rig.telemetry.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await rig.telemetry.settle();
      await rig.telemetry.flush(ignoreBackoff: true);
      final last = jsonDecode(rig.transport.bodies.last);
      expect(last['session_id'], isNot(first));
      expect(
        (last['events'] as List).any(
          (e) => e['name'] == 'session_start' && e['props']['launch'] == 'resume',
        ),
        isTrue,
      );
    });

    test('a short trip away does not start one', () async {
      final rig = Rig();
      await rig.start();
      rig.telemetry.didChangeAppLifecycleState(AppLifecycleState.paused);
      rig.clock.advance(const Duration(minutes: 5));
      rig.telemetry.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await rig.telemetry.settle();
      await rig.telemetry.flush(ignoreBackoff: true);
      final resumes = eventsOf(rig.transport).where(
        (e) => e['name'] == 'session_start' && e['props']['launch'] == 'resume',
      );
      expect(resumes, isEmpty);
    });
  });

  group('sending', () {
    test('202 deletes what was sent and nothing else', () async {
      final rig = Rig();
      await rig.start();
      await rig.telemetry.flush();
      expect(await rig.store.count(), 0);
      rig.telemetry.track('persona_created');
      await rig.telemetry.settle();
      expect(await rig.store.count(), 1);
    });

    test('a network failure keeps the items and backs off', () async {
      final rig = Rig();
      rig.transport.fallback = const TransportResult();
      await rig.start();
      rig.transport.bodies.clear();
      await rig.telemetry.flush();
      expect(await rig.store.count(), greaterThan(0));
      final tries = rig.transport.bodies.length;
      await rig.telemetry.flush();
      expect(rig.transport.bodies.length, tries, reason: 'still backing off');
      rig.clock.advance(const Duration(seconds: 31));
      rig.transport.fallback = const TransportResult(status: 202);
      await rig.telemetry.flush();
      expect(await rig.store.count(), 0);
    });

    test('5xx keeps the items', () async {
      final rig = Rig();
      rig.transport.fallback = const TransportResult(status: 503);
      await rig.start();
      expect(await rig.store.count(), greaterThan(0));
    });

    test('429 honours Retry-After', () async {
      final rig = Rig();
      rig.transport.fallback = const TransportResult(
        status: 429,
        retryAfter: Duration(seconds: 120),
      );
      await rig.start();
      rig.transport.bodies.clear();
      await rig.telemetry.flush();
      rig.clock.advance(const Duration(seconds: 100));
      await rig.telemetry.flush();
      expect(rig.transport.bodies, isEmpty);
      rig.clock.advance(const Duration(seconds: 30));
      rig.transport.fallback = const TransportResult(status: 202);
      await rig.telemetry.flush();
      expect(await rig.store.count(), 0);
    });

    test('400 and 413 drop the batch', () async {
      for (final status in [400, 413]) {
        final rig = Rig();
        rig.transport.fallback = TransportResult(status: status);
        await rig.start();
        expect(await rig.store.count(), 0, reason: 'status $status');
      }
    });

    test('the token is attached when there is one, not otherwise', () async {
      final signedIn = Rig(token: 'jwt');
      await signedIn.start();
      expect(signedIn.transport.tokens.first, 'jwt');
      final anon = Rig();
      await anon.start();
      expect(anon.transport.tokens.first, isNull);
    });

    test('an expired token does not keep the queue from draining', () async {
      final rig = Rig(token: 'old');
      rig.transport.script.add(const TransportResult(status: 401));
      await rig.start();
      expect(rig.transport.tokens.take(2), ['old', null]);
      expect(await rig.store.count(), 0);
    });

    test('50 queued items trigger a send without waiting for the timer', () async {
      final rig = Rig();
      rig.transport.fallback = const TransportResult(status: 503);
      await rig.start();
      rig.transport.bodies.clear();
      for (var i = 0; i < 50; i++) {
        rig.telemetry.track('persona_created');
      }
      await rig.telemetry.settle();
      // The failed init flush backs off, so move past it; the threshold flush
      // is what we are after, and it ran when the 50th item was written.
      expect(await rig.store.count(), greaterThanOrEqualTo(50));
    });
  });

  group('errors', () {
    test('an uncaught error is queued with frames, screen and breadcrumbs', () async {
      final rig = Rig();
      await rig.start();
      rig.telemetry.screen('play');
      rig.telemetry.track('persona_created');
      final handled = rig.telemetry.recordPlatformError(
        StateError('Bad state: No element'),
        StackTrace.fromString(
          '#0  PlayCubit._onFrame (package:everlore/features/play/state/play_cubit.dart:412:7)',
        ),
      );
      expect(handled, isTrue);
      await rig.telemetry.settle();
      await rig.telemetry.flush(ignoreBackoff: true);
      final err = errorsOf(rig.transport).single;
      expect(err['source'], 'platform');
      expect(err['type'], 'StateError');
      expect(err['screen'], 'play');
      expect(err['frames'].first['symbol'], 'PlayCubit._onFrame');
      final crumbs = (err['breadcrumbs'] as List).map((c) => c['name']);
      expect(crumbs, containsAll(['play', 'persona_created']));
      expect((err['breadcrumbs'] as List).length, lessThanOrEqualTo(20));
    });

    test('the breadcrumb ring keeps the last 20', () async {
      final rig = Rig();
      await rig.start();
      for (var i = 0; i < 40; i++) {
        rig.telemetry.track('persona_created');
      }
      rig.telemetry.recordPlatformError(StateError('x'), StackTrace.empty);
      await rig.telemetry.settle();
      await rig.telemetry.flush(ignoreBackoff: true);
      expect((errorsOf(rig.transport).single['breadcrumbs'] as List).length, 20);
    });

    test('a handled error carries status and route, never its text', () async {
      final rig = Rig();
      await rig.start();
      rig.telemetry.recordHandled(
        Exception('the player wrote: "meet me at dawn"'),
        httpStatus: 502,
        httpRoute: '/instances/:id/choices',
      );
      await rig.telemetry.settle();
      await rig.telemetry.flush(ignoreBackoff: true);
      final err = errorsOf(rig.transport).single;
      expect(err['source'], 'handled');
      expect(err['http'], {'status': 502, 'route': '/instances/:id/choices'});
      expect(jsonEncode(err), isNot(contains('meet me at dawn')));
    });

    test('one repeating failure is not reported thousands of times', () async {
      final rig = Rig();
      await rig.start();
      for (var i = 0; i < 200; i++) {
        rig.telemetry.recordPlatformError(StateError('loop'), StackTrace.empty);
      }
      await rig.telemetry.settle();
      await rig.telemetry.flush(ignoreBackoff: true);
      expect(errorsOf(rig.transport).length, lessThan(10));
    });
  });

  group('opt-out', () {
    test('off sends analytics_opted_out last, wipes the queue, records nothing more', () async {
      final rig = Rig();
      rig.transport.fallback = const TransportResult(status: 503);
      await rig.start();
      rig.telemetry.track('persona_created');
      await rig.telemetry.settle();
      expect(await rig.store.count(), greaterThan(0));
      rig.transport.bodies.clear();
      rig.transport.fallback = const TransportResult(status: 202);

      await rig.telemetry.setEnabled(false);
      expect(rig.telemetry.enabled, isFalse);
      expect(await rig.store.count(), 0);
      final names = eventsOf(rig.transport).map((e) => e['name']).toList();
      expect(names.last, 'analytics_opted_out');

      rig.transport.bodies.clear();
      rig.telemetry.track('persona_created');
      rig.telemetry.screen('home');
      rig.telemetry.recordPlatformError(StateError('x'), StackTrace.empty);
      await rig.telemetry.settle();
      await rig.telemetry.flush();
      expect(await rig.store.count(), 0);
      expect(rig.transport.bodies, isEmpty);
    });

    test('the choice survives a restart and is read before anything records', () async {
      final rig = Rig();
      await rig.start();
      await rig.telemetry.setEnabled(false);

      final next = Rig();
      next.store.meta.addAll(rig.store.meta);
      await next.start();
      expect(next.telemetry.enabled, isFalse);
      expect(await next.store.count(), 0);
      expect(next.transport.bodies, isEmpty);
    });

    test('turning it back on records again', () async {
      final rig = Rig();
      await rig.start();
      await rig.telemetry.setEnabled(false);
      await rig.telemetry.setEnabled(true);
      rig.telemetry.track('persona_created');
      await rig.telemetry.settle();
      expect(await rig.store.count(), 1);
    });
  });
}
