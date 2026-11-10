import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:everlore/app/theme/nexus_theme.dart';
import 'package:everlore/features/creator/presentation/widgets/world_status_chip.dart';
import 'package:everlore/features/group_chat/state/my_groups_cubit.dart';
import 'package:everlore/shared/models/world_template.dart';
import 'package:everlore/shared/widgets/everlore_empty_state.dart';
import 'package:everlore/shared/widgets/everlore_notice.dart';
import 'package:everlore/shared/widgets/everlore_top_bar.dart';
import '../widgets/create_group/group_delete_sheet.dart';
import '../widgets/group_cover_card.dart';

/// Screen listing the player's own created groups ("Your groups").
class MyGroupsScreen extends StatefulWidget {
  const MyGroupsScreen({super.key});

  @override
  State<MyGroupsScreen> createState() => _MyGroupsScreenState();
}

class _MyGroupsScreenState extends State<MyGroupsScreen> {
  final ScrollController _scrollController = ScrollController();

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
    if (_scrollController.position.extentAfter < 300) {
      context.read<MyGroupsCubit>().loadMore();
    }
  }

  Future<void> _confirmDelete(BuildContext context, String id) async {
    final confirmed = await showGroupDeleteSheet(context);
    if (confirmed && context.mounted) {
      await context.read<MyGroupsCubit>().delete(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EverloreTheme.void1,
      body: Column(
        children: [
          EverloreTopBar(
            title: 'Your groups',
            showBack: true,
            showProfile: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.add, color: EverloreTheme.gold),
                onPressed: () => context.push('/groups/new'),
                tooltip: 'Create a group',
              ),
            ],
          ),
          Expanded(
            child: BlocConsumer<MyGroupsCubit, MyGroupsState>(
              listener: (context, state) {
                if (state.error != null) {
                  showEverloreNotice(
                    context,
                    state.error!,
                    tone: NoticeTone.error,
                  );
                  context.read<MyGroupsCubit>().clearError();
                }
              },
              builder: (context, state) {
                if (state.isLoading && state.groups.isEmpty) {
                  return const Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: EverloreTheme.gold,
                      ),
                    ),
                  );
                }

                if (!state.isLoading && state.groups.isEmpty) {
                  return EverloreEmptyState(
                    icon: Icons.groups_outlined,
                    title: "You haven't made a group yet.",
                    message: 'Write a few people and they start talking.',
                    actionLabel: 'Create a group',
                    onAction: () => context.push('/groups/new'),
                    artAsset: 'assets/art/forge-group-cover.webp',
                    fullBleedArt: true,
                  );
                }

                return RefreshIndicator(
                  color: EverloreTheme.gold,
                  backgroundColor: EverloreTheme.void2,
                  onRefresh: () => context.read<MyGroupsCubit>().load(),
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 220,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 132 / 198,
                              ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final group = state.groups[index];
                            return _GroupGridCard(
                              group: group,
                              isDeleting: state.deletingIds.contains(group.id),
                              onTap: () =>
                                  context.push('/groups/${group.id}/edit'),
                              onDelete: () => _confirmDelete(context, group.id),
                            );
                          }, childCount: state.groups.length),
                        ),
                      ),
                      if (state.isLoadingMore)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: EverloreTheme.gold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupGridCard extends StatelessWidget {
  final WorldTemplate group;
  final bool isDeleting;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _GroupGridCard({
    required this.group,
    required this.isDeleting,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GroupCoverCard(
          template: group,
          fallbackToMosaic: true,
          onTap: isDeleting ? null : onTap,
          onLongPress: isDeleting ? null : onDelete,
        ),
        Positioned(
          top: 8,
          left: 8,
          // The chip's own fill is nearly clear, which vanishes over a painting.
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: EverloreTheme.void0.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(6),
            ),
            child: WorldStatusChip(
              template: group,
              isWorking: isDeleting,
              showNote: false,
            ),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: isDeleting ? null : onDelete,
                child: Center(
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: EverloreTheme.void0.withValues(alpha: 0.6),
                    ),
                    child: const Icon(
                      Icons.more_vert,
                      size: 18,
                      color: EverloreTheme.parchment,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
