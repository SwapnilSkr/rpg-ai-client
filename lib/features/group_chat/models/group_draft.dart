/// What the player types to make a group, and the group the server drafts
/// from it, which the player then reads and edits.
///
/// Two shapes on purpose. [GroupForm] is the short form (contract §3) and is
/// sent once to be drafted. [GroupDraft] is the whole group, every line of it,
/// and is what is saved: it round-trips the server's body so a field the
/// server adds later is never dropped by an edit (§6a).
library;

/// The four authored starting bonds, in plain words for the picker. The model
/// never returns one; the player chooses from these.
enum GroupCloseness {
  acquaintance('acquaintance'),
  friend('friend'),
  unrequitedAttraction('unrequited_attraction'),
  rival('rival');

  const GroupCloseness(this.wire);
  final String wire;

  static GroupCloseness? fromWire(String? wire) {
    for (final value in values) {
      if (value.wire == wire) return value;
    }
    return null;
  }
}

class GroupForm {
  static const minPeople = 2;
  static const maxPeople = 6;
  static const titleMax = 60;
  static const settingMax = 300;

  final String title;
  final String setting;
  final bool adult;
  final List<GroupFormPerson> people;

  const GroupForm({
    this.title = '',
    this.setting = '',
    this.adult = true,
    this.people = const [GroupFormPerson(), GroupFormPerson()],
  });

  GroupForm copyWith({
    String? title,
    String? setting,
    bool? adult,
    List<GroupFormPerson>? people,
  }) => GroupForm(
    title: title ?? this.title,
    setting: setting ?? this.setting,
    adult: adult ?? this.adult,
    people: people ?? this.people,
  );

  /// Exactly the body `POST /templates/group-draft` takes (§3).
  Map<String, dynamic> toJson() => {
    'title': title.trim(),
    'setting': setting.trim(),
    'adult': adult,
    'people': [for (final p in people) p.toJson()],
  };

  /// Field errors keyed by path (`title`, `people.1.age`, ...); empty when the
  /// form may be sent. Messages are written for the player.
  Map<String, String> validate() {
    final errors = <String, String>{};
    _length(errors, 'title', title, titleMax, 'a title');
    _length(errors, 'setting', setting, settingMax, 'where they are');
    if (people.length < minPeople || people.length > maxPeople) {
      errors['people'] = 'A group needs $minPeople to $maxPeople people.';
    }
    final seen = <String, List<int>>{};
    for (var i = 0; i < people.length; i++) {
      final p = people[i];
      final at = 'people.$i';
      _length(errors, '$at.name', p.name, GroupFormPerson.nameMax, 'a name');
      final age = p.age;
      if (age == null || age < 18 || age > 99) {
        errors['$at.age'] = 'Age must be a whole number from 18 to 99.';
      }
      _length(
        errors,
        '$at.look',
        p.look,
        GroupFormPerson.lookMax,
        'how they look',
      );
      _length(
        errors,
        '$at.personality',
        p.personality,
        GroupFormPerson.personalityMax,
        'a personality',
      );
      _length(
        errors,
        '$at.knowsPlayer',
        p.knowsPlayer,
        GroupFormPerson.knowsPlayerMax,
        'how they know you',
      );
      final name = p.name.trim().toLowerCase();
      if (name.isNotEmpty) seen.putIfAbsent(name, () => []).add(i);
    }
    for (final same in seen.values) {
      if (same.length < 2) continue;
      for (final i in same) {
        errors['people.$i.name'] = 'Each person needs a different name.';
      }
    }
    return errors;
  }

  static void _length(
    Map<String, String> errors,
    String path,
    String value,
    int max,
    String what,
  ) {
    final length = value.trim().length;
    if (length == 0) {
      errors[path] = 'Add $what.';
    } else if (length > max) {
      errors[path] = 'Keep this under $max characters.';
    }
  }
}

class GroupFormPerson {
  static const nameMax = 40;
  static const lookMax = 300;
  static const personalityMax = 400;
  static const knowsPlayerMax = 200;

  final String name;

  /// Null until typed; a number field can be empty.
  final int? age;
  final String look;
  final String personality;
  final String knowsPlayer;
  final GroupCloseness closeness;

  const GroupFormPerson({
    this.name = '',
    this.age,
    this.look = '',
    this.personality = '',
    this.knowsPlayer = '',
    this.closeness = GroupCloseness.acquaintance,
  });

