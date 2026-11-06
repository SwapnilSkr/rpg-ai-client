import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/ws_manager.dart';
import '../../../core/notifications/notification_opener.dart';
import '../../../core/notifications/on_screen.dart';
import '../../../core/storage/secure_storage.dart';
import '../data/notifications_repository.dart';
import '../models/app_notification.dart';
import 'notifications_state.dart';

bool _appInForeground() {
  final s = WidgetsBinding.instance.lifecycleState;
  return s == null || s == AppLifecycleState.resumed;
}

/// The player's notifications, for the whole app: the bell in two headers,
/// the screen, the banner. One instance, above the Navigator.
///
/// Call [load] once a player is signed in and [reset] at sign-out.
class NotificationsCubit extends Cubit<NotificationsState> {
  final NotificationsRepository _repo;
  final NotificationOpener _opener;
  final OnScreen _onScreen;
  final bool Function() _isForeground;
  final DateTime Function() _now;
  final Future<void> Function()? _ensureConnected;

  StreamSubscription<Map<String, dynamic>>? _frameSub;
  StreamSubscription<bool>? _connectionSub;

  Future<void>? _loading;
  Future<void>? _paging;

  /// Bumped by [reset]; an answer that began under an older number belongs to
  /// the previous account and is dropped.
  int _generation = 0;
  int _bannerSeq = 0;

  /// Bumped by every live frame, so a rollback can tell the count it holds
  /// went stale.
  int _frames = 0;

  /// Rows that arrived live while the first page was being read.
  final List<AppNotification> _arrivedWhileLoading = [];

  NotificationsCubit({
    NotificationsRepository repository = const HttpNotificationsRepository(),
    NotificationOpener? opener,
    OnScreen? onScreen,
    Stream<Map<String, dynamic>>? frames,
    Stream<bool>? connection,
    bool Function()? isForeground,
    DateTime Function()? now,
    Future<void> Function()? ensureConnected,
  }) : _repo = repository,
       _opener = opener ?? NotificationOpener.instance,
       _onScreen = onScreen ?? OnScreen.instance,
       _isForeground = isForeground ?? _appInForeground,
       _now = now ?? DateTime.now,
       _ensureConnected = ensureConnected,
       super(const NotificationsState()) {
    _frameSub = (frames ?? WsManager().onNotification).listen(_onFrame);
    // Frames missed while the socket was down are read back on reconnect.
    _connectionSub = (connection ?? WsManager().onConnectionState).listen((up) {
      if (up && state.hasLoaded) unawaited(load());
    });
  }

  /// A socket is only opened by sign-in and by the screens that play, so a
  /// player who opens the app on a stored session would hear nothing live.
  static Future<void> connectStored() async {
    final token = await SecureStore.getToken();
    if (token != null && token.isNotEmpty) await WsManager().connect(token);
  }

  // ── reading ─────────────────────────────────────────────────────────────

  /// Reads the first page again. A call made while one is running joins it.
  Future<void> load() =>
      _loading ??= _load().whenComplete(() => _loading = null);

  Future<void> _load() async {
    final generation = _generation;
    _arrivedWhileLoading.clear();
    emit(state.copyWith(isLoading: true));
    unawaited(_ensureConnected?.call().catchError((_) {}));
    NotificationsPage? page;
    try {
      page = await _repo.page();
    } catch (_) {
      page = null;
    }
    if (isClosed || generation != _generation) return;
    if (page == null) {
      emit(state.copyWith(isLoading: false, hasError: !state.hasLoaded));
      return;
    }
    var items = page.items;
    // A row that arrived live during the read is not in the answer if the
    // server wrote it after answering.
    for (final late in _arrivedWhileLoading) {
      items = _inserted(items, late);
    }
    _arrivedWhileLoading.clear();
    emit(
      state.copyWith(
        items: items,
        unread: page.unread,
        hasLoaded: true,
        isLoading: false,
        hasMore: page.hasMore,
        hasError: false,
      ),
    );
  }

  /// The next, older page: `before` the last row held.
  Future<void> loadMore() {
    if (!state.hasLoaded || !state.hasMore || state.items.isEmpty) {
      return Future.value();
    }
    return _paging ??= _loadMore().whenComplete(() => _paging = null);
  }

  Future<void> _loadMore() async {
    final generation = _generation;
    emit(state.copyWith(isLoadingMore: true));
    NotificationsPage? page;
    try {
      page = await _repo.page(before: state.items.last.id);
    } catch (_) {
      page = null;
    }
    if (isClosed || generation != _generation) return;
    if (page == null) {
      emit(state.copyWith(isLoadingMore: false));
      return;
    }
    final seen = {for (final i in state.items) i.id};
    emit(
      state.copyWith(
        items: [
          ...state.items,
          for (final i in page.items)
            if (seen.add(i.id)) i,
        ],
        // The older rows were read after the first page, so this is the
        // fresher count.
        unread: page.unread,
        isLoadingMore: false,
        hasMore: page.hasMore,
      ),
    );
  }

  /// Forgets everything held for the signed-in account.
  void reset() {
    _generation++;
    _frames = 0;
    _arrivedWhileLoading.clear();
    _loading = null;
    _paging = null;
    if (!isClosed) emit(const NotificationsState());
  }

  // ── live ────────────────────────────────────────────────────────────────

