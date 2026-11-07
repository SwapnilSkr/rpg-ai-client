import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/models/world_template.dart';
import '../../templates/data/template_repository.dart';
import '../data/group_chat_repository.dart';
import '../models/group_chat_models.dart';
import 'chats_read_marks.dart';
import 'chats_state.dart';

/// Loads the group templates a player can still join.
typedef LoadGroupTemplates = Future<List<WorldTemplate>> Function();

Future<List<WorldTemplate>> _publishedGroupTemplates() async {
  final result = await TemplateRepository.listPublished(
    kind: 'group',
    limit: 50,
  );
  return [
    for (final t in result['templates'] as List? ?? const [])
      if (t is WorldTemplate) t,
  ];
}

/// Drives the Chats tab: every conversation with its preview and unread
/// state, and the groups not joined yet.
///
/// Call [refresh] when the tab is selected and when a room closes; call
/// [markOpened] when a conversation is entered.
class ChatsCubit extends Cubit<ChatsState> {
  final GroupChatRepository _repo;
  final ChatsReadMarks _marksStore;
  final LoadGroupTemplates _loadTemplates;
  final DateTime Function() _now;

  Map<String, DateTime>? _marks;
  List<GroupChatRow> _rows = const [];
  List<WorldTemplate> _templates = const [];
  bool _rowsKnown = false;

  /// Conversations opened while the server still listed the member as waiting.
  /// The waiting message is written after the open, so until a refresh no
  /// longer lists the member, the open is what clears the dot.
  final Set<String> _openedPending = {};

  Future<void>? _running;
  bool _again = false;

  /// Bumped by [reset]. A read or an open that started under an older number
  /// belongs to the previous account and must not draw.
  int _generation = 0;

  ChatsCubit({
    GroupChatRepository repository = const HttpGroupChatRepository(),
    ChatsReadMarks marks = const ChatsReadMarks(),
    LoadGroupTemplates? loadTemplates,
    DateTime Function()? now,
  }) : _repo = repository,
       _marksStore = marks,
       _loadTemplates = loadTemplates ?? _publishedGroupTemplates,
       _now = now ?? DateTime.now,
       super(const ChatsState());

  /// Reads the list again. Calls made while one is running join it and cause
  /// exactly one more read after it, so a refresh asked for after a room
  /// closed is never answered with data from before. Only the newest read is
  /// ever drawn.
  Future<void> refresh() {
    final running = _running;
    if (running != null) {
      _again = true;
      return running;
    }
    return _running = _run().whenComplete(() => _running = null);
  }

  Future<void> _run() async {
    emit(state.copyWith(isLoading: true));
    do {
      _again = false;
      await _fetch();
    } while (_again && !isClosed);
    if (!isClosed) emit(state.copyWith(isLoading: false));
  }

  /// Forgets everything held for the signed-in account. Called at sign-out so
  /// the next account never sees these chats; a read still running when this
  /// is called is dropped, not drawn.
  void reset() {
    _generation++;
    _marks = null;
    _rows = const [];
    _templates = const [];
    _rowsKnown = false;
    _openedPending.clear();
    _again = false;
    if (!isClosed) emit(const ChatsState());
  }

  Future<void> _fetch() async {
    final generation = _generation;
    final read = _marks ?? await _marksStore.read();
    if (generation != _generation) return;
    _marks ??= read;
    final templatesFuture = _loadTemplates().then<List<WorldTemplate>?>(
      (t) => t,
      onError: (Object _) => null,
    );
    List<GroupChatRow>? rows;
    try {
      rows = await _repo.chats();
    } catch (_) {
      rows = null;
    }
    final templates = await templatesFuture;
    // A newer read is queued: drawing this one would only flicker. A reset
    // since this read began means it belongs to another account.
    if (isClosed || _again || generation != _generation) return;

    if (templates != null) _templates = templates;
    if (rows != null) {
      _rows = rows;
      _rowsKnown = true;
      _prunePending();
    }
    emit(
      state.copyWith(
        conversations: _conversations(),
        joinable: _joinable(),
        hasLoaded: state.hasLoaded || rows != null,
        hasError: rows == null,
      ),
    );
  }