  GroupFormPerson copyWith({
    String? name,
    int? age,
    bool clearAge = false,
    String? look,
    String? personality,
    String? knowsPlayer,
    GroupCloseness? closeness,
  }) => GroupFormPerson(
    name: name ?? this.name,
    age: clearAge ? null : (age ?? this.age),
    look: look ?? this.look,
    personality: personality ?? this.personality,
    knowsPlayer: knowsPlayer ?? this.knowsPlayer,
    closeness: closeness ?? this.closeness,
  );

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'age': age,
    'look': look.trim(),
    'personality': personality.trim(),
    'knows_player': knowsPlayer.trim(),
    'closeness': closeness.wire,
  };
}

/// One line of the opening conversation: who says it, and what.
class GroupOpeningLine {
  final String name;
  final String text;
  final Map<String, dynamic> extra;

  const GroupOpeningLine({
    required this.name,
    required this.text,
    this.extra = const {},
  });

  factory GroupOpeningLine.fromJson(Map<String, dynamic> json) =>
      GroupOpeningLine(
        name: _str(json['name']),
        text: _str(json['text']),
        extra: _without(json, const {'name', 'text'}),
      );

  GroupOpeningLine copyWith({String? name, String? text}) => GroupOpeningLine(
    name: name ?? this.name,
    text: text ?? this.text,
    extra: extra,
  );

  Map<String, dynamic> toJson() => {...extra, 'name': name, 'text': text};
}

/// One person of a drafted group. Everything the server wrote is typed here;
/// any key it sent that this class does not know stays in [extra] (person) or
/// [groupExtra] (inside `group`) and goes back unchanged on save.
class GroupDraftPerson {
  static const _personKeys = {
    'name',
    'role',
    'appearance',
    'persona',
    'identity_kind',
    'aliases',
    'first_texts',
    'statuses',
    'group',
    // Read only: the face is the server's, set by the portrait route.
    'portrait_url',
    'portrait_thumb_url',
    'portrait',
    'asset_key',
    'thumb_key',
  };
  static const _groupKeys = {
    'age',
    'talkativeness',
    'speech',
    'wants',
    'start_bond',
    'intimacy',
    'voice',
  };
  static const periods = ['morning', 'afternoon', 'evening', 'night'];

  final String name;
  final String role;
  final String appearance;
  final String persona;
  final String identityKind;
  final List<String> aliases;
  final List<String> firstTexts;
  final Map<String, String> statuses;
  final int age;
  final double talkativeness;
  final String speech;
  final String wants;

  /// The wire value of a [GroupCloseness] (kept as the server wrote it).
  final String startBond;
  final String intimacy;
  final List<String> voice;

  /// Read only. Never sent back.
  final String portraitUrl;
  final String portraitThumbUrl;

  final Map<String, dynamic> extra;
  final Map<String, dynamic> groupExtra;

  const GroupDraftPerson({
    this.name = '',
    this.role = '',
    this.appearance = '',
    this.persona = '',
    this.identityKind = '',
    this.aliases = const [],
    this.firstTexts = const [],
    this.statuses = const {},
    this.age = 0,
    this.talkativeness = 0.5,
    this.speech = '',
    this.wants = '',
    this.startBond = '',
    this.intimacy = '',
    this.voice = const [],
    this.portraitUrl = '',
    this.portraitThumbUrl = '',
    this.extra = const {},
    this.groupExtra = const {},
  });

  factory GroupDraftPerson.fromJson(Map<String, dynamic> json) {
    final raw = json['group'];
    final group = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final statuses = json['statuses'];
    return GroupDraftPerson(
      name: _str(json['name']),
      role: _str(json['role']),
      appearance: _str(json['appearance']),
      persona: _str(json['persona']),
      identityKind: _str(json['identity_kind']),
      aliases: _strings(json['aliases']),
      firstTexts: _strings(json['first_texts']),
      statuses: statuses is Map
          ? {
              for (final e in statuses.entries)
                if (e.value is String) e.key.toString(): e.value as String,
            }
          : const {},
      age: (group['age'] as num?)?.toInt() ?? 0,
      talkativeness: (group['talkativeness'] as num?)?.toDouble() ?? 0.5,
      speech: _str(group['speech']),
      wants: _str(group['wants']),
      startBond: _str(group['start_bond']),
      intimacy: _str(group['intimacy']),
      voice: _strings(group['voice']),
      portraitUrl: _str(json['portrait_url']),
      portraitThumbUrl: _str(json['portrait_thumb_url']),
      extra: _without(json, _personKeys),
      groupExtra: _without(group, _groupKeys),
    );
  }

