import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:everlore/app/theme/nexus_theme.dart';
import 'package:everlore/features/creator/presentation/widgets/world_status_chip.dart';
import 'package:everlore/features/group_chat/state/my_groups_cubit.dart';
import 'package:everlore/shared/models/world_template.dart';
import 'package:everlore/shared/widgets/everlore_network_image.dart';
import 'package:everlore/shared/widgets/everlore_notice.dart';
import 'package:everlore/shared/widgets/everlore_top_bar.dart';
import '../widgets/create_group/group_delete_sheet.dart';

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
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "You haven't made a group yet.",
                            textAlign: TextAlign.center,
                            style: EverloreTheme.aiText.copyWith(
                              fontSize: 16,
                              color: EverloreTheme.parchment,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: () => context.push('/groups/new'),
                            icon: const Icon(
                              Icons.add,
                              size: 16,
                              color: EverloreTheme.void0,
                            ),
                            label: Text(
                              'Create a group',
                              style: EverloreTheme.ui(
                                size: 14,
                                weight: FontWeight.w700,
                                color: EverloreTheme.void0,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: EverloreTheme.gold,
                              foregroundColor: EverloreTheme.void0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  color: EverloreTheme.gold,
                  backgroundColor: EverloreTheme.void2,
                  onRefresh: () => context.read<MyGroupsCubit>().load(),
                  child: ListView.separated(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    itemCount:
                        state.groups.length + (state.isLoadingMore ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      if (index >= state.groups.length) {
                        return const Padding(
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
                        );
                      }

                      final group = state.groups[index];
                      return _GroupTile(
                        group: group,
                        isDeleting: state.deletingIds.contains(group.id),
                        onTap: () => context.push('/groups/${group.id}/edit'),
                        onDelete: () => _confirmDelete(context, group.id),
                      );
                    },
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

class _GroupTile extends StatelessWidget {
  final WorldTemplate group;
  final bool isDeleting;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _GroupTile({
    required this.group,
    required this.isDeleting,
    required this.onTap,
    required this.onDelete,
  });

  String? _resolveImageUrl() {
    if (group.imageThumbUrl.isNotEmpty) return group.imageThumbUrl;
    if (group.imageUrl.isNotEmpty) return group.imageUrl;
    if (group.members.isNotEmpty) {
      final m = group.members.first;
      return m.portraitThumbUrl ?? m.portraitUrl;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _resolveImageUrl();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDeleting ? null : onTap,
        onLongPress: isDeleting ? null : onDelete,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: EverloreTheme.void2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: EverloreTheme.goldDim.withValues(alpha: 0.16),
            ),
          ),
          child: Row(
            children: [
              // Cover or first face
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 50,
                  height: 50,
                  color: EverloreTheme.void3,
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? EverloreNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          alignment: const Alignment(0, -0.5),
                        )
                      : const Center(
                          child: Icon(
                            Icons.groups,
                            size: 24,
                            color: EverloreTheme.ash,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),

              // Title and status chip
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EverloreTheme.ui(
                        size: 15,
                        weight: FontWeight.w600,
                        color: EverloreTheme.parchment,
                      ),
                    ),
                    const SizedBox(height: 6),
                    WorldStatusChip(
                      template: group,
                      isWorking: isDeleting,
                      showNote: false,
                    ),
                  ],
                ),
              ),

              // Overflow / action
              IconButton(
                icon: const Icon(
                  Icons.more_vert,
                  color: EverloreTheme.ash,
                  size: 20,
                ),
                onPressed: isDeleting ? null : onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
