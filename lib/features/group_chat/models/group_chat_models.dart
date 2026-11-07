import 'package:equatable/equatable.dart';

/// Key of the group thread in every per-thread map. A direct thread is keyed by
/// the member's id, which is never empty.
const String kGroupThreadKey = '';

String _str(Object? v) => v?.toString() ?? '';

DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse(v.toString());

int? _int(Object? v) => v is num ? v.toInt() : int.tryParse(_str(v));

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const {};

List<Map<String, dynamic>> _maps(Object? v) => v is List
    ? [for (final e in v) if (e is Map) Map<String, dynamic>.from(e)]
    : const [];

/// A url string, or null for a missing, null, non-string or blank value.
String? _optUrl(Object? v) {
  if (v is! String) return null;
  final s = v.trim();
  return s.isEmpty ? null : s;
}

/// A person in the chat. Ids are the server's character ids; nothing here is
/// known ahead of time by the app.
class GroupMember extends Equatable {
  final String id;
  final String name;
  final String role;
  final String? portraitUrl;

  /// The small copy of [portraitUrl] for avatars; null when the server sent
  /// none. [portraitUrl] always stays the full picture.
  final String? portraitThumbUrl;

  /// The line under the name, picked by the server for the player's hour;
  /// null when there is none.
  final String? status;

  /// Three things the player could say first in a direct thread; empty when
  /// the card carries none.
  final List<String> firstTexts;

  const GroupMember({
    required this.id,
    required this.name,
    this.role = '',
    this.portraitUrl,
    this.portraitThumbUrl,
    this.status,
    this.firstTexts = const [],
  });

  @override
  List<Object?> get props => [
    id,
    name,
    role,
    portraitUrl,
    portraitThumbUrl,
    status,
    firstTexts,
  ];
}

/// Non-empty strings of a JSON list; anything else is no list.
List<String> parseIdeas(Object? raw) => raw is List
    ? [
        for (final v in raw)
          if (v is String && v.trim().isNotEmpty) v.trim(),
      ]
    : const [];

/// Where a character's picture of themselves stands. Only these six words come
/// from the server; any other is no selfie at all, so a newer server cannot
/// show an older app a state it has no words for.
enum SelfieStatus { queued, processing, ready, unseen, failed, resting }

/// A selfie attached to one saved line.
class GroupSelfie extends Equatable {
  final SelfieStatus status;
  final String? mediaId;

  /// Set once [status] is ready.
  final String? url;

  /// When a resting allowance comes back (UTC, as the server sent it).
  final DateTime? resetsAt;

  const GroupSelfie({
    required this.status,
    this.mediaId,
    this.url,
    this.resetsAt,
  });

  /// [resetsAt] in the player's own time zone, for the screen to word.
  DateTime? get resetsAtLocal => resetsAt?.toLocal();

  bool get isPending =>
      status == SelfieStatus.queued || status == SelfieStatus.processing;

  /// Resting and the allowance has not come back yet at [now]. Without a time
  /// the server is asked, since it knows.
  bool isRestingAt(DateTime now) =>
      status == SelfieStatus.resting &&
      resetsAt != null &&
      now.isBefore(resetsAt!);

  static GroupSelfie? parse(Object? raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    final status = SelfieStatus.values
        .where((s) => s.name == _str(json['status']))
        .firstOrNull;
    if (status == null) return null;
    final media = _str(json['media_id'] ?? json['mediaId']);
    final url = _str(json['url']);
    return GroupSelfie(
      status: status,
      mediaId: media.isEmpty ? null : media,
      url: status == SelfieStatus.ready && url.isNotEmpty ? url : null,
      resetsAt: status == SelfieStatus.resting
          ? _date(json['resets_at'] ?? json['resetsAt'])?.toUtc()
          : null,
    );
  }

  @override
  List<Object?> get props => [status, mediaId, url, resetsAt];
}

const Object _keepSelfie = Object();

/// One message in a thread. A player's line has no [characterId].
class GroupLine extends Equatable {
  /// Stable identity used to show a line exactly once, however many frames
  /// (partial, final, complete, history) carry it.
  final String key;
  final String? characterId;
  final String name;
  final String text;
  final DateTime shownAt;

  /// Set once the server has saved the turn that holds this line.
  final String? eventId;

