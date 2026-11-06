import 'package:equatable/equatable.dart';

import '../models/app_notification.dart';

/// A foreground banner to show. [seq] changes with every arrival, so a second
/// banner for the same row still counts as a new event.
class NotificationBanner extends Equatable {
  final AppNotification item;
  final int seq;

  const NotificationBanner(this.item, this.seq);

  @override
  List<Object?> get props => [item, seq];
}

class NotificationsState extends Equatable {
  /// Newest first, no repeated id.
  final List<AppNotification> items;

  /// The server's count, which can be more than the rows held here.
  final int unread;
  final bool hasLoaded;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;

  /// The first page could not be read.
  final bool hasError;

  /// Set when a frame arrives while the app is open and the place it points
  /// at is not on screen. A newer one replaces it; the banner clears it with
  /// [NotificationsCubit.dismissBanner] when it leaves.
  final NotificationBanner? banner;

  const NotificationsState({
    this.items = const [],
    this.unread = 0,
    this.hasLoaded = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.hasError = false,
    this.banner,
  });

  bool get hasUnread => unread > 0;

  NotificationsState copyWith({
    List<AppNotification>? items,
    int? unread,
    bool? hasLoaded,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    bool? hasError,
    NotificationBanner? banner,
    bool clearBanner = false,
  }) => NotificationsState(
    items: items ?? this.items,
    unread: unread ?? this.unread,
    hasLoaded: hasLoaded ?? this.hasLoaded,
    isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    hasMore: hasMore ?? this.hasMore,
    hasError: hasError ?? this.hasError,
    banner: clearBanner ? null : (banner ?? this.banner),
  );

  @override
  List<Object?> get props => [
    items,
    unread,
    hasLoaded,
    isLoading,
    isLoadingMore,
    hasMore,
    hasError,
    banner,
  ];
}