  GroupDraftPerson copyWith({
    String? name,
    String? role,
    String? appearance,
    String? persona,
    List<String>? firstTexts,
    Map<String, String>? statuses,
    int? age,
    double? talkativeness,
    String? speech,
    String? wants,
    String? startBond,
    String? intimacy,
    List<String>? voice,
    String? portraitUrl,
    String? portraitThumbUrl,
  }) => GroupDraftPerson(
    name: name ?? this.name,
    role: role ?? this.role,
    appearance: appearance ?? this.appearance,
    persona: persona ?? this.persona,
    identityKind: identityKind,
    aliases: aliases,
    firstTexts: firstTexts ?? this.firstTexts,
    statuses: statuses ?? this.statuses,
    age: age ?? this.age,
    talkativeness: talkativeness ?? this.talkativeness,
    speech: speech ?? this.speech,
    wants: wants ?? this.wants,
    startBond: startBond ?? this.startBond,
    intimacy: intimacy ?? this.intimacy,
    voice: voice ?? this.voice,
    portraitUrl: portraitUrl ?? this.portraitUrl,
    portraitThumbUrl: portraitThumbUrl ?? this.portraitThumbUrl,
    extra: extra,
    groupExtra: groupExtra,
  );

  /// The person as the PUT body carries them: no face, and an optional field
  /// the server never sent is left out rather than sent empty.
  Map<String, dynamic> toJson() => {
    ...extra,
    'name': name,
    'role': role,
    'appearance': appearance,
    'persona': persona,
    if (identityKind.isNotEmpty) 'identity_kind': identityKind,
    'aliases': aliases,
    if (firstTexts.isNotEmpty) 'first_texts': firstTexts,
    if (statuses.isNotEmpty) 'statuses': statuses,
    'group': {
      ...groupExtra,
      'age': age,
      'talkativeness': talkativeness,
      if (speech.isNotEmpty) 'speech': speech,
      if (wants.isNotEmpty) 'wants': wants,
      if (startBond.isNotEmpty) 'start_bond': startBond,
      if (intimacy.isNotEmpty) 'intimacy': intimacy,
      'voice': voice,
    },
  };
}

/// An editable group: a fresh draft from the server, or a saved group read
/// back for editing.
class GroupDraft {
  static const _groupKeys = {
    'title',
    'description',
    'is_nsfw_capable',
    'image_url',
    'seed_prompt',
    'global_lore',
    'topics',
    'opening_lines',
    'seed_cast',
    // The draft's slug is dropped; the server mints it on save.
    'slug',
    // Read only (the authoring view's own keys).
    '_id',
    'id',
    'kind',
    'is_published',
    'visibility',
    'review_status',
    'image_thumb_url',
  };

  /// Null until the group is saved.
  final String? id;
  final String title;
  final String description;
  final bool isNsfwCapable;
  final String imageUrl;
  final String seedPrompt;
  final String globalLore;
  final List<String> topics;
  final List<GroupOpeningLine> openingLines;
  final List<GroupDraftPerson> cast;

  // Read only, set when loaded from the server.
  final bool isPublished;
  final String visibility;
  final String reviewStatus;
  final String imageThumbUrl;

  /// Keys the server sent that this class does not know, kept for the save.
  /// A fresh draft keeps `kind` and `is_sentient` here, so it can go to
  /// `POST /templates` unchanged.
  final Map<String, dynamic> extra;

  const GroupDraft({
    this.id,
    this.title = '',
    this.description = '',
    this.isNsfwCapable = true,
    this.imageUrl = '',
    this.seedPrompt = '',
    this.globalLore = '',
    this.topics = const [],
    this.openingLines = const [],
    this.cast = const [],
    this.isPublished = false,
    this.visibility = '',
    this.reviewStatus = '',
    this.imageThumbUrl = '',
    this.extra = const {},
  });

  /// The `draft` of `POST /templates/group-draft`.
  factory GroupDraft.fromDraft(Map<String, dynamic> json) =>
      GroupDraft._parse(json, keepKind: true);

  /// The view of `GET /templates/:id/authoring` (§6a).
  factory GroupDraft.fromAuthoring(Map<String, dynamic> json) =>
      GroupDraft._parse(json, keepKind: false);

