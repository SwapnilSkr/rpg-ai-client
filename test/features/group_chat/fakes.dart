import 'dart:async';

import 'package:everlore/features/group_chat/data/group_chat_gateway.dart';
import 'package:everlore/features/group_chat/data/group_chat_repository.dart';
import 'package:everlore/features/group_chat/models/group_chat_models.dart';
import 'package:everlore/features/group_chat/state/group_chat_clock.dart';

/// A clock the test moves by hand. Timers fire in time order as it advances.
class FakeClock implements GroupChatClock {
  DateTime _now = DateTime.utc(2026, 11, 4, 12);
  final List<_Timer> _timers = [];

  @override
  DateTime now() => _now;

  int get pendingTimers => _timers.length;

  @override
  void Function() schedule(Duration delay, void Function() action) {
    final timer = _Timer(_now.add(delay), action);
    _timers.add(timer);
    return () => _timers.remove(timer);
  }

  void advance(Duration by) {
    final target = _now.add(by);
    while (true) {
      _timers.sort((a, b) => a.at.compareTo(b.at));
      final due = _timers.where((t) => !t.at.isAfter(target)).firstOrNull;
      if (due == null) break;
      _timers.remove(due);
      if (due.at.isAfter(_now)) _now = due.at;
      due.action();
    }
    _now = target;
  }
}

class _Timer {
  final DateTime at;
  final void Function() action;
  _Timer(this.at, this.action);
}

/// A socket with no network. Frames are pushed by the test and delivered at
/// once.
class FakeGateway implements GroupChatGateway {
  final _connection = StreamController<bool>.broadcast(sync: true);
  final _loaded = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  final _lines = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  final _ack = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  final _complete = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  final _errors = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  final _selfie = StreamController<Map<String, dynamic>>.broadcast(sync: true);

  bool connected = true;

  /// Everything the cubit asked of the socket, in order.
  final List<Map<String, dynamic>> sent = [];

  @override
  bool get isConnected => connected;
  @override
  Stream<bool> get connectionState => _connection.stream;
  @override
  Stream<Map<String, dynamic>> get instanceLoaded => _loaded.stream;
  @override
  Stream<Map<String, dynamic>> get groupLines => _lines.stream;
  @override
  Stream<Map<String, dynamic>> get ack => _ack.stream;
  @override
  Stream<Map<String, dynamic>> get generationComplete => _complete.stream;
  @override
  Stream<Map<String, dynamic>> get errors => _errors.stream;
  @override
  Stream<Map<String, dynamic>> get selfieFrames => _selfie.stream;

  @override
  Future<void> connect() async {}

  @override
  void loadInstance(String instanceId, {String? directWith}) {
    sent.add({
      'action': 'load_instance',
      'instance_id': instanceId,
      if (directWith != null) 'direct_with': directWith,
    });
  }

  @override
  void sendChat(
    String instanceId,
    String text, {
    String? directWith,
    bool action = false,
  }) {
    sent.add({
      'action': 'chat',
      'instance_id': instanceId,
      'text': text,
      if (directWith != null) 'direct_with': directWith,
      if (action) 'kind': 'action',
    });
  }

  List<Map<String, dynamic>> get chats =>
      [for (final m in sent) if (m['action'] == 'chat') m];
  List<Map<String, dynamic>> get loads =>
      [for (final m in sent) if (m['action'] == 'load_instance') m];

  void setConnected(bool value) {
    connected = value;
    _connection.add(value);
  }

  void pushLoaded(Map<String, dynamic> msg) => _loaded.add(msg);
  void pushLines(Map<String, dynamic> msg) => _lines.add(msg);
  void pushAck(String jobId) => _ack.add({'type': 'ack', 'jobId': jobId});
  void pushComplete(Map<String, dynamic> msg) => _complete.add(msg);
  void pushError(Map<String, dynamic> msg) => _errors.add(msg);
  void pushSelfie(Map<String, dynamic> msg) => _selfie.add(msg);
}

class FakeRepository implements GroupChatRepository {
  List<GroupThreadSummary> threadRows = const [];
  final List<String> opened = [];
  bool openWriting = true;
  Object? openError;
  Completer<bool>? openGate;

  List<GroupBond> bondRows = const [];
  Object? bondsError;
  BondMeters? setResult;
  Object? setError;
  final List<Map<String, int>> setCalls = [];

  final List<GroupActionsPage> actionPages = [];
  final List<int?> actionBefore = [];

