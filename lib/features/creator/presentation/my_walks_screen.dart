import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/nexus_theme.dart';
import '../../../core/auth/auth_service.dart';
import '../../../shared/app_icons.dart';
import '../../../shared/models/user.dart';
import '../../../shared/models/world_template.dart';
import '../../../shared/widgets/everlore_empty_state.dart';
import '../../../shared/widgets/everlore_session_loader.dart';
import '../../../shared/widgets/everlore_top_bar.dart';
import '../../../shared/widgets/realm_backdrop.dart';
import '../../home/presentation/realm_entry_flow.dart';
import 'widgets/my_world_card.dart';
import '../state/my_walks_cubit.dart';

class MyWalksScreen extends StatefulWidget {
  const MyWalksScreen({super.key});

  @override
  State<MyWalksScreen> createState() => _MyWalksScreenState();
}

class _MyWalksScreenState extends State<MyWalksScreen> {
  late final Future<User?> _sessionUser;

  @override
  void initState() {
    super.initState();
    _sessionUser = AuthService.getCurrentUser();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<User?>(
      future: _sessionUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: EverloreTheme.void1,
            body: Column(
              children: [
                _topBar(context),
                const Expanded(
                  child: Center(
                    child: EverloreSessionLoader(message: 'Opening your walks'),
                  ),
                ),
              ],
            ),
          );
        }
        if (user == null) {
          return Scaffold(
            backgroundColor: EverloreTheme.void1,
            body: Column(
              children: [
                _topBar(context),
                Expanded(
                  child: EverloreEmptyState(
                    icon: Icons.lock_outline_rounded,
                    eyebrow: 'MY WALKS',
                    title: 'Sign in to tend your walks',
                    message:
                        'Walkable worlds you author appear here as drafts until you release them.',
                    actionLabel: 'Sign in',
                    onAction: () => context.push('/auth'),
                  ),
                ),
              ],
            ),
          );
        }
        return BlocProvider(
          create: (_) => MyWalksCubit()..load(),
          child: _MyWalksView(topBar: _topBar(context)),
        );
      },
    );
  }

  EverloreTopBar _topBar(BuildContext context) {
    return EverloreTopBar(
      title: 'My Walks',
      subtitle: 'Worlds you authored',
      backgroundOpacity: 0.98,
      showProfile: false,
      actions: [
        EverloreTopBarIcon(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Back to profile',
          onTap: () => context.canPop() ? context.pop() : context.go('/profile'),
        ),
      ],
    );
  }
}

class _MyWalksView extends StatelessWidget {
  const _MyWalksView({required this.topBar});
  final EverloreTopBar topBar;

  @override
  Widget build(BuildContext context) {
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
          Column(
            children: [
              topBar,
              Expanded(
                child: BlocBuilder<MyWalksCubit, MyWalksState>(
                  builder: (context, state) {
                    if (state.isLoading && state.worlds.isEmpty) {
                      return const Center(
                        child: EverloreSessionLoader(
                          message: 'Gathering your walks',
                        ),
                      );
                    }
                    if (state.worlds.isEmpty) {
                      return EverloreEmptyState(
                        icon: Icons.map_outlined,
                        eyebrow: 'MY WALKS',
                        title: 'No walks authored yet',
                        message:
                            'Walkable worlds you own appear here. Release a draft and it shows on Explore.',
                      );
                    }
                    return CustomScrollView(
                      slivers: [
                        if (state.drafts.isNotEmpty) ...[
                          _header('${state.drafts.length} DRAFTS', EverloreTheme.ember),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (ctx, i) => _card(context, state, state.drafts[i]),
                                childCount: state.drafts.length,
                              ),
                            ),
                          ),
                        ],
                        if (state.published.isNotEmpty) ...[
                          _header(
                            '${state.published.length} PUBLISHED',
                            EverloreTheme.verdant,
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (ctx, i) =>
                                    _card(context, state, state.published[i]),
                                childCount: state.published.length,
                              ),
                            ),
                          ),
                        ],
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

  SliverToBoxAdapter _header(String label, Color color) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, MyWalksState state, WorldTemplate world) {
    return MyWorldCard(
      template: world,
      isPublishing: state.publishingIds.contains(world.id),
      onTap: () => enterRealmFromTemplate(
        context,
        templateId: world.id,
        worldTitle: world.title,
        interactiveWorldKey: world.interactiveWorldKey ?? world.slug,
      ),
      onPublish: world.isPublished
          ? null
          : () => _confirmPublish(context, world),
      onDelete: () => context.read<MyWalksCubit>().delete(world),
    );
  }

  void _confirmPublish(BuildContext context, WorldTemplate world) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        var isReleasing = false;
        String? releaseError;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: EverloreTheme.void2,
            title: const Row(
              children: [
                EvIcon(AppIcons.publish, size: 22),
                SizedBox(width: 8),
                Text(
                  'Release This Walk?',
                  style: TextStyle(color: EverloreTheme.parchment, fontSize: 17),
                ),
              ],
            ),
            content: Text(
              releaseError ??
                  '"${world.title}" will appear on Explore Walks for every adventurer.',
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
                            .read<MyWalksCubit>()
                            .publish(world);
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
                child: const Text(
                  'Release to Realm',
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