  factory GroupDraft._parse(
    Map<String, dynamic> json, {
    required bool keepKind,
  }) {
    final extra = _without(json, _groupKeys);
    if (keepKind && json.containsKey('kind')) extra['kind'] = json['kind'];
    return GroupDraft(
      id: _idOf(json),
      title: _str(json['title']),
      description: _str(json['description']),
      isNsfwCapable: json['is_nsfw_capable'] != false,
      imageUrl: _str(json['image_url']),
      seedPrompt: _str(json['seed_prompt']),
      globalLore: _str(json['global_lore']),
      topics: _strings(json['topics']),
      openingLines: [
        for (final e in _maps(json['opening_lines']))
          GroupOpeningLine.fromJson(e),
      ],
      cast: [
        for (final e in _maps(json['seed_cast'])) GroupDraftPerson.fromJson(e),
      ],
      isPublished: json['is_published'] == true,
      visibility: _str(json['visibility']),
      reviewStatus: _str(json['review_status']),
      imageThumbUrl: _str(json['image_thumb_url']),
      extra: extra,
    );
  }

  GroupDraft copyWith({
    String? id,
    String? title,
    String? description,
    bool? isNsfwCapable,
    String? seedPrompt,
    String? globalLore,
    List<String>? topics,
    List<GroupOpeningLine>? openingLines,
    List<GroupDraftPerson>? cast,
  }) => GroupDraft(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    isNsfwCapable: isNsfwCapable ?? this.isNsfwCapable,
    imageUrl: imageUrl,
    seedPrompt: seedPrompt ?? this.seedPrompt,
    globalLore: globalLore ?? this.globalLore,
    topics: topics ?? this.topics,
    openingLines: openingLines ?? this.openingLines,
    cast: cast ?? this.cast,
    isPublished: isPublished,
    visibility: visibility,
    reviewStatus: reviewStatus,
    imageThumbUrl: imageThumbUrl,
    extra: extra,
  );

  GroupDraft withPerson(int index, GroupDraftPerson person) => copyWith(
    cast: [for (var i = 0; i < cast.length; i++) i == index ? person : cast[i]],
  );

  /// Renames a person and, in every opening line they speak, the speaker, so
  /// the conversation still names someone in the group. A line matches when
  /// its speaker equals the old name after trimming.
  GroupDraft renamePerson(int index, String name) {
    final old = cast[index].name.trim();
    return copyWith(
      cast: [
        for (var i = 0; i < cast.length; i++)
          i == index ? cast[i].copyWith(name: name) : cast[i],
      ],
      openingLines: old.isEmpty
          ? null
          : [
              for (final line in openingLines)
                line.name.trim() == old ? line.copyWith(name: name) : line,
            ],
    );
  }

  /// Takes the faces from a fresh read, for each person who is still the same
  /// person (same name). Nothing else changes, so edits in flight survive.
  GroupDraft withFacesFrom(GroupDraft fresh) => copyWith(
    cast: [
      for (var i = 0; i < cast.length; i++)
        if (i < fresh.cast.length &&
            fresh.cast[i].name.trim() == cast[i].name.trim())
          cast[i].copyWith(
            portraitUrl: fresh.cast[i].portraitUrl,
            portraitThumbUrl: fresh.cast[i].portraitThumbUrl,
          )
        else
          cast[i],
    ],
  );

