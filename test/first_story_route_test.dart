import 'dart:async';
import 'dart:convert';

import 'package:everlore/core/telemetry/telemetry.dart';
import 'package:everlore/features/home/presentation/realm_entry_flow.dart';
import 'package:everlore/features/templates/data/template_repository.dart';
import 'package:everlore/shared/models/world_instance.dart';
import 'package:everlore/shared/models/world_template.dart';
import 'package:flutter_test/flutter_test.dart';

import 'telemetry/fakes.dart';

const _worldId = '66f0c0ffee66f0c0ffee66f0';

WorldTemplate _template([String id = _worldId]) =>
    WorldTemplate.fromJson({'_id': id, 'title': 'The Starter'});

WorldInstance _instance(String id) => WorldInstance.fromJson({
  '_id': id,
  'template_id': _worldId,
  'player_id': 'p1',
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Rig rig;

  setUp(() async {
    rig = Rig();
    await rig.start();
    Telemetry.replaceInstance(rig.telemetry);
  });

  Future<List<Map<String, dynamic>>> events(String name) async {
    await rig.telemetry.settle();
    await rig.telemetry.flush(ignoreBackoff: true);
    return [
      for (final b in rig.transport.bodies)
        for (final e in jsonDecode(b)['events'] as List)
          if (e['name'] == name) e as Map<String, dynamic>,
    ];
  }

  test('a starter becomes the play route', () async {
    final created = <String>[];
    final route = await resolveFirstStoryRoute(
      loadInstances: () async => [],
      loadStarter: () async => _template(),
      createStory: (id) async {
        created.add(id);
        return _instance('inst1');
      },
    );
    expect(route, '/play/inst1?starter=1');
    expect(created, [_worldId]);
    final started = await events('starter_started');
    expect(started.single['props']['world_id'], _worldId);
  });

  test('no starter goes to Explore', () async {
    final route = await resolveFirstStoryRoute(
      loadInstances: () async => [],
      loadStarter: () async => null,
      createStory: (_) async => fail('must not create'),
    );
    expect(route, '/discover');
    final fb = await events('starter_fallback');
    expect(fb.single['props']['reason'], 'none');
  });

  test('a failing starter lookup goes to Explore', () async {
    final route = await resolveFirstStoryRoute(
      loadInstances: () async => [],
      loadStarter: () async => throw Exception('offline'),
      createStory: (_) async => fail('must not create'),
    );
    expect(route, '/discover');
    final fb = await events('starter_fallback');
    expect(fb.single['props']['reason'], 'error');
  });

  test('a failing create goes to Explore', () async {
    final route = await resolveFirstStoryRoute(
      loadInstances: () async => [],
      loadStarter: () async => _template(),
      createStory: (_) async => throw Exception('server'),
    );
    expect(route, '/discover');
    final fb = await events('starter_fallback');
    expect(fb.single['props']['reason'], 'error');
  });

  test('a player with saves keeps Explore and no story is started', () async {
    var asked = false;
    final route = await resolveFirstStoryRoute(
      loadInstances: () async => [_instance('old')],
      loadStarter: () async {
        asked = true;
        return _template();
      },
      createStory: (_) async => fail('must not create'),
    );
    expect(route, '/discover');
    expect(asked, isFalse);
    final fb = await events('starter_fallback');
    expect(fb.single['props']['reason'], 'has_saves');
  });

  test('a double tap creates one story', () async {
    final gate = Completer<WorldInstance>();
    var creates = 0;
    Future<WorldInstance> create(String id) {
      creates++;
      return gate.future;
    }

    final first = resolveFirstStoryRoute(
      loadInstances: () async => [],
      loadStarter: () async => _template(),
      createStory: create,
    );
    final second = resolveFirstStoryRoute(
      loadInstances: () async => [],
      loadStarter: () async => _template(),
      createStory: create,
    );
    await pumpEventQueue();
    gate.complete(_instance('inst2'));
    expect(await first, '/play/inst2?starter=1');
    expect(await second, '/play/inst2?starter=1');
    expect(creates, 1);
  });

  test('the repository never throws when the starter cannot be fetched', () async {
    expect(
      await TemplateRepository.starter(timeout: const Duration(milliseconds: 200)),
      isNull,
    );
  });
}
