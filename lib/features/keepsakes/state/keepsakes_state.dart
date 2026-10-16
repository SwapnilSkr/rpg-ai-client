import '../models/keepsake_item.dart';

class KeepsakesState {
  final KeepsakesFilter filter;
  final KeepsakesViewMode mode;
  final List<KeepsakeItem> items;
  final String? nextBefore;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingNextPage;
  final bool isRefreshing;
  final String? error;
  final String? nextPageError;
  final bool hasAnySaves;
  final bool hasAnyKeepsakesOverall;

  const KeepsakesState({
    this.filter = KeepsakesFilter.all,
    this.mode = KeepsakesViewMode.feed,
    this.items = const [],
    this.nextBefore,
    this.hasMore = false,
    this.isLoading = false,
    this.isLoadingNextPage = false,
    this.isRefreshing = false,
    this.error,
    this.nextPageError,
    this.hasAnySaves = true,
    this.hasAnyKeepsakesOverall = false,
  });

  /// Faces filter is always grid mode per spec.
  KeepsakesViewMode get effectiveMode =>
      filter == KeepsakesFilter.faces ? KeepsakesViewMode.grid : mode;

  bool get isEmpty => !isLoading && items.isEmpty && error == null;

  bool get isFilterOnlyEmpty =>
      isEmpty && filter != KeepsakesFilter.all && hasAnyKeepsakesOverall;

  KeepsakesState copyWith({
    KeepsakesFilter? filter,
    KeepsakesViewMode? mode,
    List<KeepsakeItem>? items,
    String? nextBefore,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingNextPage,
    bool? isRefreshing,
    String? error,
    bool clearError = false,
    String? nextPageError,
    bool clearNextPageError = false,
    bool? hasAnySaves,
    bool? hasAnyKeepsakesOverall,
  }) {
    return KeepsakesState(
      filter: filter ?? this.filter,
      mode: mode ?? this.mode,
      items: items ?? this.items,
      nextBefore: nextBefore ?? this.nextBefore,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingNextPage: isLoadingNextPage ?? this.isLoadingNextPage,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: clearError ? null : (error ?? this.error),
      nextPageError: clearNextPageError ? null : (nextPageError ?? this.nextPageError),
      hasAnySaves: hasAnySaves ?? this.hasAnySaves,
      hasAnyKeepsakesOverall: hasAnyKeepsakesOverall ?? this.hasAnyKeepsakesOverall,
    );
  }
}
