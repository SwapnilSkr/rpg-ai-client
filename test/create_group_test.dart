import 'dart:async';

import 'package:everlore/core/network/api_client.dart';
import 'package:everlore/features/creator/data/creator_repository.dart';
import 'package:everlore/features/group_chat/data/group_create_repository.dart';
import 'package:everlore/features/group_chat/models/group_draft.dart';
import 'package:everlore/features/group_chat/state/create_group_cubit.dart';
import 'package:everlore/features/group_chat/state/create_group_state.dart';
import 'package:everlore/features/group_chat/state/my_groups_cubit.dart';
import 'package:everlore/shared/models/world_template.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:http/http.dart' as http;

Map<String, dynamic> _person(String name, int age) => {
  'name': name,
  'role': 'The regular.',
  'appearance': '$age, lean, short bleached hair.',
  'persona': 'Fiercely competitive and blunt.',
  'mood': 'a key this app has never heard of',
  'identity_kind': 'human',
  'aliases': <String>[],
  'first_texts': ['Ready to get schooled again?', 'Chalk up.', 'Beat my time.'],
  'statuses': {
    'morning': 'Stretching.',
    'afternoon': 'Chalked up.',
    'evening': 'Crushed it. Drinks?',
    'night': 'Sleep.',
  },
  'group': {
    'age': age,
    'talkativeness': 0.8,
    'speech': 'Short, punchy sentences.',
    'wants': 'To push the player.',
    'start_bond': 'rival',
    'intimacy': 'When it is just us, I am not about the games.',
    'voice': ['You almost had that crux!', 'See you at O Beco.', 'Another?'],
    'future_group_key': 7,
  },
};

Map<String, dynamic> _draftJson() => {
  'slug': 'draft-four',
  'title': 'The Climbing Gym',
  'description': 'Four regulars share a bouldering gym.',
  'kind': 'group',
  'is_sentient': false,
  'is_nsfw_capable': true,
  'seed_prompt': 'You arrive at the gym.',
  'global_lore': 'Lisbon climbing is small.',
  'topics': ['Routes.', 'Gossip.'],
  'opening_lines': [
    {'name': 'Ines', 'text': 'Seriously, Tomas?'},
    {'name': 'Tomas', 'text': 'Think before you fling yourself.'},
  ],
  'seed_cast': [_person('Ines', 27), _person('Tomas', 33)],
  'future_top_key': 'kept',
};

Map<String, dynamic> _withoutSlug() => _draftJson()..remove('slug');

/// The authoring view (§6a) of a saved group, optionally with faces.
Map<String, dynamic> _authoring({bool faces = false, String face = 'f1'}) {
  final cast = [_person('Ines', 27), _person('Tomas', 33)];
  if (faces) {
    for (final p in cast) {
      p['portrait_url'] = 'https://cdn/$face/${p['name']}.webp';
      p['portrait_thumb_url'] = 'https://cdn/$face/${p['name']}-t.webp';
    }
  }
  return {
    '_id': 'g1',
    'kind': 'group',
    'title': 'The Climbing Gym',
    'description': 'Four regulars share a bouldering gym.',
    'is_nsfw_capable': true,
    'is_published': false,
    'visibility': 'private',
    'review_status': 'none',
    'image_thumb_url': 'https://cdn/cover-t.webp',
    'seed_prompt': 'You arrive at the gym.',
    'global_lore': 'Lisbon climbing is small.',
    'topics': ['Routes.', 'Gossip.'],
    'opening_lines': [
      {'name': 'Ines', 'text': 'Seriously, Tomas?'},
      {'name': ' Tomas ', 'text': 'Think before you fling yourself.'},
    ],
    'seed_cast': cast,
  };
}

GroupForm _goodForm() => const GroupForm(
  title: 'The Climbing Gym',
  setting: 'A bouldering gym in Lisbon.',
  people: [
    GroupFormPerson(
      name: 'Ines',
      age: 27,
      look: 'Lean, bleached hair.',
      personality: 'Competitive.',
      knowsPlayer: 'Climbs beside you.',
    ),
    GroupFormPerson(
      name: 'Tomas',
      age: 33,
      look: 'Tall, curly hair.',
      personality: 'Gentle.',
      knowsPlayer: 'Sets the routes.',
      closeness: GroupCloseness.friend,
    ),
  ],
);

