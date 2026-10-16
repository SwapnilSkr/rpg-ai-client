import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/nexus_theme.dart';
import '../../../../shared/widgets/everlore_top_bar.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/neu.dart';
import '../data/keepsakes_repository.dart';
import '../models/keepsake_item.dart';
import '../state/keepsakes_cubit.dart';
import '../state/keepsakes_state.dart';
import 'widgets/keepsake_feed_post.dart';
import 'widgets/keepsake_grid_tile.dart';
import 'widgets/keepsakes_filter_row.dart';
import 'widgets/keepsakes_state_view.dart';
import 'widgets/keepsakes_viewer_screen.dart';

int getGridColumns(double width) {
  if (width >= 1000) return 5;
  if (width >= 700) return 4;
  return 3;
}

class KeepsakesScreen extends StatelessWidget {
  final KeepsakesRepository? repository;

  const KeepsakesScreen({super.key, this.repository});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => KeepsakesCubit(
        repository: repository ?? HttpKeepsakesRepository(),
      )..loadInitial(),
      child: const _KeepsakesView(),
    );
  }
}

class _KeepsakesView extends StatefulWidget {
  const _KeepsakesView();

  @override
  State<_KeepsakesView> createState() => _KeepsakesViewState();
}

class _KeepsakesViewState extends State<_KeepsakesView> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    if (currentScroll >= maxScroll - 350) {
      context.read<KeepsakesCubit>().loadNextPage();
    }
  }

  Widget _buildEndFlourish({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        EverloreTheme.goldDim.withValues(alpha: 0.35),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.auto_awesome,
                  size: 13,
                  color: EverloreTheme.goldDim.withValues(alpha: 0.6),
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        EverloreTheme.goldDim.withValues(alpha: 0.35),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildSkeletonFeed() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 28),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: EverloreTheme.void2.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: EverloreTheme.goldDim.withValues(alpha: 0.16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header skeleton
              Row(
                children: [
                  const LoadingShimmer(width: 34, height: 34, radius: 17),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      LoadingShimmer(width: 120, height: 14, radius: 4),
                      SizedBox(height: 6),
                      LoadingShimmer(width: 80, height: 11, radius: 3),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 9:16 block
              const AspectRatio(
                aspectRatio: 9 / 16,
                child: LoadingShimmer(width: double.infinity, height: double.infinity, radius: 16),
              ),
              const SizedBox(height: 12),
              // Caption lines
              const LoadingShimmer(width: double.infinity, height: 13, radius: 3),
              const SizedBox(height: 6),
              const LoadingShimmer(width: 200, height: 13, radius: 3),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSkeletonGrid(int columns) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: 9 / 16,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: columns * 2,
      itemBuilder: (context, index) {
        return const LoadingShimmer(
          width: double.infinity,
          height: double.infinity,
          radius: 12,
        );
      },
    );
  }

  Widget _buildFeedContent(BuildContext context, KeepsakesState state) {
    final items = state.items;
    final count = items.length;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: count +
          (state.isLoadingNextPage ? 1 : 0) +
          (state.nextPageError != null ? 1 : 0) +
          (count > 0 && !state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < count) {
          final item = items[index];
          return KeepsakeFeedPost(
            item: item,
            isAutoplayEnabled: !reducedMotion,
            onTap: () {
              KeepsakesViewerScreen.show(
                context,
                items: items,
                initialIndex: index,
              );
            },
            onRemove: () => context.read<KeepsakesCubit>().removeKeepsake(item.mediaId),
          );
        }

        // Paging skeleton
        if (state.isLoadingNextPage && index == count) {
          return Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: EverloreTheme.void2.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LoadingShimmer(width: 140, height: 14, radius: 4),
                SizedBox(height: 12),
                AspectRatio(
                  aspectRatio: 9 / 16,
                  child: LoadingShimmer(width: double.infinity, height: double.infinity, radius: 16),
                ),
              ],
            ),
          );
        }

        // Paging error
        if (state.nextPageError != null && index == (count + (state.isLoadingNextPage ? 1 : 0))) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Couldn't reach the rest.",
                  style: EverloreTheme.ui(size: 13, color: EverloreTheme.ash),
                ),
                const SizedBox(height: 8),
                NeuButton(
                  label: 'Try again',
                  onTap: () => context.read<KeepsakesCubit>().loadNextPage(),
                ),
              ],
            ),
          );
        }

        // End of list / 1-3 nudge
        if (count > 0 && !state.hasMore) {
          if (count <= 3) {
            return _buildEndFlourish(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'That\'s everything you\'ve kept.',
                    style: TextStyle(
                      fontFamily: EverloreTheme.aiText.fontFamily,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: EverloreTheme.ash,
                    ),
                  ),
                  const SizedBox(height: 12),
                  NeuButton(
                    label: 'Picture another moment',
                    primary: false,
                    accent: EverloreTheme.gold,
                    onTap: () => context.go('/'),
                  ),
                ],
              ),
            );
          }

          return _buildEndFlourish(
            child: Text(
              'That\'s everything you\'ve kept.',
              style: TextStyle(
                fontFamily: EverloreTheme.aiText.fontFamily,
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: EverloreTheme.ash,
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildGridContent(BuildContext context, KeepsakesState state, int columns) {
    final items = state.items;
    final count = items.length;

    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(12),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              childAspectRatio: 9 / 16,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = items[index];
                return KeepsakeGridTile(
                  item: item,
                  onTap: () {
                    KeepsakesViewerScreen.show(
                      context,
                      items: items,
                      initialIndex: index,
                    );
                  },
                );
              },
              childCount: count,
            ),
          ),
        ),

        // Paging indicator
        if (state.isLoadingNextPage)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: EverloreTheme.goldDim,
                  ),
                ),
              ),
            ),
          ),

        // Paging error
        if (state.nextPageError != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Text(
                    "Couldn't reach the rest.",
                    style: EverloreTheme.ui(size: 13, color: EverloreTheme.ash),
                  ),
                  const SizedBox(height: 8),
                  NeuButton(
                    label: 'Try again',
                    onTap: () => context.read<KeepsakesCubit>().loadNextPage(),
                  ),
                ],
              ),
            ),
          ),

        // End flourish
        if (count > 0 && !state.hasMore)
          SliverToBoxAdapter(
            child: count <= 3
                ? _buildEndFlourish(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'That\'s everything you\'ve kept.',
                          style: TextStyle(
                            fontFamily: EverloreTheme.aiText.fontFamily,
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: EverloreTheme.ash,
                          ),
                        ),
                        const SizedBox(height: 12),
                        NeuButton(
                          label: 'Picture another moment',
                          primary: false,
                          accent: EverloreTheme.gold,
                          onTap: () => context.go('/'),
                        ),
                      ],
                    ),
                  )
                : _buildEndFlourish(
                    child: Text(
                      'That\'s everything you\'ve kept.',
                      style: TextStyle(
                        fontFamily: EverloreTheme.aiText.fontFamily,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: EverloreTheme.ash,
                      ),
                    ),
                  ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, KeepsakesState state) {
    // 1. Filter-only empty state (§3.5)
    if (state.isFilterOnlyEmpty) {
      final (title, body) = switch (state.filter) {
        KeepsakesFilter.pictures => (
          'No pictures yet',
          'No pictures yet. Long-press a moment and choose Picture this.',
        ),
        KeepsakesFilter.films => (
          'No films yet',
          'No films yet. Long-press a moment and choose Film this, or long-press a spoken line.',
        ),
        KeepsakesFilter.faces => (
          'No faces yet',
          'No faces yet. They appear when you picture or film the people in your stories.',
        ),
        KeepsakesFilter.all => ('Nothing kept yet', ''),
      };

      return KeepsakesStateView(
        compact: true,
        title: title,
        body: body,
        actionLabel: 'Show all',
        onAction: () => context.read<KeepsakesCubit>().setFilter(KeepsakesFilter.all),
      );
    }

    // 2. Full empty state variants
    if (state.hasAnySaves) {
      return KeepsakesStateView(
        title: 'Nothing kept yet',
        body: 'Long-press any moment in a story to picture it or film it. What you make gathers here.',
        actionLabel: 'Open your realms',
        onAction: () => context.go('/'),
      );
    } else {
      return KeepsakesStateView(
        title: 'Nothing kept yet',
        body: 'Begin a story, then picture or film the moments worth keeping.',
        actionLabel: 'Find a world',
        onAction: () => context.go('/discover'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = getGridColumns(width);

    return Scaffold(
      backgroundColor: EverloreTheme.void0,
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<KeepsakesCubit, KeepsakesState>(
          builder: (context, state) {
            return Column(
              children: [
                const EverloreTopBar(
                  title: 'Keepsakes',
                  showProfile: true,
                ),
                // Filter row stays visible whenever player has any keepsakes (§3.5)
                if (state.hasAnyKeepsakesOverall || state.items.isNotEmpty || state.filter != KeepsakesFilter.all)
                  KeepsakesFilterRow(
                    selectedFilter: state.filter,
                    viewMode: state.mode,
                    onFilterChanged: (f) => context.read<KeepsakesCubit>().setFilter(f),
                    onModeChanged: (m) => context.read<KeepsakesCubit>().setMode(m),
                  ),

                // Main body
                Expanded(
                  child: RefreshIndicator(
                    color: EverloreTheme.gold,
                    backgroundColor: EverloreTheme.void2,
                    onRefresh: () => context.read<KeepsakesCubit>().refresh(),
                    child: Builder(
                      builder: (context) {
                        // 1. First load error (§3.5)
                        if (state.error != null && state.items.isEmpty) {
                          return KeepsakesStateView(
                            isError: true,
                            title: 'Out of reach',
                            body: 'Your keepsakes are out of reach. Check your connection and try again.',
                            actionLabel: 'Try again',
                            onAction: () => context.read<KeepsakesCubit>().loadInitial(),
                          );
                        }

                        // 2. Initial loading skeleton (§3.5)
                        if (state.isLoading && state.items.isEmpty) {
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 560),
                              child: state.effectiveMode == KeepsakesViewMode.feed
                                  ? _buildSkeletonFeed()
                                  : _buildSkeletonGrid(columns),
                            ),
                          );
                        }

                        // 3. Empty state (§3.5)
                        if (state.isEmpty) {
                          return _buildEmptyState(context, state);
                        }

                        // 4. Feed or Grid mode
                        if (state.effectiveMode == KeepsakesViewMode.feed) {
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 560),
                              child: _buildFeedContent(context, state),
                            ),
                          );
                        }

                        return _buildGridContent(context, state, columns);
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
