import 'dart:async';

import '../../../core/guide/guide_anchor.dart';
import '../../../core/guide/guide_flows.dart';
import '../../../core/guide/guide_ids.dart';
import '../../../core/guide/guide_trigger.dart';

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
import '../../../../shared/widgets/everlore_notice.dart';
import '../../../../shared/widgets/realm_backdrop.dart';
import 'playthrough_route.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.walks = false});

  /// The Walks shelf — map-world playthroughs, not chat realms.
  final bool walks;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeCubit(walks: walks)..loadInstances(),
      child: _HomeView(walks: walks),
    );
  }
}

class _HomeView extends StatefulWidget {
  const _HomeView({required this.walks});

  final bool walks;

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
          BlocBuilder<HomeCubit, HomeState>(
            buildWhen: (previous, current) =>
                previous.realms.isEmpty != current.realms.isEmpty ||
                previous.isLoading != current.isLoading,
            // Two arcs, one surface. A shelf with stories on it explains the
            // stories; a shelf with none explains the shelf. Which one is
            // owed is not knowable until the first load has answered, so
            // neither runs before it has. Walks is a sibling shelf and
            // must not replay the Realms script.
            builder: (context, state) => GuideOnEnter(
              flow: state.realms.isEmpty
                  ? GuideFlows.homeEmpty
                  : GuideFlows.home,
              enabled: !widget.walks && !state.isLoading,
              child: Column(
                children: [
                  BlocBuilder<HomeCubit, HomeState>(
                    buildWhen: (previous, current) =>
                        previous.isLoading != current.isLoading ||
                        previous.realms.length != current.realms.length ||
                        previous.total != current.total,
                    builder: (context, state) {
                      return EverloreTopBar(
                        title: widget.walks ? 'Your Walks' : 'Your Realms',
                        subtitle: state.realms.isEmpty
                            ? (_searchController.text.isNotEmpty
                                  ? (widget.walks
                                        ? 'No matching walks'
                                        : 'No matching realms')
                                  : (widget.walks
                                        ? 'No walks yet'
                                        : 'No realms yet'))
                            : '${state.total} ${state.total == 1 ? (widget.walks ? 'walk' : 'realm') : (widget.walks ? 'walks' : 'realms')}',
                        backgroundOpacity: 0.68,
                        actions: [
                          EverloreTopBarIcon(
                            icon: _searchOpen
                                ? Icons.close_rounded
                                : Icons.search_rounded,
                            tooltip: _searchOpen
                                ? 'Close search'
                                : (widget.walks
                                      ? 'Search walks'
                                      : 'Search realms'),
                            onTap: _toggleSearch,
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
                              decoration: widget.walks
                                  ? _walkSearchDecoration()
                                  : _realmSearchDecoration(),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  Expanded(
                    child: BlocBuilder<HomeCubit, HomeState>(
                      builder: (context, state) {
                        return RefreshIndicator(
                          color: EverloreTheme.gold,
                          backgroundColor: EverloreTheme.void2,
                          onRefresh: () => context
                              .read<HomeCubit>()
                              .loadInstances(forceRefresh: true),
                          child: CustomScrollView(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              if (state.isLoading && state.realms.isEmpty)
                                SliverFillRemaining(
                                  child: _LoadingView(walks: widget.walks),
                                )
                              else if (state.error != null &&
                                  state.error!.contains('Unauthorized') &&
                                  state.realms.isEmpty)
                                SliverFillRemaining(
                                  child: _UnauthView(walks: widget.walks),
                                )
                              else if (state.error != null &&
                                  state.realms.isEmpty)
                                SliverFillRemaining(
                                  child: _ErrorView(
                                    message: state.error!,
                                    walks: widget.walks,
                                  ),
                                )
                              else if (state.realms.isEmpty)
                                SliverFillRemaining(
                                  child: _EmptyView(
                                    isSearchEmpty:
                                        _searchController.text.isNotEmpty,
                                    walks: widget.walks,
                                  ),
                                )
                              else
                                _buildRealmList(context, state),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
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
        // No count label here. The top bar already prints one 40pt above it,
        // and this one was the wrong number besides — `groups.length` is what
        // has loaded so far, so it read "1 REALM" under a header saying "12
        // realms" until the reader scrolled. A lone section header labelling
        // the only section is not structure, it is noise.
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index == groups.length && state.isLoadingMore) {
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
          if (index >= groups.length) return null;
          final group = groups[index];
          // The newest story stands for all of them.
          return guideAnchorIf(
            index == 0,
            GuideIds.homeCard,
            RealmGroupCard(
              group: group,
              onContinue: (story) async {
                await context.push(
                  playthroughLocation(
                    instanceId: story.id,
                    interactiveWorldKey: interactiveWorldKeyOf(
                      group.template ?? story.template,
                    ),
                  ),
                );
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
              onArchive: () async {
                final cubit = context.read<HomeCubit>();
                final ok = await cubit.archiveInstance(group.latest.id);
                if (!ok && context.mounted) {
                  showEverloreNotice(
                    context,
                    cubit.state.error ??
                        (widget.walks
                            ? 'Could not seal that walk.'
                            : 'Could not seal that story.'),
                    tone: NoticeTone.error,
                  );
                }
              },
              onDelete: () async {
                final cubit = context.read<HomeCubit>();
                final ok = await cubit.deleteInstance(group.latest.id);
                if (!ok && context.mounted) {
                  showEverloreNotice(
                    context,
                    cubit.state.error ??
                        (widget.walks
                            ? 'Could not delete that walk.'
                            : 'Could not delete that story.'),
                    tone: NoticeTone.error,
                  );
                }
              },
            ),
          );
        }, childCount: groups.length + (state.isLoadingMore ? 1 : 0)),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({this.walks = false});

  final bool walks;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: EverloreSessionLoader(
        message: walks ? 'Summoning your walks' : 'Summoning your realms',
      ),
    );
  }
}

class _UnauthView extends StatelessWidget {
  const _UnauthView({this.walks = false});

  final bool walks;

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
            Text(
              walks ? 'Your walks await' : 'Your realms await',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: EverloreTheme.parchment,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              walks
                  ? 'Sign in to step onto the map and continue a walkable world.'
                  : 'Sign in to access your adventures and continue your story.',
              textAlign: TextAlign.center,
              style: const TextStyle(
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
  final bool walks;
  const _EmptyView({this.isSearchEmpty = false, this.walks = false});

  @override
  Widget build(BuildContext context) {
    return EverloreEmptyState(
      icon: isSearchEmpty
          ? Icons.search_off_rounded
          : walks
          ? Icons.map_outlined
          : Icons.auto_stories_rounded,
      eyebrow: isSearchEmpty
          ? 'NO MATCHES'
          : (walks ? 'YOUR WALKS' : 'YOUR REALMS'),
      title: isSearchEmpty
          ? (walks ? 'No walks found' : 'No realms found')
          : (walks ? 'Your first walk awaits' : 'Your first realm awaits'),
      message: isSearchEmpty
          ? (walks
                ? 'Try another title or clear the search to see all your walks.'
                : 'Try another title or clear the search to see all your realms.')
          : (walks
                ? 'Choose a walkable world, step onto the map, and let the land remember you.'
                : 'Choose a world, step through its threshold, and let your story take its first breath.'),
      actionLabel: isSearchEmpty
          ? 'Clear search'
          : (walks ? 'Explore walks' : 'Explore worlds'),
      actionIcon: isSearchEmpty ? Icons.close_rounded : Icons.explore_rounded,
      accent: EverloreTheme.gold,
      // Only the genuinely-empty shelf is a first-run moment. A search that
      // matched nothing is a dead end the player made themselves, and the
      // Chronicler has nothing useful to say about it.
      anchorId: isSearchEmpty || walks ? null : GuideIds.homeEmpty,
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

InputDecoration _walkSearchDecoration() => InputDecoration(
  hintText: 'Search your walks',
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
  final bool walks;
  const _ErrorView({required this.message, this.walks = false});

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
            Text(
              walks ? 'Could not summon walks' : 'Could not summon realms',
              textAlign: TextAlign.center,
              style: const TextStyle(
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
