import 'package:equatable/equatable.dart';

import '../../../shared/models/world_template.dart';
import '../models/group_chat_models.dart';
import 'chats_read_marks.dart';

/// One row of the Chats tab: a group's room, or one direct thread in it.
class ChatConversation extends Equatable {
  final String instanceId;

  /// Null for the group's room; the member's id for a direct thread.
  final String? memberId;

  /// The group's name for a room, the member's name for a direct thread.
  final String title;

  /// The group's name, for both kinds (a thread can show it as a subtitle).
  final String groupTitle;

  /// The group's cover, or null.
  final String? imageUrl;

  /// A room shows every member; a direct thread shows its one member.
  final List<GroupMember> faces;

  /// Null when nothing is shown yet, or every line is hidden from this player.
  /// No preview text then.
  final GroupLastLine? last;
  final bool unread;

  const ChatConversation({
    required this.instanceId,
    this.memberId,
    required this.title,
    required this.groupTitle,
    this.imageUrl,
    this.faces = const [],
    this.last,
    this.unread = false,
  });

  bool get isDirect => memberId != null;

  /// When the conversation last moved; null sorts after every dated one.
  DateTime? get at => last?.at;

  /// Identity for list keys and for `ChatsCubit.markOpened`.
  String get key => chatKey(instanceId, memberId);

  @override
  List<Object?> get props => [
    instanceId,
    memberId,
    title,
    groupTitle,
    imageUrl,
    faces,
    last,
    unread,
  ];
}

class ChatsState extends Equatable {
  /// Rooms and direct threads, newest first.
  final List<ChatConversation> conversations;

  /// Published group templates this player has no save of yet.
  final List<WorldTemplate> joinable;

  /// A fetch is running. Show a spinner only while [hasLoaded] is false; later
  /// refreshes happen quietly under the rows already on screen.
  final bool isLoading;

  /// At least one fetch of the list succeeded.
  final bool hasLoaded;

  /// The latest fetch failed. The previous rows stay in [conversations].
  final bool hasError;

  const ChatsState({
    this.conversations = const [],
    this.joinable = const [],
    this.isLoading = false,
    this.hasLoaded = false,
    this.hasError = false,
  });

  /// Conversations that need attention, for a badge on the tab.
  int get unreadCount => conversations.where((c) => c.unread).length;

  ChatsState copyWith({
    List<ChatConversation>? conversations,
    List<WorldTemplate>? joinable,
    bool? isLoading,
    bool? hasLoaded,
    bool? hasError,
  }) => ChatsState(
    conversations: conversations ?? this.conversations,
    joinable: joinable ?? this.joinable,
    isLoading: isLoading ?? this.isLoading,
    hasLoaded: hasLoaded ?? this.hasLoaded,
    hasError: hasError ?? this.hasError,
  );

  @override
  List<Object?> get props => [
    conversations,
    joinable,
    isLoading,
    hasLoaded,
    hasError,
  ];
}
