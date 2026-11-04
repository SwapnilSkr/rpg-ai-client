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

/// A person in the chat. Ids are the server's character ids; nothing here is
/// known ahead of time by the app.
class GroupMember extends Equatable {
  final String id;
  final String name;
  final String role;
  final String? portraitUrl;

  const GroupMember({
    required this.id,
    required this.name,
    this.role = '',
    this.portraitUrl,
  });

  @override
  List<Object?> get props => [id, name, role, portraitUrl];
}

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

  /// The player's line was sent as an action (drawn differently).
  final bool isAction;

  /// A player's line the server has not saved yet: waiting its turn in the
  /// send queue, or sent and being answered.
  final GroupLineStatus status;

  const GroupLine({
    required this.key,
    this.characterId,
    this.name = '',
    required this.text,
    required this.shownAt,
    this.eventId,
    this.isAction = false,
    this.status = GroupLineStatus.sent,
  });

  bool get isPlayer => characterId == null;

  /// Identity of a spoken line. The stored time is the same in every frame that
  /// carries the line, so it tells two deliveries of one line apart from two
  /// different lines with the same words.
  static String spokenKey(String characterId, DateTime shownAt, String text) =>
      '$characterId|${shownAt.millisecondsSinceEpoch}|$text';

  GroupLine copyWith({
    String? eventId,
    GroupLineStatus? status,
    String? name,
  }) => GroupLine(
    key: key,
    characterId: characterId,
    name: name ?? this.name,
    text: text,
    shownAt: shownAt,
    eventId: eventId ?? this.eventId,
    isAction: isAction,
    status: status ?? this.status,
  );

  @override
  List<Object?> get props => [
    key,
    characterId,
    name,
    text,
    shownAt,
    eventId,
    isAction,
    status,
  ];
}

enum GroupLineStatus { queued, sending, sent }

/// A line as carried by a frame or a history event. `group_lines` uses camel
/// case and a saved event uses snake case; both are read.
GroupLine? parseSpokenLine(Map<String, dynamic> json, {String? eventId}) {
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
  );
}

List<GroupLine> parseSpokenLines(Object? raw, {String? eventId}) => [
  for (final json in _maps(raw))
    ?parseSpokenLine(json, eventId: eventId),
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

  const GroupHistoryEvent({
    required this.id,
    required this.sequence,
    required this.createdAt,
    this.playerInput = '',
    this.playerAction = false,
    this.origin = 'player',
    this.lines = const [],
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
      lines: parseSpokenLines(data['lines'] ?? json['lines'], eventId: id),
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

  const GroupSnapshot({
    required this.instanceId,
    this.title = '',
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
    members,
    last,
    pendingFrom,
    threads,
  ];
}