  /// The saved turn's place in the chat's one timeline (shared by the room and
  /// every direct thread). Rewind needs it. Null until the turn is saved and
  /// its number is known.
  final int? sequence;

  /// The player's line was sent as an action (drawn differently).
  final bool isAction;

  /// A player's line the server has not saved yet: waiting its turn in the
  /// send queue, or sent and being answered.
  final GroupLineStatus status;

  /// The server's stable id for a saved character line. Selfie frames name a
  /// line by it. Null until a frame that carries it arrives.
  final String? lineId;

  /// The picture this character sent with the line, if any.
  final GroupSelfie? selfie;

  const GroupLine({
    required this.key,
    this.characterId,
    this.name = '',
    required this.text,
    required this.shownAt,
    this.eventId,
    this.sequence,
    this.isAction = false,
    this.status = GroupLineStatus.sent,
    this.lineId,
    this.selfie,
  });

  bool get isPlayer => characterId == null;

  /// Identity of a spoken line. The stored time is the same in every frame that
  /// carries the line, so it tells two deliveries of one line apart from two
  /// different lines with the same words.
  static String spokenKey(String characterId, DateTime shownAt, String text) =>
      '$characterId|${shownAt.millisecondsSinceEpoch}|$text';

  GroupLine copyWith({
    String? eventId,
    int? sequence,
    GroupLineStatus? status,
    String? name,
    String? lineId,
    Object? selfie = _keepSelfie,
  }) => GroupLine(
    key: key,
    characterId: characterId,
    name: name ?? this.name,
    text: text,
    shownAt: shownAt,
    eventId: eventId ?? this.eventId,
    sequence: sequence ?? this.sequence,
    isAction: isAction,
    status: status ?? this.status,
    lineId: lineId ?? this.lineId,
    selfie: identical(selfie, _keepSelfie) ? this.selfie : selfie as GroupSelfie?,
  );

  @override
  List<Object?> get props => [
    key,
    characterId,
    name,
    text,
    shownAt,
    eventId,
    sequence,
    isAction,
    status,
    lineId,
    selfie,
  ];
}

enum GroupLineStatus { queued, sending, sent }

/// A line as carried by a frame or a history event. `group_lines` uses camel
/// case and a saved event uses snake case; both are read.
GroupLine? parseSpokenLine(
  Map<String, dynamic> json, {
  String? eventId,
  int? sequence,
}) {
  final characterId = _str(json['characterId'] ?? json['character_id']);
  final text = _str(json['text']);
  final shownAt = _date(json['shownAt'] ?? json['shown_at']);
  if (characterId.isEmpty || text.isEmpty || shownAt == null) return null;
  return GroupLine(
    key: GroupLine.spokenKey(characterId, shownAt, text),
    characterId: characterId,
    name: _str(json['name']),
    text: text,
    shownAt: shownAt,
    eventId: eventId,
    sequence: sequence,
    lineId: _str(json['line_id'] ?? json['lineId']).isEmpty
        ? null
        : _str(json['line_id'] ?? json['lineId']),
    selfie: GroupSelfie.parse(json['selfie']),
  );
}

List<GroupLine> parseSpokenLines(
  Object? raw, {
  String? eventId,
  int? sequence,
}) => [
  for (final json in _maps(raw))
    ?parseSpokenLine(json, eventId: eventId, sequence: sequence),
];

/// One saved turn from a history read.
class GroupHistoryEvent extends Equatable {
  final String id;
  final int sequence;
  final DateTime createdAt;
  final String playerInput;
  final bool playerAction;
  final String origin;
  final List<GroupLine> lines;

  /// What the player could say next; only the newest event of a thread has any.
  final List<String> replyIdeas;

  const GroupHistoryEvent({
    required this.id,
    required this.sequence,
    required this.createdAt,
    this.playerInput = '',
    this.playerAction = false,
    this.origin = 'player',
    this.lines = const [],
    this.replyIdeas = const [],
  });