  /// Marks a conversation as seen now, and redraws at once. The mark is never
  /// older than the newest line already listed, so a line the player has just
  /// read can't come back as unread because the phone's clock runs behind.
  Future<void> markOpened(String instanceId, {String? memberId}) async {
    final key = chatKey(instanceId, memberId);
    final generation = _generation;
    final read = _marks ?? await _marksStore.read();
    if (isClosed || generation != _generation) return;
    final marks = _marks ??= read;
    final listed = state.conversations
        .where((c) => c.key == key)
        .map((c) => c.at)
        .firstOrNull;
    var at = _now();
    if (listed != null && listed.isAfter(at)) at = listed;
    marks[key] = at;
    if (memberId != null && _isPending(instanceId, memberId)) {
      _openedPending.add(key);
    }
    emit(state.copyWith(conversations: _conversations()));
    await _marksStore.write(marks);
  }

  bool _isPending(String instanceId, String memberId) => _rows.any(
    (r) => r.instanceId == instanceId && r.pendingFrom.contains(memberId),
  );

  void _prunePending() {
    _openedPending.removeWhere((key) {
      final parts = key.split('|');
      return !_isPending(parts.first, parts.length > 1 ? parts[1] : '');
    });
  }

  List<WorldTemplate> _joinable() {
    // Until the saves are known, every template would look unjoined.
    if (!_rowsKnown) return const [];
    final joined = {for (final r in _rows) r.templateId};
    return [
      for (final t in _templates)
        if (!joined.contains(t.id)) t,
    ];
  }

  List<ChatConversation> _conversations() {
    final marks = _marks ?? const <String, DateTime>{};

    bool unread(String key, GroupLastLine? last, {bool pending = false}) {
      if (pending && !_openedPending.contains(key)) return true;
      if (last == null || last.isPlayer) return false;
      final mark = marks[key];
      return mark == null || last.at.isAfter(mark);
    }

    final out = <ChatConversation>[];
    for (final row in _rows) {
      out.add(
        ChatConversation(
          instanceId: row.instanceId,
          title: row.title,
          groupTitle: row.title,
          imageUrl: row.imageUrl,
          imageThumbUrl: row.imageThumbUrl,
          faces: row.members,
          last: row.last,
          unread: unread(chatKey(row.instanceId), row.last),
        ),
      );
      final byId = {for (final m in row.members) m.id: m};
      final seen = <String>{};
      // A waiting message has no thread row yet, but still needs a place.
      final threads = [
        ...row.threads,
        for (final id in row.pendingFrom)
          if (!row.threads.any((t) => t.memberId == id))
            GroupThreadRow(memberId: id),
      ];
      for (final thread in threads) {
        final member = byId[thread.memberId];
        if (member == null || !seen.add(member.id)) continue;
        final key = chatKey(row.instanceId, member.id);
        out.add(
          ChatConversation(
            instanceId: row.instanceId,
            memberId: member.id,
            title: member.name,
            groupTitle: row.title,
            imageUrl: row.imageUrl,
            imageThumbUrl: row.imageThumbUrl,
            faces: [member],
            last: thread.last,
            unread: unread(
              key,
              thread.last,
              pending: row.pendingFrom.contains(member.id),
            ),
          ),
        );
      }
    }

    // Newest first; no time sorts last. Dart's sort is not stable, so ties
    // keep the server's order by index.
    final order = {for (var i = 0; i < out.length; i++) out[i]: i};
    out.sort((a, b) {
      final x = a.at, y = b.at;
      if (x != null && y != null) {
        final c = y.compareTo(x);
        if (c != 0) return c;
      } else if (x != null) {
        return -1;
      } else if (y != null) {
        return 1;
      }
      return order[a]!.compareTo(order[b]!);
    });
    return out;
  }
}
