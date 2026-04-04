import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../state/home_cubit.dart';
import 'widgets/world_card.dart';
import '../../../../app/theme/nexus_theme.dart';

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
      body: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          return CustomScrollView(
            slivers: [
              _buildAppBar(context, state),
              if (state.isLoading && state.instances.isEmpty)
                const SliverFillRemaining(
                  child: _LoadingView(),
                )
              else if (state.error != null &&
                  state.error!.contains('Unauthorized') &&
                  state.instances.isEmpty)
                const SliverFillRemaining(child: _UnauthView())
              else if (state.instances.isEmpty)
                const SliverFillRemaining(child: _EmptyView())
              else
                _buildInstanceList(context, state),
            ],
          );
        },
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, HomeState state) {
    return SliverAppBar(
      backgroundColor: EverloreTheme.void0,
      expandedHeight: 110,
      floating: true,
      snap: true,
      pinned: false,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(color: EverloreTheme.void0),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Logo mark
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: EverloreTheme.goldDim
                                  .withValues(alpha: 0.5)),
                        ),
                        child: const Icon(Icons.auto_stories,
                            color: EverloreTheme.gold, size: 16),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'EVERLORE',
                        style: TextStyle(
                          color: EverloreTheme.gold,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4,
                        ),
                      ),
                      const Spacer(),
                      _HeaderButton(
                        icon: Icons.explore_outlined,
                        tooltip: 'Explore Worlds',
                        onTap: () => context.push('/templates'),
                      ),
                      const SizedBox(width: 4),
                      _HeaderButton(
                        icon: Icons.auto_fix_high,
                        tooltip: 'My Worlds',
                        onTap: () => context.push('/my-worlds'),
                      ),
                      const SizedBox(width: 4),
                      _HeaderButton(
                        icon: Icons.person_outline,
                        tooltip: 'Profile',
                        onTap: () => context.push('/auth'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Your Realms',
                    style: TextStyle(
                      color: EverloreTheme.parchment,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: const [SizedBox(width: 0)],
    );
  }

  SliverList _buildInstanceList(BuildContext context, HomeState state) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Row(
                children: [
                  Text(
                    '${state.instances.length} ACTIVE',
                    style: EverloreTheme.sectionHeader,
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.read<HomeCubit>().loadInstances(),
                    child: const Text(
                      'Refresh',
                      style: TextStyle(
                          color: EverloreTheme.gold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          }
          if (index > state.instances.length) return null;
          final instance = state.instances[index - 1];
          return WorldCard(
            instance: instance,
            onTap: () => context.push('/play/${instance.id}'),
            onArchive: () => _confirmArchive(context, instance.id),
          );
        },
        childCount: state.instances.length + 1,
      ),
    );
  }

  void _confirmArchive(BuildContext context, String instanceId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EverloreTheme.void2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: EverloreTheme.goldDim.withValues(alpha: 0.3)),
        ),
        title: const Text(
          'Seal This Realm?',
          style: TextStyle(color: EverloreTheme.parchment, fontSize: 18),
        ),
        content: const Text(
          'This realm will be sealed away. Your story will be preserved.',
          style: TextStyle(color: EverloreTheme.ash, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Open',
                style: TextStyle(color: EverloreTheme.ash)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<HomeCubit>().archiveInstance(instanceId);
            },
            child: const Text('Seal Realm',
                style: TextStyle(color: EverloreTheme.crimson)),
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: EverloreTheme.void2,
            border: Border.all(
                color: EverloreTheme.goldDim.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, color: EverloreTheme.ash, size: 18),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: EverloreTheme.gold,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Summoning your realms...',
            style: TextStyle(color: EverloreTheme.ash, fontSize: 14),
          ),
        ],
      ),
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
                    color: EverloreTheme.goldDim.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.lock_outline,
                  color: EverloreTheme.goldDim, size: 36),
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
                  color: EverloreTheme.ash, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push('/auth'),
                child: const Text('Sign In'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.push('/templates'),
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
                    color: EverloreTheme.goldDim.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.explore,
                  color: EverloreTheme.gold, size: 40),
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
                  color: EverloreTheme.ash, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/templates'),
                icon: const Icon(Icons.explore, size: 18),
                label: const Text('Explore Worlds'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