/// Stands in for the server: records calls, answers from [server].
class _Fake {
  final log = <String>[];
  GroupDraft server = GroupDraft.fromAuthoring(_authoring());
  Completer<void>? holdCreate;
  Object? createError;
  Object? updateError;
  GroupFaceResult faceResult = const GroupFaceResult(GroupFaceOutcome.queued);

  /// Re-reads (after the first) before the face shows up; null: never.
  int? readsBeforeFace;
  int reads = 0;

  int count(String what) => log.where((l) => l == what).length;

  CreateGroupCubit cubit() => CreateGroupCubit(
    draftFn: (form) async {
      log.add('draft');
      return GroupDraft.fromDraft(_withoutSlug());
    },
    createFn: (d) async {
      log.add('create');
      await holdCreate?.future;
      if (createError != null) throw createError!;
      return 'g1';
    },
    updateFn: (id, d) async {
      log.add('update');
      if (updateError != null) throw updateError!;
    },
    loadFn: (id) async {
      log.add('load');
      reads++;
      final at = readsBeforeFace;
      if (at != null && reads > at) {
        return GroupDraft.fromAuthoring(_authoring(faces: true));
      }
      return server;
    },
    faceFn: (id, index, {repaint = false}) async {
      log.add('face');
      return faceResult;
    },
    publishFn: (id, visibility) async => log.add('publish:$visibility'),
    deleteFn: (id) async => log.add('delete'),
  );
}

ApiException _refusal(int status, String message, [Map<String, dynamic>? d]) =>
    ApiException(
      statusCode: status,
      message: message,
      details: {'error': message, ...?d},
    );

