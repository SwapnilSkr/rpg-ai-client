import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../state/home_cubit.dart';
import 'widgets/realm_group_card.dart';
import '../../../../app/theme/nexus_theme.dart';
import '../../../../shared/app_icons.dart';
import '../../../../shared/widgets/everlore_session_loader.dart';
import '../../../../shared/widgets/everlore_top_bar.dart';
import '../../../../shared/widgets/neu.dart';
import '../../../../shared/widgets/everlore_empty_state.dart';
import '../../../../shared/widgets/realm_backdrop.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeCubit()..loadInstances(),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _searchOpen = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (_scrollController.position.extentAfter > 520) return;
    context.read<HomeCubit>().loadMore();
  }

  void _toggleSearch() {
    setState(() => _searchOpen = !_searchOpen);
    if (!_searchOpen && _searchController.text.isNotEmpty) {
      _searchDebounce?.cancel();
      _searchController.clear();
      context.read<HomeCubit>().loadInstances(search: '');
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      if (mounted) context.read<HomeCubit>().loadInstances(search: value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EverloreTheme.void1,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/art/forge-muse.webp',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          const EmberOverlay(),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  EverloreTheme.void0.withValues(alpha: 0.22),
                  EverloreTheme.void0.withValues(alpha: 0.58),
                  EverloreTheme.void0.withValues(alpha: 0.84),
                ],
                stops: const [0, 0.42, 1],
              ),
            ),
          ),
          Column(
            children: [
              BlocBuilder<HomeCubit, HomeState>(
                buildWhen: (previous, current) =>
                    previous.isLoading != current.isLoading ||
                    previous.realms.length != current.realms.length ||
                    previous.total != current.total,
                builder: (context, state) {
                  return EverloreTopBar(
                    title: 'Your Realms',
                    subtitle: state.realms.isEmpty
                        ? (_searchController.text.isNotEmpty
                              ? 'No matching realms'
                              : 'No realms yet')
                        : '${state.total} ${state.total == 1 ? 'realm' : 'realms'}',
                    backgroundOpacity: 0.68,
                    actions: [
                      EverloreTopBarIcon(
                        icon: _searchOpen
                            ? Icons.close_rounded
                            : Icons.search_rounded,
                        tooltip: _searchOpen ? 'Close search' : 'Search realms',
                        onTap: _toggleSearch,
                      ),
                      EverloreTopBarIcon(
                        icon: Icons.refresh_rounded,
                        tooltip: 'Refresh realms',
                        isLoading:
                            state.isLoading && state.instances.isNotEmpty,
                        onTap: () => context.read<HomeCubit>().loadInstances(
                          forceRefresh: true,
                        ),
                      ),
                    ],
                  );
                },
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: _searchOpen
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          onChanged: _onSearchChanged,
                          textInputAction: TextInputAction.search,
                          style: EverloreTheme.ui(
                            size: 14,
                            color: EverloreTheme.parchment,
                          ),
                          decoration: _realmSearchDecoration(),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              Expanded(
                child: BlocBuilder<HomeCubit, HomeState>(
                  builder: (context, state) {
                    return CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        if (state.isLoading && state.realms.isEmpty)
                          const SliverFillRemaining(child: _LoadingView())
                        else if (state.error != null &&
                            state.error!.contains('Unauthorized') &&
                            state.realms.isEmpty)
                          const SliverFillRemaining(child: _UnauthView())
                        else if (state.error != null && state.realms.isEmpty)
                          SliverFillRemaining(
                            child: _ErrorView(message: state.error!),
                          )
                        else if (state.realms.isEmpty)
                          SliverFillRemaining(
                            child: _EmptyView(
                              isSearchEmpty: _searchController.text.isNotEmpty,
                            ),
                          )
                        else
                          _buildRealmList(context, state),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRealmList(BuildContext context, HomeState state) {
    final groups = state.realms;

    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 110), // clear the floating nav
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Row(
                children: [
                  Text(
                    '${groups.length} ${groups.length == 1 ? 'REALM' : 'REALMS'}',
                    style: EverloreTheme.sectionHeader,
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.read<HomeCubit>().loadInstances(
                      forceRefresh: true,
                    ),
                    child: const Text(
                      'Refresh',
                      style: TextStyle(color: EverloreTheme.gold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          }
          if (index == groups.length + 1 && state.isLoadingMore) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: EverloreTheme.gold,
                ),
              ),
            );
          }
          if (index > groups.length) return null;
          final group = groups[index - 1];
          return RealmGroupCard(
            group: group,
            onContinue: (story) async {
              await context.push('/play/${story.id}');
              if (context.mounted) {
                unawaited(
                  context.read<HomeCubit>().loadInstances(silent: true),
                );
              }
            },
            onViewStories: () async {
              await context.push('/realms/${group.templateId}');
              if (context.mounted) {
                unawaited(
                  context.read<HomeCubit>().loadInstances(silent: true),
                );
              }
            },
          );
        }, childCount: groups.length + 1 + (state.isLoadingMore ? 1 : 0)),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: EverloreSessionLoader(message: 'Summoning your realms'),
    );
  }
}

class _UnauthView extends StatelessWidget {
  const _UnauthView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EverloreTheme.void2,
                border: Border.all(
                  color: EverloreTheme.goldDim.withValues(alpha: 0.3),
                ),
              ),
              child: const EvIcon(AppIcons.lockedGate, size: 68),
            ),
            const SizedBox(height: 24),
            const Text(
              'Your realms await',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: EverloreTheme.parchment,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Sign in to access your adventures and continue your story.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: EverloreTheme.ash,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            NeuButton(
              label: 'Sign In',
              icon: Icons.login,
              onTap: () => context.push('/auth'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/discover'),
              child: const Text(
                'Browse Worlds First',
                style: TextStyle(color: EverloreTheme.ash),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final bool isSearchEmpty;
  const _EmptyView({this.isSearchEmpty = false});

  @override
  Widget build(BuildContext context) {
    return EverloreEmptyState(
      icon: isSearchEmpty
          ? Icons.search_off_rounded
          : Icons.auto_stories_rounded,
      eyebrow: isSearchEmpty ? 'NO MATCHES' : 'YOUR REALMS',
      title: isSearchEmpty ? 'No realms found' : 'Your first realm awaits',
      message: isSearchEmpty
          ? 'Try another title or clear the search to see all your realms.'
          : 'Choose a world, step through its threshold, and let your story take its first breath.',
      actionLabel: isSearchEmpty ? 'Clear search' : 'Explore worlds',
      actionIcon: isSearchEmpty ? Icons.close_rounded : Icons.explore_rounded,
      accent: EverloreTheme.gold,
      onAction: () => isSearchEmpty
          ? context.read<HomeCubit>().loadInstances(search: '')
          : context.go('/discover'),
    );
  }
}

InputDecoration _realmSearchDecoration() => InputDecoration(
  hintText: 'Search your realms',
  hintStyle: EverloreTheme.ui(size: 14, color: EverloreTheme.ash),
  prefixIcon: const Icon(Icons.search_rounded, color: EverloreTheme.goldDim),
  filled: true,
  fillColor: EverloreTheme.void2,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(
      color: EverloreTheme.goldDim.withValues(alpha: 0.22),
    ),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(
      color: EverloreTheme.goldDim.withValues(alpha: 0.22),
    ),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: EverloreTheme.gold, width: 1.2),
  ),
);

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EvIcon(AppIcons.errorRune, size: 110),
            const SizedBox(height: 20),
            const Text(
              'Could not summon realms',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: EverloreTheme.parchment,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: EverloreTheme.ash,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            NeuButton(
              label: 'Try Again',
              onTap: () => context.read<HomeCubit>().loadInstances(),
            ),
          ],
        ),
      ),
    );
  }
}