  static GroupHistoryEvent? parse(Map<String, dynamic> json) {
    final id = _str(json['id'] ?? json['_id']);
    if (id.isEmpty) return null;
    final data = _map(json['data']);
    return GroupHistoryEvent(
      id: id,
      sequence: _int(json['sequence']) ?? 0,
      createdAt: _date(json['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      playerInput: _str(data['player_input'] ?? json['player_input']),
      playerAction: (data['player_action'] ?? json['player_action']) == true,
      origin: _str(data['origin'] ?? json['origin']).isEmpty
          ? 'player'
          : _str(data['origin'] ?? json['origin']),
      lines: parseSpokenLines(
        data['lines'] ?? json['lines'],
        eventId: id,
        sequence: _int(json['sequence']),
      ),
      replyIdeas: parseIdeas(data['reply_ideas'] ?? json['reply_ideas']),
    );
  }

  @override
  List<Object?> get props => [
    id,
    sequence,
    createdAt,
    playerInput,
    playerAction,
    origin,
    lines,
    replyIdeas,
  ];
}

/// What an `instance_loaded` frame says about a group chat, thread by thread.
class GroupSnapshot extends Equatable {
  final String instanceId;
  final List<GroupMember> members;
  final List<GroupHistoryEvent> events;

  /// Characters with a message waiting; absent on the wire means none.
  final List<String> pendingFrom;

  /// Whether the world allows mature writing. The player's own switch is a
  /// profile preference and is not part of this frame.
  final bool matureCapable;

  /// `generation` or `rewind` while the server is busy with this chat.
  final String? operation;
  final bool hasOlder;

  /// The group's name; empty when the frame's template carries none.
  final String title;

  /// The group's cover; empty when the frame's template carries none.
  final String imageUrl;

  const GroupSnapshot({
    required this.instanceId,
    this.title = '',
    this.imageUrl = '',
    this.members = const [],
    this.events = const [],
    this.pendingFrom = const [],
    this.matureCapable = false,
    this.operation,
    this.hasOlder = false,
  });

  static GroupSnapshot? parse(Map<String, dynamic> msg) {
    final data = _map(msg['data']);
    final instance = _map(data['instance']);
    final instanceId = _str(instance['id'] ?? instance['_id']);
    if (instanceId.isEmpty) return null;

    final cards = _maps(data['characters']);
    final cast = _maps(instance['seed_cast_snapshot']);
    GroupMember? memberFrom(Map<String, dynamic> card) {
      final id = _str(card['id'] ?? card['_id']);
      final name = _str(card['canonical_name']);
      if (id.isEmpty || name.isEmpty) return null;
      final portrait = card['portrait_url'] ?? _map(card['portrait'])['url'];
      return GroupMember(
        id: id,
        name: name,
        role: _str(card['role']),
        portraitUrl: portrait == null ? null : _str(portrait),
        portraitThumbUrl: _optUrl(card['portrait_thumb_url']),
        status: _str(card['status']).trim().isEmpty
            ? null
            : _str(card['status']).trim(),
        firstTexts: parseIdeas(card['first_texts']),
      );
    }

    // The save's cast names who is in the chat, in order. Without it every
    // card is a member.
    final members = <GroupMember>[];
    if (cast.isEmpty) {
      for (final card in cards) {
        final m = memberFrom(card);
        if (m != null) members.add(m);
      }
    } else {
      for (final entry in cast) {
        final name = _str(entry['name']).toLowerCase();
        for (final card in cards) {
          if (_str(card['canonical_name']).toLowerCase() != name) continue;
          final m = memberFrom(card);
          if (m != null) members.add(m);
          break;
        }
      }
    }

    final events = [
      for (final json in _maps(data['recentEvents']))
        ?GroupHistoryEvent.parse(json),
    ]..sort((a, b) => a.sequence.compareTo(b.sequence));

    final window = _map(data['eventWindow']);
    final operation = _map(data['operation'])['kind'];
    return GroupSnapshot(
      instanceId: instanceId,
      members: members,
      events: events,
      pendingFrom: [
        for (final id in (instance['pending_from'] as List? ?? const []))
          if (_str(id).isNotEmpty) _str(id),
      ],
      matureCapable: _map(data['template'])['is_nsfw_capable'] == true,
      title: _str(_map(data['template'])['title']),
      imageUrl: _str(_map(data['template'])['image_url']),
      operation: operation == null ? null : _str(operation),
      hasOlder: window['hasOlder'] == true,
    );
  }

  @override
  List<Object?> get props => [
    instanceId,
    members,
    events,
    pendingFrom,
    matureCapable,
    operation,
    hasOlder,
  ];
}

/// One row of `GET /instances/:id/threads`.
class GroupThreadSummary extends Equatable {
  final String memberId;
  final String lastLine;
  final DateTime? lastAt;
  final int messageCount;

  const GroupThreadSummary({
    required this.memberId,
    this.lastLine = '',
    this.lastAt,
    this.messageCount = 0,
  });

  static GroupThreadSummary? parse(Object? raw) {
    final json = _map(raw);
    final id = _str(json['memberId']);
    if (id.isEmpty) return null;
    return GroupThreadSummary(
      memberId: id,
      lastLine: _str(json['lastLine']),
      lastAt: _date(json['lastAt']),
      messageCount: _int(json['messageCount']) ?? 0,
    );
  }

  @override
  List<Object?> get props => [memberId, lastLine, lastAt, messageCount];
}

/// The four meters, 0 to 100.
class BondMeters extends Equatable {
  final int trust;
  final int affection;
  final int fear;
  final int rivalry;

  const BondMeters({
    this.trust = 0,
    this.affection = 0,
    this.fear = 0,
    this.rivalry = 0,
  });

  factory BondMeters.fromJson(Object? raw) {
    final json = _map(raw);
    return BondMeters(
      trust: _int(json['trust']) ?? 0,
      affection: _int(json['affection']) ?? 0,
      fear: _int(json['fear']) ?? 0,
      rivalry: _int(json['rivalry']) ?? 0,
    );
  }

  @override
  List<Object?> get props => [trust, affection, fear, rivalry];
}

/// A recent change to a bond and the words that caused it.
class BondMoment extends Equatable {
  final Map<String, int> deltas;
  final String evidence;
  final DateTime? createdAt;

  const BondMoment({
    this.deltas = const {},
    this.evidence = '',
    this.createdAt,
  });

  factory BondMoment.fromJson(Object? raw) {
    final json = _map(raw);
    return BondMoment(
      deltas: {
        for (final e in _map(json['deltas']).entries)
          if (_int(e.value) != null) e.key: _int(e.value)!,
      },
      evidence: _str(json['evidence']),
      createdAt: _date(json['created_at']),
    );
  }

  @override
  List<Object?> get props => [deltas, evidence, createdAt];
}

class GroupBond extends Equatable {
  final String characterId;
  final String name;
  final BondMeters meters;
  final List<BondMoment> moments;

  const GroupBond({
    required this.characterId,
    this.name = '',
    this.meters = const BondMeters(),
    this.moments = const [],
  });

  static GroupBond? parse(Object? raw) {
    final json = _map(raw);
    final id = _str(json['characterId']);
    if (id.isEmpty) return null;
    return GroupBond(
      characterId: id,
      name: _str(json['name']),
      meters: BondMeters.fromJson(json['meters']),
      moments: [for (final m in _maps(json['moments'])) BondMoment.fromJson(m)],
    );
  }

  GroupBond withMeters(BondMeters value) => GroupBond(
    characterId: characterId,
    name: name,
    meters: value,
    moments: moments,
  );

  @override
  List<Object?> get props => [characterId, name, meters, moments];
}

/// One row of the actions list.
class GroupAction extends Equatable {
  final String eventId;
  final int sequence;
  final String text;
  final DateTime? at;

  const GroupAction({
    required this.eventId,
    required this.sequence,
    this.text = '',
    this.at,
  });

  static GroupAction? parse(Object? raw) {
    final json = _map(raw);
    final id = _str(json['eventId']);
    if (id.isEmpty) return null;
    return GroupAction(
      eventId: id,
      sequence: _int(json['sequence']) ?? 0,
      text: _str(json['text']),
      at: _date(json['at']),
    );
  }

  @override
  List<Object?> get props => [eventId, sequence, text, at];
}

class GroupActionsPage extends Equatable {
  final List<GroupAction> actions;

  /// `before` for the next, older page; null when this is the last.
  final int? next;

  const GroupActionsPage({this.actions = const [], this.next});

  factory GroupActionsPage.parse(Object? raw) {
    final json = _map(raw);
    return GroupActionsPage(
      actions: [
        for (final a in (json['actions'] as List? ?? const []))
          ?GroupAction.parse(a),
      ],
      next: _int(json['next']),
    );
  }

  @override
  List<Object?> get props => [actions, next];
}

/// Who wrote a Chats preview line.
enum GroupLastFrom { member, player }

/// The newest line the player has been shown in a conversation. A player's own
/// line has no [name].
class GroupLastLine extends Equatable {
  final GroupLastFrom from;
  final String name;
  final String text;
  final DateTime at;

  const GroupLastLine({
    required this.from,
    this.name = '',
    required this.text,
    required this.at,
  });

  bool get isPlayer => from == GroupLastFrom.player;

  /// Null when [raw] is absent or has no usable time; a line we cannot place
  /// in time cannot be sorted or marked read, so it counts as no line.
  static GroupLastLine? parse(Object? raw) {
    final json = _map(raw);
    final at = _date(json['at']);
    if (at == null) return null;
    final from = switch (_str(json['from'])) {
      'member' => GroupLastFrom.member,
      'player' => GroupLastFrom.player,
      _ => null,
    };
    if (from == null) return null;
    return GroupLastLine(
      from: from,
      name: _str(json['name']),
      text: _str(json['text']),
      at: at,
    );
  }

  @override
  List<Object?> get props => [from, name, text, at];
}

/// One direct thread in a Chats row. [last] is absent when every shown line
/// is hidden from this player, though [messageCount] is above 0.
class GroupThreadRow extends Equatable {
  final String memberId;
  final GroupLastLine? last;
  final int messageCount;

  const GroupThreadRow({
    required this.memberId,
    this.last,
    this.messageCount = 0,
  });

  static GroupThreadRow? parse(Object? raw) {
    final json = _map(raw);
    final id = _str(json['member_id']);
    if (id.isEmpty) return null;
    return GroupThreadRow(
      memberId: id,
      last: GroupLastLine.parse(json['last']),
      messageCount: _int(json['message_count']) ?? 0,
    );
  }

  @override
  List<Object?> get props => [memberId, last, messageCount];
}

/// One group save as the Chats tab lists it.
class GroupChatRow extends Equatable {
  final String instanceId;
  final String templateId;
  final String title;
  final String? imageUrl;

  /// The small copy of [imageUrl] for list covers; null when none was sent.
  final String? imageThumbUrl;
  final List<GroupMember> members;

  /// The main room's newest shown line; null for a new group, or when every
  /// line so far is hidden from this player.
  final GroupLastLine? last;

  /// Members with a direct message waiting to be opened.
  final List<String> pendingFrom;
  final List<GroupThreadRow> threads;

  const GroupChatRow({
    required this.instanceId,
    required this.templateId,
    this.title = '',
    this.imageUrl,
    this.imageThumbUrl,
    this.members = const [],
    this.last,
    this.pendingFrom = const [],
    this.threads = const [],
  });

  /// Null when the row has no save id: nothing could open it.
  static GroupChatRow? parse(Object? raw) {
    try {
      final json = _map(raw);
      final instanceId = _str(json['instance_id']);
      if (instanceId.isEmpty) return null;
      final image = _str(json['image_url']);
      return GroupChatRow(
        instanceId: instanceId,
        templateId: _str(json['template_id']),
        title: _str(json['title']),
        imageUrl: image.isEmpty ? null : image,
        imageThumbUrl: _optUrl(json['image_thumb_url']),
        members: [
          for (final m in _maps(json['members']))
            if (_str(m['id']).isNotEmpty && _str(m['name']).isNotEmpty)
              GroupMember(
                id: _str(m['id']),
                name: _str(m['name']),
                role: _str(m['role']),
                portraitUrl: _str(m['portrait_url']).isEmpty
                    ? null
                    : _str(m['portrait_url']),
                portraitThumbUrl: _optUrl(m['portrait_thumb_url']),
              ),
        ],
        last: GroupLastLine.parse(json['last']),
        pendingFrom: [
          if (json['pending_from'] is List)
            for (final id in json['pending_from'] as List)
              if (_str(id).isNotEmpty) _str(id),
        ],
        threads: [
          if (json['threads'] is List)
            for (final t in json['threads'] as List) ?GroupThreadRow.parse(t),
        ],
      );
    } catch (_) {
      return null;
    }
  }

  @override
  List<Object?> get props => [
    instanceId,
    templateId,
    title,
    imageUrl,
    imageThumbUrl,
    members,
    last,
    pendingFrom,
    threads,
  ];
}