void main() {
  group('GroupForm', () {
    test('a good form has no errors and sends the section 3 body', () {
      final form = _goodForm();
      expect(form.validate(), isEmpty);
      final json = form.toJson();
      expect(json['adult'], true);
      expect((json['people'] as List)[1], {
        'name': 'Tomas',
        'age': 33,
        'look': 'Tall, curly hair.',
        'personality': 'Gentle.',
        'knows_player': 'Sets the routes.',
        'closeness': 'friend',
      });
      expect(GroupCloseness.unrequitedAttraction.wire, 'unrequited_attraction');
    });

    test('limits: lengths and ages', () {
      final form = _goodForm().copyWith(
        title: 'x' * 61,
        setting: ' ',
        people: [
          _goodForm().people[0].copyWith(age: 17),
          _goodForm().people[1].copyWith(clearAge: true, look: 'y' * 301),
        ],
      );
      final errors = form.validate();
      expect(errors.keys, {
        'title',
        'setting',
        'people.0.age',
        'people.1.age',
        'people.1.look',
      });
      expect(
        _goodForm()
            .copyWith(
              people: [
                _goodForm().people[0].copyWith(age: 100),
                _goodForm().people[1],
              ],
            )
            .validate()
            .keys,
        ['people.0.age'],
      );
    });

    test('one and seven people are impossible, two and six are fine', () {
      final one = _goodForm().copyWith(people: [_goodForm().people[0]]);
      expect(one.validate().keys, contains('people'));
      final people = [
        for (var i = 0; i < 7; i++)
          _goodForm().people[0].copyWith(name: 'Person $i'),
      ];
      expect(
        _goodForm().copyWith(people: people).validate().keys,
        contains('people'),
      );
      expect(
        _goodForm().copyWith(people: people.sublist(0, 6)).validate(),
        isEmpty,
      );
    });

    test('names must differ ignoring case and surrounding spaces', () {
      final a = _goodForm().people[0];
      final form = _goodForm().copyWith(
        people: [
          a,
          a.copyWith(name: '  INES '),
        ],
      );
      expect(form.validate(), {
        'people.0.name': 'Each person needs a different name.',
        'people.1.name': 'Each person needs a different name.',
      });
    });

    test(
      'the cubit keeps 2 to 6 people and sends nothing when invalid',
      () async {
        final fake = _Fake();
        final cubit = fake.cubit();
        cubit.removePerson(0);
        expect(cubit.state.form.people, hasLength(2));
        for (var i = 0; i < 9; i++) {
          cubit.addPerson();
        }
        expect(cubit.state.form.people, hasLength(6));
        await cubit.draft();
        expect(fake.count('draft'), 0);
        expect(cubit.state.formErrors.keys, contains('title'));
        cubit.updateForm(title: 'Gym');
        expect(cubit.state.formErrors.keys, isNot(contains('title')));
        await cubit.close();
      },
    );
  });

  group('GroupDraft', () {
    test('fromDraft to toSaveBody keeps every key, known and unknown', () {
      final body = GroupDraft.fromDraft(_draftJson()).toSaveBody();
      expect(body, _withoutSlug());
      final person = (body['seed_cast'] as List)[0] as Map;
      expect(person['first_texts'], hasLength(3));
      expect(person['identity_kind'], 'human');
      expect(person['mood'], isNotNull);
      expect((person['group'] as Map)['future_group_key'], 7);
      expect(body['kind'], 'group');
    });

    test(
      'fromAuthoring to toSaveBody is the PUT body: no faces, no read-only',
      () {
        final json = _authoring(faces: true)
          ..['image_url'] = 'https://cdn/c.webp';
        final draft = GroupDraft.fromAuthoring(json);
        expect(draft.id, 'g1');
        expect(draft.cast[0].portraitUrl, 'https://cdn/f1/Ines.webp');
        final body = draft.toSaveBody();
        for (final key in [
          '_id',
          'kind',
          'is_published',
          'visibility',
          'review_status',
          'image_thumb_url',
        ]) {
          expect(body.containsKey(key), isFalse, reason: key);
        }
        expect(body['image_url'], 'https://cdn/c.webp');
        for (final p in body['seed_cast'] as List) {
          expect((p as Map).containsKey('portrait_url'), isFalse);
          expect(p.containsKey('portrait_thumb_url'), isFalse);
          expect(p['statuses'], isNotEmpty);
        }
        expect(
          GroupDraft.fromAuthoring(
            _authoring(),
          ).toSaveBody().containsKey('image_url'),
          isFalse,
        );
      },
    );

    test('renaming a person renames them in the opening lines', () {
      final draft = GroupDraft.fromAuthoring(_authoring());
      final renamed = draft.renamePerson(1, 'Tomás');
      expect(renamed.cast[1].name, 'Tomás');
      expect(renamed.openingLines.map((l) => l.name), ['Ines', 'Tomás']);
      expect(draft.openingLines[1].name, ' Tomas ');
    });
  });

  group('CreateGroupCubit', () {
    test('a second draft() while one is in flight makes no call', () async {
      final gate = Completer<GroupDraft>();
      var calls = 0;
      final cubit = CreateGroupCubit(
        draftFn: (_) {
          calls++;
          return gate.future;
        },
      );
      cubit.updateForm(title: 'a');
      final form = _goodForm();
      cubit.updateForm(title: form.title, setting: form.setting);
      cubit.updatePerson(0, form.people[0]);
      cubit.updatePerson(1, form.people[1]);
      final first = cubit.draft();
      final second = cubit.draft();
      expect(cubit.state.phase, CreateGroupPhase.drafting);
      gate.complete(GroupDraft.fromDraft(_withoutSlug()));
      await Future.wait([first, second]);
      expect(calls, 1);
      expect(cubit.state.phase, CreateGroupPhase.editing);
      expect(cubit.state.draft!.cast, hasLength(2));
      expect(cubit.state.needsSave, isTrue);
      await cubit.close();
    });

    test(
      'a refused draft shows the server message, a 503 the retry line',
      () async {
        final fake = _Fake();
        for (final c in [
          (
            _refusal(422, "We couldn't write this group."),
            "We couldn't write this group.",
          ),
          (_refusal(503, 'upstream down'), 'Try again in a moment.'),
        ]) {
          final cubit = CreateGroupCubit(draftFn: (_) async => throw c.$1);
          final form = _goodForm();
          cubit.updateForm(title: form.title, setting: form.setting);
          cubit.updatePerson(0, form.people[0]);
          cubit.updatePerson(1, form.people[1]);
          await cubit.draft();
          expect(cubit.state.phase, CreateGroupPhase.form);
          expect(cubit.state.error, c.$2);
          await cubit.close();
        }
        expect(fake.log, isEmpty);
      },
    );

    test('a second save() while one is in flight makes one call', () async {
      final fake = _Fake()..holdCreate = Completer<void>();
      final cubit = fake.cubit();
      final form = _goodForm();
      cubit.updateForm(title: form.title, setting: form.setting);
      cubit.updatePerson(0, form.people[0]);
      cubit.updatePerson(1, form.people[1]);
      await cubit.draft();
      final first = cubit.save();
      final second = await cubit.save();
      expect(second, isFalse);
      fake.holdCreate!.complete();
      expect(await first, isTrue);
      expect(fake.count('create'), 1);
      // Saved, then re-read for current faces and URLs.
      expect(fake.log.sublist(fake.log.length - 2), ['create', 'load']);
      expect(cubit.state.draft!.id, 'g1');
      expect(cubit.state.isDirty, isFalse);
      expect(cubit.state.needsSave, isFalse);
      await cubit.close();
    });

    test(
      'a 422 puts its paths in refusedPaths; editing that field clears them',
      () async {
        final fake = _Fake()
          ..updateError = _refusal(422, 'One of these lines cannot be used.', {
            'paths': ['seed_cast.1.group.voice.2', 'seed_cast.0.first_texts.1'],
          });
        final cubit = fake.cubit();
        await cubit.load('g1');
        cubit.setVoiceLine(1, 2, 'a new line');
        expect(await cubit.save(), isFalse);
        expect(cubit.state.error, 'One of these lines cannot be used.');
        expect(cubit.state.refusedPaths, {
          'seed_cast.1.group.voice.2',
          'seed_cast.0.first_texts.1',
        });
        expect(cubit.state.isSaving, isFalse);
        cubit.setVoiceLine(1, 1, 'another line');
        expect(cubit.state.refusedPaths, hasLength(2));
        cubit.setVoiceLine(1, 2, 'fixed');
        expect(cubit.state.refusedPaths, {'seed_cast.0.first_texts.1'});
        cubit.setFirstText(0, 1, 'fixed');
        expect(cubit.state.refusedPaths, isEmpty);

        fake.updateError = _refusal(503, 'down');
        cubit.setTitle('Other');
        expect(await cubit.save(), isFalse);
        expect(cubit.state.error, 'Try again in a moment.');
        await cubit.close();
      },
    );

    test(
      'a save sends the full cast and a person edit changes only that person',
      () async {
        final fake = _Fake();
        final bodies = <Map<String, dynamic>>[];
        final cubit = CreateGroupCubit(
          loadFn: (_) async => fake.server,
          updateFn: (id, d) async => bodies.add(d.toSaveBody()),
        );
        await cubit.load('g1');
        cubit.setPersonWants(0, 'Something else.');
        await cubit.save();
        final cast = bodies.single['seed_cast'] as List;
        expect(cast, hasLength(2));
        expect(((cast[0] as Map)['group'] as Map)['wants'], 'Something else.');
        expect(
          cast[1],
          GroupDraft.fromAuthoring(_authoring()).toSaveBody()['seed_cast'][1],
        );
        await cubit.close();
      },
    );

    test('a stale load for another id is ignored', () async {
      final slow = Completer<GroupDraft>();
      final other = GroupDraft.fromAuthoring(_authoring()..['title'] = 'Other');
      final cubit = CreateGroupCubit(
        loadFn: (id) => id == 'a' ? slow.future : Future.value(other),
      );
      final first = cubit.load('a');
      await cubit.load('b');
      slow.complete(GroupDraft.fromAuthoring(_authoring()));
      await first;
      expect(cubit.state.draft!.title, 'Other');
      await cubit.close();
    });

    test(
      'faceWillReset: true once name or look differs from the saved face',
      () async {
        final fake = _Fake()
          ..server = GroupDraft.fromAuthoring(_authoring(faces: true));
        final cubit = fake.cubit();
        await cubit.load('g1');
        expect(cubit.faceWillReset(0), isFalse);
        cubit.setPersonRole(0, 'Another role');
        expect(cubit.faceWillReset(0), isFalse);
        cubit.setPersonAppearance(0, '28, a new look.');
        expect(cubit.faceWillReset(0), isTrue);
        expect(cubit.faceWillReset(1), isFalse);
        cubit.setPersonName(1, 'Tomás');
        expect(cubit.faceWillReset(1), isTrue);
        expect(cubit.state.hasFace(1), isFalse);
        await cubit.close();
      },
    );
  });

  group('GroupDraft.validate', () {
    GroupDraft base() => GroupDraft.fromAuthoring(_authoring());
    GroupDraft person(
      GroupDraft d,
      int i,
      GroupDraftPerson Function(GroupDraftPerson) f,
    ) => d.withPerson(i, f(d.cast[i]));

    test('a good group has no problems', () {
      expect(base().validate(), isEmpty);
      expect(GroupDraft.fromDraft(_withoutSlug()).validate(), isEmpty);
    });

    final longLine = 'x' * 121;
    final rules = <String, (GroupDraft Function(GroupDraft), String)>{
      'blank title': ((d) => d.copyWith(title: ' '), 'title'),
      'one person': ((d) => d.copyWith(cast: [d.cast[0]]), 'seed_cast'),
      'blank name': ((d) => d.renamePerson(0, ' '), 'seed_cast.0.name'),
      'duplicate name': ((d) => d.renamePerson(1, 'ines'), 'seed_cast.1.name'),
      'colon in name': ((d) => d.renamePerson(0, 'In:es'), 'seed_cast.0.name'),
      'star in name': ((d) => d.renamePerson(0, 'In*es'), 'seed_cast.0.name'),
      'at in name': ((d) => d.renamePerson(0, '@Ines'), 'seed_cast.0.name'),
      'spaced name': ((d) => d.renamePerson(0, 'Ines '), 'seed_cast.0.name'),
      'under 18': (
        (d) => person(d, 1, (p) => p.copyWith(age: 17)),
        'seed_cast.1.group.age',
      ),
      'no speech': (
        (d) => person(d, 0, (p) => p.copyWith(speech: ' ')),
        'seed_cast.0.group.speech',
      ),
      'no wants': (
        (d) => person(d, 0, (p) => p.copyWith(wants: '')),
        'seed_cast.0.group.wants',
      ),
      'no intimacy in an adult group': (
        (d) => person(d, 0, (p) => p.copyWith(intimacy: '')),
        'seed_cast.0.group.intimacy',
      ),
      'no voice in an adult group': (
        (d) => person(d, 0, (p) => p.copyWith(voice: [])),
        'seed_cast.0.group.voice',
      ),
      'nine voice lines': (
        (d) => person(d, 0, (p) => p.copyWith(voice: List.filled(9, 'a'))),
        'seed_cast.0.group.voice',
      ),
      'blank voice line': (
        (d) => person(d, 0, (p) => p.copyWith(voice: ['a', ' '])),
        'seed_cast.0.group.voice.1',
      ),
      'two-line voice line': (
        (d) => person(d, 0, (p) => p.copyWith(voice: ['a\nb'])),
        'seed_cast.0.group.voice.0',
      ),
      'two first texts': (
        (d) => person(d, 0, (p) => p.copyWith(firstTexts: ['a', 'b'])),
        'seed_cast.0.first_texts',
      ),
      'long first text': (
        (d) =>
            person(d, 0, (p) => p.copyWith(firstTexts: ['a', longLine, 'c'])),
        'seed_cast.0.first_texts.1',
      ),
      'missing status': (
        (d) => person(
          d,
          0,
          (p) => p.copyWith(
            statuses: {'morning': 'a', 'afternoon': 'b', 'evening': 'c'},
          ),
        ),
        'seed_cast.0.statuses.night',
      ),
      'broken status': (
        (d) => person(
          d,
          0,
          (p) => p.copyWith(statuses: {...p.statuses, 'night': 'a\nb'}),
        ),
        'seed_cast.0.statuses.night',
      ),
      'no topics': ((d) => d.copyWith(topics: []), 'topics'),
      'blank topic': ((d) => d.copyWith(topics: ['a', '']), 'topics.1'),
      'no opening lines': (
        (d) => d.copyWith(openingLines: []),
        'opening_lines',
      ),
      'stranger speaks': (
        (d) => d.copyWith(
          openingLines: [GroupOpeningLine(name: 'Nobody', text: 'hi')],
        ),
        'opening_lines.0.name',
      ),
      'blank opening text': (
        (d) => d.copyWith(
          openingLines: [GroupOpeningLine(name: 'Ines', text: ' ')],
        ),
        'opening_lines.0.text',
      ),
    };
    rules.forEach((name, rule) {
      test(name, () {
        final errors = rule.$1(base()).validate();
        expect(errors.keys, contains(rule.$2));
        for (final message in errors.values) {
          expect(
            message,
            isNot(
              matches(
                RegExp('first_texts|statuses|prefix|seed_cast|opening_lines'),
              ),
            ),
          );
        }
      });
    });

    test('a non-adult group may leave out intimacy and voice', () {
      final d = base().copyWith(isNsfwCapable: false);
      final plain = d.copyWith(
        cast: [for (final p in d.cast) p.copyWith(intimacy: '', voice: [])],
      );
      expect(plain.validate(), isEmpty);
    });

    test(
      'save with a broken draft sends nothing and names the fields',
      () async {
        final fake = _Fake();
        final cubit = fake.cubit();
        await cubit.load('g1');
        fake.log.clear();
        cubit.setPersonName(0, 'In:es');
        cubit.setStatus(1, 'night', '');
        expect(await cubit.save(), isFalse);
        expect(fake.log, isEmpty);
        expect(cubit.state.error, CreateGroupCubit.checkMessage);
        expect(
          cubit.state.fieldErrors.keys,
          containsAll(['seed_cast.0.name', 'seed_cast.1.statuses.night']),
        );
        cubit.setStatus(1, 'night', 'Asleep.');
        expect(cubit.state.fieldErrors.keys, ['seed_cast.0.name']);
        // Faces and publish save first, so they stop there too.
        cubit.setPersonName(0, 'In:es');
        await cubit.requestFace(0);
        await cubit.publish('private');
        expect(fake.log, isEmpty);
        expect(cubit.state.faceOf(0).status, GroupFaceStatus.idle);
        await cubit.close();
      },
    );

    test(
      'a 400 from the server shows the general copy, never its text',
      () async {
        final fake = _Fake()
          ..updateError = _refusal(
            400,
            'Group: first_texts must contain exactly three lines',
          );
        final cubit = fake.cubit();
        await cubit.load('g1');
        cubit.setTitle('Other');
        expect(await cubit.save(), isFalse);
        expect(
          cubit.state.error,
          "Some lines in this group can't be saved. Check each part and try again.",
        );
        await cubit.close();
      },
    );
  });

  group('faces', () {
    test('queued: re-reads every 4 s until the face appears, then ready', () {
      fakeAsync((async) {
        final fake = _Fake()..readsBeforeFace = 2;
        final cubit = fake.cubit();
        cubit.load('g1');
        async.flushMicrotasks();
        fake.reads = 0;
        cubit.requestFace(0);
        async.flushMicrotasks();
        expect(cubit.state.faceOf(0).status, GroupFaceStatus.painting);
        // A second tap while painting does nothing.
        cubit.requestFace(0);
        async.flushMicrotasks();
        expect(fake.count('face'), 1);
        async.elapse(const Duration(seconds: 4));
        expect(cubit.state.faceOf(0).status, GroupFaceStatus.painting);
        async.elapse(const Duration(seconds: 4));
        expect(cubit.state.faceOf(0).status, GroupFaceStatus.painting);
        async.elapse(const Duration(seconds: 4));
        expect(cubit.state.faceOf(0).status, GroupFaceStatus.ready);
        expect(cubit.state.draft!.cast[0].portraitUrl, contains('Ines'));
        expect(cubit.state.saved!.cast[0].portraitUrl, contains('Ines'));
        expect(cubit.state.isDirty, isFalse);
        cubit.close();
      });
    });

    test('gives up after two minutes with the slow message', () {
      fakeAsync((async) {
        final fake = _Fake();
        final cubit = fake.cubit();
        cubit.load('g1');
        async.flushMicrotasks();
        fake.reads = 0;
        cubit.requestFace(0);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 116));
        expect(cubit.state.faceOf(0).status, GroupFaceStatus.painting);
        async.elapse(const Duration(seconds: 8));
        expect(cubit.state.faceOf(0).status, GroupFaceStatus.idle);
        expect(
          cubit.state.error,
          'This is taking longer than usual. Try again in a while.',
        );
        expect(fake.reads, 30);
        async.elapse(const Duration(minutes: 5));
        expect(fake.reads, 30);
        cubit.close();
      });
    });

    test('a removed or renamed person stops their poll', () {
      fakeAsync((async) {
        final fake = _Fake();
        final cubit = fake.cubit();
        cubit.load('g1');
        async.flushMicrotasks();
        fake.reads = 0;
        cubit.requestFace(0);
        async.flushMicrotasks();
        cubit.setPersonName(0, 'Inès');
        async.elapse(const Duration(seconds: 4));
        expect(cubit.state.faceOf(0).status, GroupFaceStatus.idle);
        expect(fake.reads, 0);
        async.elapse(const Duration(minutes: 3));
        expect(fake.reads, 0);
        cubit.close();
      });
    });

    test('closing mid-poll emits nothing afterwards', () {
      fakeAsync((async) {
        final fake = _Fake();
        final cubit = fake.cubit();
        cubit.load('g1');
        async.flushMicrotasks();
        cubit.requestFace(0);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 4));
        var emitted = 0;
        final sub = cubit.stream.listen((_) => emitted++);
        cubit.close();
        fake.reads = 0;
        async.elapse(const Duration(minutes: 5));
        expect(emitted, 0);
        expect(fake.reads, 0);
        sub.cancel();
      });
    });

    test('dirty: saves first, then asks; a failed save asks nothing', () async {
      final fake = _Fake()
        ..faceResult = const GroupFaceResult(
          GroupFaceOutcome.unseen,
          message: 'This moment stays unseen.',
        );
      final cubit = fake.cubit();
      await cubit.load('g1');
      fake.log.clear();
      cubit.setPersonAppearance(0, '27, a new look.');
      await cubit.requestFace(0);
      expect(fake.log, ['update', 'load', 'face']);
      expect(cubit.state.faceOf(0).status, GroupFaceStatus.unseen);
      expect(cubit.state.faceOf(0).message, 'This moment stays unseen.');

      fake.log.clear();
      fake.updateError = _refusal(503, 'down');
      cubit.setPersonAppearance(1, '33, another look.');
      await cubit.requestFace(1);
      expect(fake.log, ['update']);
      expect(cubit.state.faceOf(1).status, GroupFaceStatus.idle);
      expect(cubit.state.error, 'Try again in a moment.');
      await cubit.close();
    });

    test('a spent allowance is resting, with the server words', () async {
      final fake = _Fake()
        ..faceResult = const GroupFaceResult(
          GroupFaceOutcome.resting,
          message: 'Faces are resting for today.',
        );
      final cubit = fake.cubit();
      await cubit.load('g1');
      await cubit.requestFace(0, repaint: true);
      expect(cubit.state.faceOf(0).status, GroupFaceStatus.resting);
      expect(cubit.state.faceOf(0).message, 'Faces are resting for today.');
      await cubit.close();
    });

    test(
      'the repository tells resting and unseen from other refusals',
      () async {
        // Pure parsing of the refusal bodies the repository maps.
        final resting = _refusal(429, 'Resting.', {
          'status': 'resting',
          'kind': 'portrait',
        });
        final unseen = _refusal(422, 'This moment stays unseen.');
        expect(resting.details?['status'], 'resting');
        expect(unseen.details?['status'], isNull);
        expect(GroupFaceOutcome.values, hasLength(4));
      },
    );
  });

  group('publish and delete', () {
    test(
      'public without every face is refused locally, nothing is sent',
      () async {
        final fake = _Fake();
        final cubit = fake.cubit();
        await cubit.load('g1');
        fake.log.clear();
        expect(await cubit.publish('public'), isFalse);
        expect(fake.log, isEmpty);
        expect(cubit.state.error, CreateGroupCubit.faceMissingMessage);
        await cubit.close();
      },
    );

    test('private needs no faces and saves first when dirty', () async {
      final fake = _Fake();
      final cubit = fake.cubit();
      await cubit.load('g1');
      fake.log.clear();
      cubit.setTitle('Edited');
      expect(await cubit.publish('private'), isTrue);
      expect(fake.log, ['update', 'load', 'publish:private', 'load']);
      await cubit.close();
    });

    test(
      'public with every face goes through; a renamed face does not count',
      () async {
        final fake = _Fake()
          ..server = GroupDraft.fromAuthoring(_authoring(faces: true));
        final cubit = fake.cubit();
        await cubit.load('g1');
        cubit.setPersonName(0, 'Inès');
        expect(await cubit.publish('public'), isFalse);
        cubit.setPersonName(0, 'Ines');
        expect(cubit.state.isDirty, isFalse);
        expect(await cubit.publish('public'), isTrue);
        expect(fake.count('publish:public'), 1);
        await cubit.close();
      },
    );

    test('a server refusal of a public publish shows its message', () async {
      final server = GroupDraft.fromAuthoring(_authoring(faces: true));
      final cubit = CreateGroupCubit(
        loadFn: (_) async => server,
        publishFn: (_, _) async => throw _refusal(
          422,
          'Every person needs a face before this group can be shared.',
        ),
      );
      await cubit.load('g1');
      expect(await cubit.publish('public'), isFalse);
      expect(cubit.state.error, contains('needs a face'));
      expect(cubit.state.isPublishing, isFalse);
      await cubit.close();
    });

    test('delete marks the group deleted', () async {
      final fake = _Fake();
      final cubit = fake.cubit();
      await cubit.load('g1');
      expect(await cubit.delete(), isTrue);
      expect(cubit.state.isDeleted, isTrue);
      expect(fake.count('delete'), 1);
      await cubit.close();
    });
  });

  group('MyGroupsCubit', () {
    WorldTemplate group(String id) =>
        WorldTemplate.fromJson({'_id': id, 'title': 'Group $id'});

    test(
      'loads, pages, reloads on changes, and ignores its own delete',
      () async {
        final notifier = ValueNotifier<int>(0);
        final pages = <int>[];
        final cubit = MyGroupsCubit(
          changesNotifier: notifier,
          fetchPage: ({int page = 1, int limit = 20}) async {
            pages.add(page);
            return CreatorWorldPage(
              worlds: [group('p$page-a'), group('p$page-b')],
              total: 2,
              page: page,
            );
          },
          deleteFn: (id) async => notifier.value++,
        );
        await cubit.load();
        expect(cubit.state.groups.map((g) => g.id), ['p1-a', 'p1-b']);
        expect(cubit.state.hasMore, isFalse);

        notifier.value++;
        await Future<void>.delayed(Duration.zero);
        expect(pages, [1, 1]);

        expect(await cubit.delete('p1-a'), isTrue);
        await Future<void>.delayed(Duration.zero);
        expect(pages, [1, 1]);
        expect(cubit.state.groups.map((g) => g.id), ['p1-b']);
        await cubit.close();
        notifier.value++;
        expect(pages, [1, 1]);
      },
    );

    test('loadMore appends the next page without repeats', () async {
      final cubit = MyGroupsCubit(
        changesNotifier: ValueNotifier<int>(0),
        fetchPage: ({int page = 1, int limit = 20}) async => CreatorWorldPage(
          worlds: page == 1
              ? [for (var i = 0; i < 20; i++) group('a$i')]
              : [group('a19'), group('b')],
          total: 22,
          page: page,
        ),
      );
      await cubit.load();
      expect(cubit.state.hasMore, isTrue);
      await cubit.loadMore();
      expect(cubit.state.groups, hasLength(21));
      expect(cubit.state.hasMore, isFalse);
      await cubit.close();
    });
  });

  group('ApiException.details', () {
    test('is the decoded JSON body of a refusal', () {
      try {
        ApiClient.parseResponse(
          http.Response('{"error":"No.","paths":["seed_cast.2.voice.4"]}', 422),
        );
        fail('should throw');
      } on ApiException catch (e) {
        expect(e.message, 'No.');
        expect(e.details?['paths'], ['seed_cast.2.voice.4']);
      }
    });

    test('is null when the body is not JSON', () {
      try {
        ApiClient.parseResponse(http.Response('<html>Bad gateway</html>', 502));
        fail('should throw');
      } on ApiException catch (e) {
        expect(e.details, isNull);
      }
    });
  });
}
