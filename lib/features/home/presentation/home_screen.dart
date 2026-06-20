import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../domain/realm_group.dart';
import '../state/home_cubit.dart';
import 'widgets/realm_group_card.dart';
import '../../../../app/theme/nexus_theme.dart';
import '../../../../shared/app_icons.dart';
import '../../../../shared/widgets/everlore_session_loader.dart';
import '../../../../shared/widgets/everlore_top_bar.dart';
import '../../../../shared/widgets/neu.dart';

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

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EverloreTheme.void1,
      body: Column(
        children: [
          BlocBuilder<HomeCubit, HomeState>(
            buildWhen: (previous, current) =>
                previous.isLoading != current.isLoading ||
                previous.instances.length != current.instances.length,
            builder: (context, state) {
              return EverloreTopBar(
                title: 'Your Realms',
                subtitle: state.instances.isEmpty
                    ? 'Worlds and stories'
                    : '${groupInstancesByRealm(state.instances).length} worlds',
                actions: [
                  EverloreTopBarIcon(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Refresh realms',
                    isLoading: state.isLoading && state.instances.isNotEmpty,
                    onTap: () => context.read<HomeCubit>().loadInstances(
                      forceRefresh: true,
                    ),
                  ),
                ],
              );
            },
          ),
          Expanded(
            child: BlocBuilder<HomeCubit, HomeState>(
              builder: (context, state) {
                return CustomScrollView(
                  slivers: [
                    if (state.isLoading && state.instances.isEmpty)
                      const SliverFillRemaining(child: _LoadingView())
                    else if (state.error != null &&
                        state.error!.contains('Unauthorized') &&
                        state.instances.isEmpty)
                      const SliverFillRemaining(child: _UnauthView())
                    else if (state.error != null && state.instances.isEmpty)
                      SliverFillRemaining(
                        child: _ErrorView(message: state.error!),
                      )
                    else if (state.instances.isEmpty)
                      const SliverFillRemaining(child: _EmptyView())
                    else
                      _buildRealmList(context, state),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealmList(BuildContext context, HomeState state) {
    final groups = groupInstancesByRealm(state.instances);

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
                    '${groups.length} ${groups.length == 1 ? 'WORLD' : 'WORLDS'}',
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
          if (index > groups.length) return null;
          final group = groups[index - 1];
          return RealmGroupCard(
            group: group,
            onViewStories: () async {
              await context.push('/realms/${group.templateId}');
              if (context.mounted) {
                unawaited(
                  context.read<HomeCubit>().loadInstances(silent: true),
                );
              }
            },
            onStoryTap: (story) async {
              await context.push('/play/${story.id}');
              if (context.mounted) {
                unawaited(
                  context.read<HomeCubit>().loadInstances(silent: true),
                );
              }
            },
            onArchiveStory: (story) =>
                context.read<HomeCubit>().archiveInstance(story.id),
            onDeleteStory: (story) =>
                context.read<HomeCubit>().deleteInstance(story.id),
          );
        }, childCount: groups.length + 1),
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
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    EverloreTheme.violet.withValues(alpha: 0.15),
                    EverloreTheme.void2,
                  ],
                ),
                border: Border.all(
                  color: EverloreTheme.goldDim.withValues(alpha: 0.3),
                ),
              ),
              child: const EvIcon(AppIcons.emptyRealms, size: 86),
            ),
            const SizedBox(height: 24),
            const Text(
              'No realms yet',
              style: TextStyle(
                color: EverloreTheme.parchment,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your first adventure is waiting. Choose a world and begin your legend.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: EverloreTheme.ash,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            NeuButton(
              label: 'Explore Worlds',
              icon: Icons.explore,
              onTap: () => context.go('/discover'),
            ),
          ],
        ),
      ),
    );
  }
}

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