  final List<int> rewindCalls = [];
  Object? rewindError;
  Completer<void>? rewindGate;

  /// Answers to selfie requests, in order; a [Completer] holds one open.
  final List<Object> selfieAnswers = [];
  final List<Map<String, String>> selfieCalls = [];

  @override
  Future<GroupSelfie> requestSelfie(
    String instanceId,
    String eventId,
    String characterId,
    String text,
  ) async {
    selfieCalls.add({'event': eventId, 'who': characterId, 'text': text});
    final next = selfieAnswers.removeAt(0);
    if (next is Completer<GroupSelfie>) return next.future;
    if (next is GroupSelfie) return next;
    throw next;
  }

  @override
  Future<void> rewind(String instanceId, int sequence) async {
    rewindCalls.add(sequence);
    if (rewindGate != null) await rewindGate!.future;
    if (rewindError != null) throw rewindError!;
  }

  @override
  Future<List<GroupThreadSummary>> threads(String instanceId) async => threadRows;

  @override
  Future<List<GroupChatRow>> chats() async => const [];

  @override
  Future<bool> openThread(String instanceId, String characterId) async {
    opened.add(characterId);
    if (openError != null) throw openError!;
    if (openGate != null) return openGate!.future;
    return openWriting;
  }

  @override
  Future<List<GroupBond>> bonds(String instanceId) async {
    if (bondsError != null) throw bondsError!;
    return bondRows;
  }

  @override
  Future<BondMeters> setBond(
    String instanceId,
    String characterId,
    Map<String, int> meters,
  ) async {
    setCalls.add(meters);
    if (setError != null) throw setError!;
    return setResult!;
  }

  @override
  Future<GroupActionsPage> actions(
    String instanceId, {
    int? before,
    int limit = 30,
  }) async {
    actionBefore.add(before);
    return actionPages.removeAt(0);
  }
}

const instanceId = 'inst1';
const jess = 'm1';
const tom = 'm2';

/// An `instance_loaded` frame for a group chat. [events] are history rows as
/// the server sends them.
Map<String, dynamic> loadedFrame({
  List<Map<String, dynamic>> events = const [],
  List<String>? pendingFrom,
  String? operation,
  bool matureCapable = false,
  String id = instanceId,
  String? directWith,
}) => {
  'type': 'instance_loaded',
  if (directWith != null) 'directWith': directWith,
  'data': {
    'instance': {
      'id': id,
      'seed_cast_snapshot': [
        {'name': 'Jess'},
        {'name': 'Tom'},
      ],
      if (pendingFrom != null) 'pending_from': pendingFrom,
    },
    'template': {'is_nsfw_capable': matureCapable},
    'characters': [
      {'_id': jess, 'canonical_name': 'Jess', 'role': 'friend'},
      {'_id': tom, 'canonical_name': 'Tom'},
    ],
    'recentEvents': events,
    'eventWindow': {'hasOlder': false, 'total': events.length},
    'operation': operation == null ? null : {'kind': operation},
  },
};

Map<String, dynamic> eventRow({
  required String id,
  required int sequence,
  String playerInput = '',
  bool action = false,
  String? origin,
  List<Map<String, dynamic>> lines = const [],
  DateTime? at,
}) => {
  '_id': id,
  'sequence': sequence,
  'created_at': (at ?? DateTime.utc(2026, 11, 4, 11)).toIso8601String(),
  'data': {
    'player_input': playerInput,
    if (action) 'player_action': true,
    if (origin != null) 'origin': origin,
    'lines': lines,
  },
};

/// A stored line (snake case), as inside a history event or a completion frame.
Map<String, dynamic> storedLine(String who, String text, DateTime at) => {
  'character_id': who,
  'text': text,
  'shown_at': at.toIso8601String(),
};

/// A published line (camel case), as inside `group_lines`.
Map<String, dynamic> wireLine(String who, String text, DateTime at) => {
  'characterId': who,
  'name': who == jess ? 'Jess' : 'Tom',
  'text': text,
  'shownAt': at.toIso8601String(),
};

/// The chats list as a screen outside the tab shell sees it: nothing to read,
/// so the cubit stays quiet and only the marks a screen makes show up.
class FakeChatsRepository implements GroupChatRepository {
  final List<GroupChatRow> rows;
  FakeChatsRepository([this.rows = const []]);

  @override
  Future<List<GroupChatRow>> chats() async => rows;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