  /// What stops this group saving, as the server's structure check would
  /// find it, keyed by the paths the text gate uses (`title`, `topics.3`,
  /// `opening_lines.1.name`, `seed_cast.2.group.voice.4`,
  /// `seed_cast.2.first_texts.1`, `seed_cast.2.statuses.night`, ...). Empty
  /// means it may be sent. Messages are written for the player.
  Map<String, String> validate() {
    final errors = <String, String>{};
    const addText = 'Add something here.';
    const oneLine = 'Keep this to one line of 120 characters or fewer.';

    // A written line: present, one line, at most 120 characters.
    void written(String path, String? value) {
      if (value == null || value.trim().isEmpty) {
        errors[path] = addText;
      } else if (value.contains(RegExp(r'[\r\n]')) ||
          value.runes.length > 120) {
        errors[path] = oneLine;
      }
    }

    void text(String path, String? value) {
      if (value == null || value.trim().isEmpty) errors[path] = addText;
    }

    if (title.trim().isEmpty) errors['title'] = 'Add a title.';
    if (cast.length < 2 || cast.length > 6) {
      errors['seed_cast'] = 'A group needs 2 to 6 people.';
    }
    final names = <String, int>{};
    for (var i = 0; i < cast.length; i++) {
      final p = cast[i];
      final at = 'seed_cast.$i';
      final key = p.name.trim().toLowerCase();
      if (key.isEmpty) {
        errors['$at.name'] = 'Add a name.';
      } else if (names.containsKey(key)) {
        errors['$at.name'] = 'Each person needs a different name.';
        errors['seed_cast.${names[key]}.name'] =
            'Each person needs a different name.';
      } else {
        names[key] = i;
      }
      if (key.isNotEmpty &&
          (p.name != p.name.trim() || p.name.contains(RegExp(r'[:\r\n*@]')))) {
        errors['$at.name'] =
            "Names can't contain : * or @, or start or end with a space.";
      }
      if (p.age < 18) errors['$at.group.age'] = 'Age must be 18 or over.';
      text('$at.group.speech', p.speech);
      text('$at.group.wants', p.wants);
      if (isNsfwCapable || p.intimacy.isNotEmpty) {
        text('$at.group.intimacy', p.intimacy);
      }
      if (isNsfwCapable || p.voice.isNotEmpty) {
        if (p.voice.isEmpty) {
          errors['$at.group.voice'] = 'Add at least one line.';
        } else if (p.voice.length > 8) {
          errors['$at.group.voice'] = 'Keep this to 8 lines or fewer.';
        }
        for (var j = 0; j < p.voice.length; j++) {
          final line = p.voice[j];
          if (line.trim().isEmpty) {
            errors['$at.group.voice.$j'] = addText;
          } else if (line.contains(RegExp(r'[\r\n]'))) {
            errors['$at.group.voice.$j'] = 'Keep this to one line.';
          }
        }
      }
      if (p.firstTexts.isNotEmpty) {
        if (p.firstTexts.length != 3) {
          errors['$at.first_texts'] =
              'Each person needs exactly 3 first messages.';
        }
        for (var j = 0; j < p.firstTexts.length; j++) {
          written('$at.first_texts.$j', p.firstTexts[j]);
        }
      }
      if (p.statuses.isNotEmpty) {
        for (final period in GroupDraftPerson.periods) {
          written('$at.statuses.$period', p.statuses[period]);
        }
      }
    }
    if (topics.isEmpty) errors['topics'] = 'Add at least one topic.';
    for (var i = 0; i < topics.length; i++) {
      text('topics.$i', topics[i]);
    }
    if (openingLines.isEmpty) {
      errors['opening_lines'] = 'Add at least one opening line.';
    }
    for (var i = 0; i < openingLines.length; i++) {
      final line = openingLines[i];
      if (!names.containsKey(line.name.trim().toLowerCase())) {
        errors['opening_lines.$i.name'] =
            'This line has to name someone in the group.';
      }
      text('opening_lines.$i.text', line.text);
    }
    return errors;
  }

  /// The body `PUT /templates/:id` takes (§6a), and, with [extra], the body of
  /// `POST /templates`: the full cast, no faces, `image_url` only when set.
  Map<String, dynamic> toSaveBody() => {
    ...extra,
    'title': title,
    'description': description,
    'is_nsfw_capable': isNsfwCapable,
    if (imageUrl.isNotEmpty) 'image_url': imageUrl,
    'seed_prompt': seedPrompt,
    'global_lore': globalLore,
    'topics': topics,
    'opening_lines': [for (final l in openingLines) l.toJson()],
    'seed_cast': [for (final p in cast) p.toJson()],
  };
}

String _str(Object? v) => v is String ? v : '';

List<String> _strings(Object? v) => v is List
    ? [
        for (final e in v)
          if (e is String) e,
      ]
    : <String>[];

List<Map<String, dynamic>> _maps(Object? v) => v is List
    ? [
        for (final e in v)
          if (e is Map) Map<String, dynamic>.from(e),
      ]
    : <Map<String, dynamic>>[];

Map<String, dynamic> _without(Map<String, dynamic> json, Set<String> keys) => {
  for (final e in json.entries)
    if (!keys.contains(e.key)) e.key: e.value,
};

String? _idOf(Map<String, dynamic> json) {
  final id = json['_id'] ?? json['id'];
  return id is String && id.isNotEmpty ? id : null;
}