  void _onFrame(Map<String, dynamic> frame) {
    final item = AppNotification.parse(frame['item']);
    if (item == null) return;
    final unread = frame['unread'];
    _frames++;
    if (state.isLoading) _arrivedWhileLoading.add(item);

    NotificationBanner? banner;
    if (item.isUnread && _shouldBanner(item)) {
      banner = NotificationBanner(item, ++_bannerSeq);
    }
    emit(
      state.copyWith(
        items: _inserted(state.items, item),
        unread: unread is num && unread >= 0 ? unread.toInt() : null,
        banner: banner,
      ),
    );
  }

  /// A banner is for an arrival while the app is open, for a kind the app can
  /// open, and not for the place the player is already looking at.
  bool _shouldBanner(AppNotification item) {
    if (!_isForeground() || item.kind == null) return false;
    return !_onScreen.isShowing(NotificationTap.fromItem(item).place);
  }

  /// The banner has left (or was swiped away). Only clears the one named, so
  /// a banner that was already replaced is not cleared by the old one's exit.
  void dismissBanner([int? seq]) {
    final banner = state.banner;
    if (banner == null || (seq != null && banner.seq != seq)) return;
    emit(state.copyWith(clearBanner: true));
  }

  /// Newest first. A row whose id is held is replaced. A story's newer reply
  /// arrives with a new id and the server deletes the older unread one, so
  /// that one goes here too.
  List<AppNotification> _inserted(
    List<AppNotification> items,
    AppNotification item,
  ) {
    final supersedes =
        item.kind == NotificationKind.storyReply && item.isUnread;
    final rest = [
      for (final i in items)
        if (i.id != item.id &&
            !(supersedes &&
                i.kind == NotificationKind.storyReply &&
                i.isUnread &&
                i.instanceId == item.instanceId))
          i,
    ];
    var at = rest.indexWhere((i) => i.createdAt.isBefore(item.createdAt));
    if (at < 0) at = rest.length;
    return [...rest.take(at), item, ...rest.skip(at)];
  }

  // ── reading marks ───────────────────────────────────────────────────────

  /// Marks one row read at once; put back if the server refuses.
  Future<void> markRead(String id) async {
    final held = state.items.where((i) => i.id == id).firstOrNull;
    if (held == null || !held.isUnread) return;
    final generation = _generation;
    final frames = _frames;
    final before = state.unread;
    emit(
      state.copyWith(
        items: _replace(held.asRead(_now())),
        unread: before > 0 ? before - 1 : 0,
      ),
    );
    try {
      final unread = await _repo.markIds([id]);
      if (isClosed || generation != _generation) return;
      emit(state.copyWith(unread: unread));
    } catch (_) {
      if (isClosed || generation != _generation) return;
      final still = state.items.where((i) => i.id == id).firstOrNull;
      emit(
        state.copyWith(
          items: still == null ? null : _replace(held),
          unread: frames == _frames ? before : state.unread,
        ),
      );
    }
  }

  List<AppNotification> _replace(AppNotification item) => [
    for (final i in state.items) i.id == item.id ? item : i,
  ];

  /// Marks everything read at once; put back if the server refuses.
  Future<void> markAllRead() async {
    if (!state.hasUnread && !state.items.any((i) => i.isUnread)) return;
    final generation = _generation;
    final frames = _frames;
    final before = state.unread;
    final wasUnread = {
      for (final i in state.items)
        if (i.isUnread) i.id,
    };
    final at = _now();
    emit(
      state.copyWith(
        items: [for (final i in state.items) i.asRead(at)],
        unread: 0,
      ),
    );
    try {
      final unread = await _repo.markAll();
      if (isClosed || generation != _generation) return;
      emit(state.copyWith(unread: unread));
    } catch (_) {
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          items: [
            for (final i in state.items)
              wasUnread.contains(i.id) ? i.asUnread() : i,
          ],
          unread: frames == _frames ? before : state.unread,
        ),
      );
    }
  }

  /// A film was opened from Keepsakes. Quiet: the player is watching a film,
  /// not managing a list, so a failure is dropped.
  Future<void> filmOpened(String mediaId) async {
    if (mediaId.isEmpty) return;
    final generation = _generation;
    try {
      final unread = await _repo.markMedia(mediaId);
      if (isClosed || generation != _generation) return;
      final at = _now();
      emit(
        state.copyWith(
          items: [
            for (final i in state.items)
              i.mediaId == mediaId ? i.asRead(at) : i,
          ],
          unread: unread,
        ),
      );
    } catch (_) {}
  }

  // ── taps ────────────────────────────────────────────────────────────────

  /// A row or a banner was tapped: mark it read, then go where it points. A
  /// save that is gone has already been explained to the player; its rows go.
  Future<OpenResult> open(AppNotification item) async {
    final banner = state.banner;
    if (banner != null && banner.item.id == item.id) dismissBanner();
    unawaited(markRead(item.id));
    final result = await _opener.open(NotificationTap.fromItem(item));
    if (result == OpenResult.gone && !isClosed) {
      if (item.kind == NotificationKind.filmReady) {
        _remove((i) => i.id == item.id);
      } else {
        removeForSave(item.instanceId);
      }
    }
    return result;
  }

  /// Drops every row about a save the player no longer has.
  void removeForSave(String instanceId) {
    if (instanceId.isEmpty) return;
    _remove((i) => i.instanceId == instanceId);
  }

  void _remove(bool Function(AppNotification) test) {
    final gone = state.items.where(test).toList();
    if (gone.isEmpty) return;
    final goneUnread = gone.where((i) => i.isUnread).length;
    emit(
      state.copyWith(
        items: [
          for (final i in state.items)
            if (!test(i)) i,
        ],
        unread: (state.unread - goneUnread).clamp(0, state.unread),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _frameSub?.cancel();
    await _connectionSub?.cancel();
    return super.close();
  }
}
