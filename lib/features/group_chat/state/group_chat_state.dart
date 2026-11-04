import 'package:equatable/equatable.dart';

import '../models/group_chat_models.dart';

/// Why something failed, in terms a screen can phrase for itself. No wording
/// lives here: the screen owns every word a player reads.
enum GroupChatError {
  offline,
  busy,
  rateLimited,
  insufficientInk,
  signInRequired,
  resting,
  notFound,
  rejected,
  failed,
}

enum GroupChatLoad { loading, ready, failed }

/// What is on screen for one thread.
class GroupThreadView extends Equatable {
  /// Lines already revealed, oldest first.
  final List<GroupLine> lines;

  /// Who is typing next, or null.
  final String? typingId;

  /// Whether this thread's history has been read at least once.
  final bool loaded;

  const GroupThreadView({
    this.lines = const [],
    this.typingId,
    this.loaded = false,
  });

  GroupThreadView copyWith({
    List<GroupLine>? lines,
    Object? typingId = _keep,
    bool? loaded,
  }) => GroupThreadView(
    lines: lines ?? this.lines,
    typingId: identical(typingId, _keep) ? this.typingId : typingId as String?,
    loaded: loaded ?? this.loaded,
  );

  @override
  List<Object?> get props => [lines, typingId, loaded];
}

const Object _keep = Object();

/// A send that did not go through. The text is kept so the player can edit it
/// back into the composer or send it again.
class FailedSend extends Equatable {
  final String id;
  final String text;
  final String? directWith;
  final bool isAction;
  final GroupChatError error;

  const FailedSend({
    required this.id,
    required this.text,
    this.directWith,
    this.isAction = false,
    required this.error,
  });

  @override
  List<Object?> get props => [id, text, directWith, isAction, error];
}

class GroupChatState extends Equatable {
  final String instanceId;
  final GroupChatLoad load;
  final bool connected;

  final List<GroupMember> members;
  final bool matureCapable;

  /// The group's name, from the template in the room's frames.
  final String title;

  /// The group's cover, from the same frames.
  final String imageUrl;

  /// Members with a message waiting for the player.
  final List<String> pendingFrom;

  /// Thread keys are [kGroupThreadKey] or a member id.
  final Map<String, GroupThreadView> threads;
  final List<GroupThreadSummary> threadSummaries;

  /// The thread on screen, as last told by `selectThread`.
  final String selectedThread;

  /// A reply is being written. One at a time for the whole chat.
  final bool turnInFlight;

  /// Sends waiting behind it.
  final int queuedSends;
  final List<FailedSend> failedSends;

  /// A load that failed; sends report their own errors.
  final GroupChatError? error;

  final List<GroupBond> bonds;
  final bool bondsLoading;
  final GroupChatError? bondsError;

  final List<GroupAction> actions;
  final int? actionsNext;
  final bool actionsLoading;
  final GroupChatError? actionsError;

  const GroupChatState({
    required this.instanceId,
    this.load = GroupChatLoad.loading,
    this.connected = false,
    this.members = const [],
    this.matureCapable = false,
    this.title = '',
    this.imageUrl = '',
    this.pendingFrom = const [],
    this.threads = const {},
    this.threadSummaries = const [],
    this.selectedThread = kGroupThreadKey,
    this.turnInFlight = false,
    this.queuedSends = 0,
    this.failedSends = const [],
    this.error,
    this.bonds = const [],
    this.bondsLoading = false,
    this.bondsError,
    this.actions = const [],
    this.actionsNext,
    this.actionsLoading = false,
    this.actionsError,
  });

  /// The thread for [directWith], or the group thread when null.
  GroupThreadView thread([String? directWith]) =>
      threads[directWith ?? kGroupThreadKey] ?? const GroupThreadView();

  GroupMember? member(String id) {
    for (final m in members) {
      if (m.id == id) return m;
    }
    return null;
  }

  GroupChatState copyWith({
    GroupChatLoad? load,
    bool? connected,
    List<GroupMember>? members,
    bool? matureCapable,
    String? title,
    String? imageUrl,
    List<String>? pendingFrom,
    Map<String, GroupThreadView>? threads,
    List<GroupThreadSummary>? threadSummaries,
    String? selectedThread,
    bool? turnInFlight,
    int? queuedSends,
    List<FailedSend>? failedSends,
    Object? error = _keep,
    List<GroupBond>? bonds,
    bool? bondsLoading,
    Object? bondsError = _keep,
    List<GroupAction>? actions,
    Object? actionsNext = _keep,
    bool? actionsLoading,
    Object? actionsError = _keep,
  }) => GroupChatState(
    instanceId: instanceId,
    load: load ?? this.load,
    connected: connected ?? this.connected,
    members: members ?? this.members,
    matureCapable: matureCapable ?? this.matureCapable,
    title: title ?? this.title,
    imageUrl: imageUrl ?? this.imageUrl,
    pendingFrom: pendingFrom ?? this.pendingFrom,
    threads: threads ?? this.threads,
    threadSummaries: threadSummaries ?? this.threadSummaries,
    selectedThread: selectedThread ?? this.selectedThread,
    turnInFlight: turnInFlight ?? this.turnInFlight,
    queuedSends: queuedSends ?? this.queuedSends,
    failedSends: failedSends ?? this.failedSends,
    error: identical(error, _keep) ? this.error : error as GroupChatError?,
    bonds: bonds ?? this.bonds,
    bondsLoading: bondsLoading ?? this.bondsLoading,
    bondsError: identical(bondsError, _keep)
        ? this.bondsError
        : bondsError as GroupChatError?,
    actions: actions ?? this.actions,
    actionsNext: identical(actionsNext, _keep)
        ? this.actionsNext
        : actionsNext as int?,
    actionsLoading: actionsLoading ?? this.actionsLoading,
    actionsError: identical(actionsError, _keep)
        ? this.actionsError
        : actionsError as GroupChatError?,
  );

  @override
  List<Object?> get props => [
    instanceId,
    load,
    connected,
    members,
    matureCapable,
    title,
    imageUrl,
    pendingFrom,
    threads,
    threadSummaries,
    selectedThread,
    turnInFlight,
    queuedSends,
    failedSends,
    error,
    bonds,
    bondsLoading,
    bondsError,
    actions,
    actionsNext,
    actionsLoading,
    actionsError,
  ];
}
