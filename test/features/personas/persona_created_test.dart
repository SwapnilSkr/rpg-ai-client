import 'dart:convert';

import 'package:everlore/core/telemetry/telemetry_vocabulary.dart';
import 'package:everlore/core/telemetry/telemetry.dart';
import 'package:everlore/features/personas/data/persona_repository.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../telemetry/fakes.dart';

List<Map<String, dynamic>> _events(FakeTransport t) => [
  for (final b in t.bodies)
    for (final e in jsonDecode(b)['events'] as List) e as Map<String, dynamic>,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persona_created is one event per creation, with its entry point', () async {
    FlutterSecureStorage.setMockInitialValues({});
    dotenv.loadFromString(envString: 'API_BASE_URL=http://api.test');
    final rig = Rig();
    await rig.start();
    Telemetry.replaceInstance(rig.telemetry);

    await http.runWithClient(() async {
      Future<void> create(String? from) => PersonaRepository.create(
        name: 'Mira',
        gender: 'female',
        entryPoint: from,
      );
      await create('story_start');
      await create('create_menu');
      await create(null);
    }, () => MockClient((_) async => http.Response(
      jsonEncode({
        'persona': {'id': 'p1', 'name': 'Mira', 'gender': 'female'},
      }),
      200,
    )));

    await rig.telemetry.settle();
    await rig.telemetry.flush();
    final made = _events(rig.transport)
        .where((e) => e['name'] == 'persona_created')
        .toList();
    expect(made.length, 3, reason: 'one event per creation, never two');
    expect(made[0]['props'], {'entry_point': 'story_start'});
    expect(made[1]['props'], {'entry_point': 'create_menu'});
    expect(made[2].containsKey('props'), isFalse);
  });

  test('the entry point is optional and limited to the closed list', () {
    expect(validateEvent('persona_created', {}), isNull);
    for (final from in personaEntryPoints) {
      expect(validateEvent('persona_created', {'entry_point': from}), isNull);
    }
    expect(
      validateEvent('persona_created', {'entry_point': 'somewhere_else'}),
      isNotNull,
    );
  });
}
