import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/nexus_theme.dart';
import '../../../../core/guide/guide_anchor.dart';
import '../../../../core/guide/guide_flows.dart';
import '../../../../core/guide/guide_ids.dart';
import '../../../../core/guide/guide_trigger.dart';
import '../../models/group_chat_models.dart';
import '../../state/group_chat_cubit.dart';
import '../../state/group_chat_state.dart';

/// Actions tab listing narrated actions newest first with infinite scroll paging.
class ActionsTab extends StatefulWidget {
  final GroupChatCubit cubit;

  const ActionsTab({super.key, required this.cubit});

  @override
  State<ActionsTab> createState() => _ActionsTabState();
}

class _ActionsTabState extends State<ActionsTab> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    widget.cubit.loadActions();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 300) {
      final state = widget.cubit.state;
      if (state.actionsNext != null && !state.actionsLoading) {
        widget.cubit.loadMoreActions();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GroupChatCubit, GroupChatState>(
      bloc: widget.cubit,
      builder: (context, state) {
        if (state.actionsLoading && state.actions.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
              color: EverloreTheme.gold,
              strokeWidth: 2,
            ),
          );
        }

        if (state.actions.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                decoration: BoxDecoration(
                  color: EverloreTheme.void0.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome_outlined,
                      color: EverloreTheme.goldDim,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No actions yet',
                      style: EverloreTheme.cardTitle.copyWith(
                        color: EverloreTheme.parchment,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Say what you do in the chat, and they'll react.",
                      textAlign: TextAlign.center,
                      style: EverloreTheme.bodyDim.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return GuideOnEnter(
          flow: GuideFlows.groupActions,
          enabled: !state.actionsLoading && state.actions.isNotEmpty,
          child: RefreshIndicator(
            color: EverloreTheme.gold,
            backgroundColor: EverloreTheme.void2,
            onRefresh: () => widget.cubit.loadActions(),
            child: ListView.separated(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: state.actions.length + (state.actionsLoading ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index >= state.actions.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: EverloreTheme.gold,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  );
                }

                final action = state.actions[index];
                return guideAnchorIf(
                  index == 0,
                  GuideIds.groupFirstAction,
                  _ActionCard(action: action),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  final GroupAction action;

  const _ActionCard({required this.action});

  String _formatDate(DateTime? at) {
    if (at == null) return '';
    final local = at.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = _formatDate(action.at);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EverloreTheme.void2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: EverloreTheme.goldDim.withValues(alpha: 0.25),
          width: 0.9,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: EverloreTheme.goldDim,
                size: 15,
              ),
              const SizedBox(width: 6),
              Text(
                'ACTION',
                style: EverloreTheme.caption.copyWith(
                  color: EverloreTheme.goldDim,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              if (timeStr.isNotEmpty)
                Text(
                  timeStr,
                  style: EverloreTheme.caption.copyWith(
                    color: EverloreTheme.ash,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            action.text,
            style: EverloreTheme.aiText.copyWith(
              fontSize: 15,
              height: 1.45,
              fontStyle: FontStyle.italic,
              color: EverloreTheme.parchment,
            ),
          ),
        ],
      ),
    );
  }
}
