import 'dart:convert';

import 'package:everlore/core/auth/auth_service.dart';
import 'package:everlore/core/telemetry/telemetry.dart';
import 'package:everlore/core/telemetry/telemetry_vocabulary.dart';
import 'package:everlore/features/billing/presentation/billing_screen.dart';
import 'package:everlore/features/play/state/play_cubit.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fast_reply_send_test.dart'
    show FakeAudioPlaybackController, FakeMediaRepository, FrameWs;
import 'fakes.dart';

List<Map<String, dynamic>> sent(Rig rig, [String? name]) => [
  for (final b in rig.transport.bodies)
    for (final e in jsonDecode(b)['events'] as List)
      if (name == null || e['name'] == name) e as Map<String, dynamic>,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Every name and value §3.1 lists, spelled out. A typo in the vocabulary
  // would otherwise only show up as a hole in production data.
  group('§3.1 vocabulary', () {
    const sheets = [
      'realm_menu', 'protagonist', 'filters', 'paywall', 'chat_menu',
      'timeline', 'thoughts', 'bond_actions', 'world_actions', 'travel',
      'relationships', 'advance_time', 'create_chooser', 'world_options',
      'story_options', 'keepsake_options', 'report', 'content_actions',
      'persona_editor', 'interests_editor', 'autofill', 'publish',
      'story_intro',
    ];
    final table = <String, Map<String, List<String>>>{
      'turn_sent': {'input': ['typed', 'choice', 'choice_edited', 'continue']},
      'sheet_opened': {'sheet': sheets},
      'paywall_shown': {
        'source': ['ink', 'media', 'profile', 'top_bar', 'story'],
      },
      'story_action': {
        'action': [
          'retry', 'rewind', 'edit_reply', 'replay_reply', 'pick_variant',
          'reset', 'delete', 'travel', 'relationship_set', 'time_advanced',
          'protagonist_set', 'protagonist_reused', 'protagonist_skipped',
          'character_edited', 'character_tracked', 'relation_resolved',
          'milestone_cleared', 'history_loaded', 'voice_played',
        ],
      },
      'story_settings_changed': {
        'setting': [
          'pov', 'mode', 'length', 'voice', 'tone', 'focus', 'persona',
        ],
      },
      'chronicle_tab': {
        'tab': [
          'recap', 'timeline', 'memories', 'calendar', 'places', 'bonds',
          'threads',
        ],
      },
      'chronicle_action': {
        'action': [
          'memory_edited', 'memory_deleted', 'event_edited',
          'timeline_switched',
        ],
      },
      'keepsakes_action': {
        'action': ['filtered', 'mode_changed', 'opened', 'removed'],
        'filter': ['all', 'pictures', 'films', 'faces'],
        'mode': ['feed', 'grid'],
      },
      'library_action': {
        'action': [
          'story_deleted', 'world_deleted', 'world_forge_opened',
          'character_creation_opened',
        ],
        'mode': ['new', 'edit'],
      },
      'creator_action': {
        'action': ['autofill_used', 'character_created', 'world_saved'],
      },
      'report_submitted': {
        'target': ['world', 'message', 'character', 'keepsake', 'other'],
      },
      'account_action': {
        'action': ['signed_out', 'account_deleted', 'interests_updated'],
      },
      'guide_arc': {
        'arc': [
          'arrival', 'chronicle', 'explore_genres', 'home', 'ink', 'keepsakes',
          'my_worlds', 'personas', 'realm', 'scene_settings', 'world_detail',
        ],
        'outcome': ['completed', 'skipped'],
      },
    };

    test('every listed value is accepted', () {
      for (final event in table.entries) {
        for (final prop in event.value.entries) {
          for (final v in prop.value) {
            // Required siblings need a value for the check to reach this one.
            final props = <String, Object?>{
              for (final sibling in event.value.entries)
                sibling.key: sibling.value.first,
              prop.key: v,
            };
            expect(
              validateEvent(event.key, props),
              isNull,
              reason: '${event.key}.${prop.key}=$v',
            );
          }
        }
      }
    });

    test('a value outside the list is refused, and asserts in debug', () async {
      expect(validateEvent('sheet_opened', {'sheet': 'made_up'}), isNotNull);
      expect(validateEvent('story_action', {'action': 'nope'}), isNotNull);
      expect(validateEvent('guide_arc', {'arc': 'home'}), isNotNull);
      expect(validateEvent('account_action', {'action': 'signed_out', 'count': 201}), isNotNull);
      expect(validateEvent('keepsakes_action', {'action': 'filtered', 'filter': 'videos'}), isNotNull);
      final rig = Rig();
      await rig.start();
      expect(
        () => rig.telemetry.track('story_action', {'action': 'nope'}),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('turn_sent input kind', () {
    late Rig rig;
    late FrameWs ws;
    late PlayCubit cubit;

    setUp(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (call) async => null,
          );
      rig = Rig();
      await rig.start();
      Telemetry.replaceInstance(rig.telemetry);
      ws = FrameWs();
      cubit = PlayCubit(
        instanceId: 'inst_cov',
        ws: ws,
        mediaRepo: FakeMediaRepository(),
        audio: FakeAudioPlaybackController(),
        onRefreshInk: () async {},
      );
      ws.connectionCtrl.add(true);
      await pumpEventQueue();
    });

    tearDown(() async {
      await cubit.close();
      ws.dispose();
    });

    Future<List<String>> inputs() async {
      await rig.telemetry.settle();
      await rig.telemetry.flush(ignoreBackoff: true);
      return [for (final e in sent(rig, 'turn_sent')) e['props']['input']];
    }

    Future<void> finishTurn(String job) async {
      ws.push('ack', {'type': 'ack', 'jobId': job});
      ws.push('started', {'instanceId': 'inst_cov', 'jobId': job});
      ws.push('stream_end', {
        'instanceId': 'inst_cov',
        'jobId': job,
        'narrative': 'Prose.',
      });
      ws.push('complete', {
        'instanceId': 'inst_cov',
        'jobId': job,
        'event': {'id': 'ev_$job', 'sequence': 1, 'narrative': 'Prose.'},
      });
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }

    test('typed, then a tapped choice sent unchanged, then an edited one', () async {
      await cubit.sendMessage('I open the door');
      await finishTurn('j1');

      cubit.noteChoiceTapped('*I step inside.*');
      await cubit.sendMessage('*I step inside.*');
      await finishTurn('j2');

      cubit.noteChoiceTapped('*I step inside.*');
      await cubit.sendMessage('*I step inside, slowly.*');
      await finishTurn('j3');

      // The tap is spent by the send above: a later free-typed line is typed.
      await cubit.sendMessage('hello again');
      expect(await inputs(), ['typed', 'choice', 'choice_edited', 'typed']);
    });

    test('travel and a time skip are story actions, only once sent', () async {
      await cubit.travelTo(destination: 'Somewhere', companions: const []);
      await finishTurn('j1');
      await cubit.continueStory(advance: 'day');
      await rig.telemetry.settle();
      await rig.telemetry.flush(ignoreBackoff: true);
      final actions = [
        for (final e in sent(rig, 'story_action')) e['props']['action'],
      ];
      expect(actions, ['travel', 'time_advanced']);
      expect(ws.sends, ['world:travel', 'continue']);
    });

    test('nothing about a choice, place or companion leaves the device', () async {
      const choice = 'I confess everything to Lady Morwenna';
      const place = 'The Sunken Library of Vael';
      const person = 'Captain Aldric Vane';
      const memory = 'She remembers the night the bells fell silent';
      cubit.noteChoiceTapped(choice);
      await cubit.sendMessage('$choice. $memory');
      await finishTurn('j1');
      await cubit.travelTo(destination: place, companions: const [person]);
      await rig.telemetry.settle();
      await rig.telemetry.flush(ignoreBackoff: true);
      final everything = rig.transport.bodies.join('\n');
      expect(everything, contains('choice_edited'));
      for (final text in [choice, place, person, memory, 'Morwenna', 'Vael']) {
        expect(everything, isNot(contains(text)), reason: 'leaked: $text');
      }
    });
  });

  group('paywall source', () {
    test('paywall_shown carries the source the route was opened with', () async {
      final rig = Rig();
      await rig.start();
      Telemetry.replaceInstance(rig.telemetry);
      for (final source in ['ink', 'profile', 'top_bar']) {
        trackPaywallShown(source);
      }
      trackPaywallShown('somewhere_else'); // unknown: sent without a source
      trackPaywallShown(null);
      await rig.telemetry.settle();
      await rig.telemetry.flush(ignoreBackoff: true);
      expect([for (final e in sent(rig, 'paywall_shown')) e['props'] ?? {}], [
        {'source': 'ink'},
        {'source': 'profile'},
        {'source': 'top_bar'},
        {},
        {},
      ]);
    });
  });

  group('new_account', () {
    test('read from the sign-in response; absent means omitted', () {
      expect(AuthService.newAccountFrom({'token': 't', 'new_account': true}), isTrue);
      expect(AuthService.newAccountFrom({'token': 't'}), isFalse);
      expect(AuthService.newAccountFrom({'new_account': 'yes'}), isFalse);
      // Spent once read, so the next sign-in cannot inherit it.
      expect(AuthService.takeNewAccountFlag(), isFalse);
    });

    test('the prop is accepted by the vocabulary', () {
      expect(
        validateEvent('sign_in_completed', {'method': 'google', 'new_account': true}),
        isNull,
      );
    });
  });
}
