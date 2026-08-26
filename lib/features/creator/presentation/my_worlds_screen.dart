import 'dart:async';
import '../../../core/guide/guide_flows.dart';
import '../../../core/guide/guide_trigger.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../state/my_worlds_cubit.dart';
import 'widgets/my_world_card.dart';
import '../../../app/theme/nexus_theme.dart';
import '../../../core/auth/auth_service.dart';
import '../../../shared/app_icons.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/everlore_session_loader.dart';
import '../../../shared/widgets/everlore_top_bar.dart';
import '../../../shared/widgets/neu.dart';
import '../../../shared/widgets/everlore_empty_state.dart';
import '../../../shared/widgets/realm_backdrop.dart';

class MyWorldsScreen extends StatelessWidget {
  const MyWorldsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MyWorldsCubit()..load(),
      child: const _MyWorldsView(),
    );
  }
}

class _MyWorldsView extends StatefulWidget {
  const _MyWorldsView();

  @override
  State<_MyWorldsView> createState() => _MyWorldsViewState();
}

class _MyWorldsViewState extends State<_MyWorldsView> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _searchOpen = false;

  // Resolved once, not per build: a fresh Future handed to the FutureBuilder
  // on every setState (e.g. toggling search) resets it to waiting and flashes
  // the whole screen back to the forge loader.
  late final Future<User?> _sessionUser;

  @override
  void initState() {
    super.initState();
    _sessionUser = AuthService.resolveSessionUser();
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
    context.read<MyWorldsCubit>().loadMore();
  }

  void _toggleSearch() {
    setState(() => _searchOpen = !_searchOpen);
    if (!_searchOpen && _searchController.text.isNotEmpty) {
      _searchDebounce?.cancel();
      _searchController.clear();
      context.read<MyWorldsCubit>().load(forceRefresh: true);
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      if (mounted) context.read<MyWorldsCubit>().load(search: value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<User?>(
      future: _sessionUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: EverloreTheme.void1,
            body: Column(
              children: [
                EverloreTopBar(title: 'Worlds', subtitle: 'Your creations'),
                Expanded(
                  child: Center(
                    child: EverloreSessionLoader(message: 'Opening your forge'),
                  ),
                ),
              ],
            ),
          );
        }
        if (user == null) return _buildGate(context, _GateType.unauth);
        if (!AuthService.canAccessForge(user.tier)) {
          return _buildGate(context, _GateType.upgrade);
        }
        return _buildCreatorView(context);
      },
    );
  }

  Widget _buildGate(BuildContext context, _GateType type) {
    return Scaffold(
      backgroundColor: EverloreTheme.void1,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EverloreTopBar(title: 'Worlds', subtitle: 'Your creations'),
          Expanded(
            child: type == _GateType.unauth ? _UnauthGate() : _UpgradeGate(),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatorView(BuildContext context) {
    return Scaffold(
      backgroundColor: EverloreTheme.void1,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/art/worlds-vault.webp',
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
          BlocConsumer<MyWorldsCubit, MyWorldsState>(
            listener: (context, state) {
              if (state.error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      state.error!,
                      style: const TextStyle(color: EverloreTheme.parchment),
                    ),
                    backgroundColor: EverloreTheme.crimson.withValues(
                      alpha: 0.9,
                    ),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
                context.read<MyWorldsCubit>().clearError();
              }
            },
            builder: (context, state) {
              return GuideOnEnter(
                flow: GuideFlows.myWorlds,
                child: Column(
                  children: [
                    EverloreTopBar(
                      title: 'Worlds',
                      subtitle: state.total == 0
                          ? (_searchController.text.isNotEmpty
                                ? 'No matching worlds'
                                : 'No worlds yet')
                          : '${state.total} ${state.total == 1 ? 'world' : 'worlds'}',
                      backgroundOpacity: 0.68,
                      actions: [
                        EverloreTopBarIcon(
                          icon: _searchOpen
                              ? Icons.close_rounded
                              : Icons.search_rounded,
                          tooltip: _searchOpen
                              ? 'Close search'
                              : 'Search worlds',
                          onTap: _toggleSearch,
                        ),
                      ],
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
                                decoration: _creatorSearchDecoration(),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        color: EverloreTheme.gold,
                        backgroundColor: EverloreTheme.void2,
                        onRefresh: () => context.read<MyWorldsCubit>().load(
                          forceRefresh: true,
                        ),
                        child: CustomScrollView(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            if (state.isLoading && state.worlds.isEmpty)
                              const SliverFillRemaining(child: _LoadingView())
                            else if (!state.isLoading && state.worlds.isEmpty)
                              SliverFillRemaining(
                                child: _EmptyForgeView(
                                  onForge: _searchController.text.isNotEmpty
                                      ? () {
                                          _searchController.clear();
                                          context.read<MyWorldsCubit>().load();
                                        }
                                      : () => context.push('/my-worlds/forge'),
                                  isSearchEmpty:
                                      _searchController.text.isNotEmpty,
                                ),
                              )
                            else ...[
                              if (state.drafts.isNotEmpty) ...[
                                _sectionHeader(
                                  '${state.drafts.length} DRAFTS',
                                  Icons.edit_note,
                                  EverloreTheme.ember,
                                ),
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    0,
                                  ),
                                  sliver: SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (ctx, i) => MyWorldCard(
                                        template: state.drafts[i],
                                        isPublishing: state.publishingIds
                                            .contains(state.drafts[i].id),
                                        onEdit: () => context.push(
                                          '/my-worlds/${state.drafts[i].id}/forge',
                                          extra: state.drafts[i],
                                        ),
                                        onPublish: () => _confirmPublish(
                                          context,
                                          state.drafts[i].id,
                                          state.drafts[i].title,
                                        ),
                                        onDelete: () => context
                                            .read<MyWorldsCubit>()
                                            .delete(state.drafts[i].id),
                                      ),
                                      childCount: state.drafts.length,
                                    ),
                                  ),
                                ),
                              ],
                              if (state.published.isNotEmpty) ...[
                                _sectionHeader(
                                  '${state.published.length} PUBLISHED',
                                  Icons.public,
                                  EverloreTheme.verdant,
                                ),
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    0,
                                  ),
                                  sliver: SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (ctx, i) => MyWorldCard(
                                        template: state.published[i],
                                        isPublishing: false,
                                        onEdit: () => context.push(
                                          '/my-worlds/${state.published[i].id}/forge',
                                          extra: state.published[i],
                                        ),
                                        onTap: () => context.push(
                                          '/templates/${state.published[i].id}',
                                        ),
                                        onDelete: () => context
                                            .read<MyWorldsCubit>()
                                            .delete(state.published[i].id),
                                      ),
                                      childCount: state.published.length,
                                    ),
                                  ),
                                ),
                              ],
                              const SliverPadding(
                                padding: EdgeInsets.only(bottom: 120),
                              ),
                              if (state.isLoadingMore)
                                const SliverToBoxAdapter(
                                  child: Padding(
                                    padding: EdgeInsets.only(bottom: 130),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: EverloreTheme.gold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String label, IconData icon, Color color) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        child: Row(
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmPublish(BuildContext context, String id, String title) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        var isReleasing = false;
        String? releaseError;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: EverloreTheme.void2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: EverloreTheme.goldDim.withValues(alpha: 0.3),
              ),
            ),
            title: const Row(
              children: [
                EvIcon(AppIcons.publish, size: 22),
                SizedBox(width: 8),
                Text(
                  'Release This World?',
                  style: TextStyle(
                    color: EverloreTheme.parchment,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
            content: Text(
              releaseError ??
                  '"$title" will be revealed to all adventurers across the realm. You can still edit it later from My Worlds.',
              style: TextStyle(
                color: releaseError == null
                    ? EverloreTheme.ash
                    : EverloreTheme.crimson,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: isReleasing ? null : () => Navigator.pop(ctx),
                child: const Text(
                  'Keep Hidden',
                  style: TextStyle(color: EverloreTheme.ash),
                ),
              ),
              TextButton(
                onPressed: isReleasing
                    ? null
                    : () async {
                        setDialogState(() => isReleasing = true);
                        final released = await context
                            .read<MyWorldsCubit>()
                            .publish(id);
                        if (!ctx.mounted) return;
                        if (released) {
                          Navigator.pop(ctx);
                        } else {
                          setDialogState(() {
                            isReleasing = false;
                            releaseError =
                                'The release could not be completed. Nothing changed — try again.';
                          });
                        }
                      },
                child: isReleasing
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              color: EverloreTheme.gold,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Releasing…',
                            style: TextStyle(color: EverloreTheme.gold),
                          ),
                        ],
                      )
                    : const Text(
                        'Release to the Realm',
                        style: TextStyle(color: EverloreTheme.gold),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

enum _GateType { unauth, upgrade }

class _UnauthGate extends StatelessWidget {
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
              'Sign in to forge worlds',
              style: TextStyle(
                color: EverloreTheme.parchment,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Only authenticated creators may wield the arcane forge and breathe life into new realms.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: EverloreTheme.ash,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            NeuButton(
              label: 'Sign In',
              icon: Icons.login,
              onTap: () => context.push('/auth'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpgradeGate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Centered, non-scrolling — fits the viewport without a vertical scroll.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  EverloreTheme.gold.withValues(alpha: 0.18),
                  EverloreTheme.void2,
                ],
              ),
              border: Border.all(
                color: EverloreTheme.goldDim.withValues(alpha: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: EverloreTheme.gold.withValues(alpha: 0.1),
                  blurRadius: 20,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: const EvIcon(AppIcons.lockedGate, size: 58),
          ),
          const SizedBox(height: 16),
          const Text(
            'ASCEND TO FORGE',
            style: TextStyle(
              color: EverloreTheme.gold,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'World creation is granted to Premium and Creator wielders. Upgrade your pact to unlock the arcane forge.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: EverloreTheme.ash,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: EverloreTheme.void2,
              border: Border.all(
                color: EverloreTheme.goldDim.withValues(alpha: 0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(2, 4),
                ),
              ],
            ),
            child: Column(
              children: const [
                _UpgradeFeature(
                  icon: Icons.public,
                  title: 'Create & Publish Worlds',
                  subtitle: 'Share your realms with all adventurers',
                ),
                _UpgradeFeature(
                  icon: Icons.psychology_alt,
                  title: 'Custom AI Personalities',
                  subtitle: 'Define the Oracle\'s Voice and soul',
                ),
                _UpgradeFeature(
                  icon: Icons.bar_chart,
                  title: 'Design Stat Systems',
                  subtitle: 'Health, mana, honour — your rules',
                ),
                _UpgradeFeature(
                  icon: Icons.auto_stories,
                  title: 'Forge Scene Threads',
                  subtitle: 'Shape combat, dialogue, exploration',
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Upgrade available through your profile',
            style: TextStyle(color: EverloreTheme.goldDim, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _UpgradeFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isLast;

  const _UpgradeFeature({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EverloreTheme.gold.withValues(alpha: 0.1),
              ),
              child: Icon(icon, color: EverloreTheme.gold, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: EverloreTheme.parchment,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: EverloreTheme.ash,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!isLast) ...[
          const SizedBox(height: 8),
          const Divider(color: EverloreTheme.white10, height: 1, thickness: 1),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _EmptyForgeView extends StatelessWidget {
  final VoidCallback onForge;
  final bool isSearchEmpty;

  const _EmptyForgeView({required this.onForge, this.isSearchEmpty = false});

  @override
  Widget build(BuildContext context) {
    return EverloreEmptyState(
      icon: isSearchEmpty
          ? Icons.search_off_rounded
          : Icons.auto_awesome_rounded,
      eyebrow: isSearchEmpty ? 'NO MATCHES' : 'THE FORGE',
      title: isSearchEmpty ? 'No worlds found' : 'Your forge awaits',
      message: isSearchEmpty
          ? 'Try another title or clear the search to see all your creations.'
          : 'Shape the lore, set the rules, and release a world for adventurers to discover.',
      actionLabel: isSearchEmpty ? 'Clear search' : 'Forge your first world',
      actionIcon: isSearchEmpty ? Icons.close_rounded : Icons.add_rounded,
      accent: EverloreTheme.gold,
      onAction: onForge,
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: EverloreSessionLoader(message: 'Consulting the archives'),
    );
  }
}

InputDecoration _creatorSearchDecoration() => InputDecoration(
  hintText: 'Search your worlds',
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
