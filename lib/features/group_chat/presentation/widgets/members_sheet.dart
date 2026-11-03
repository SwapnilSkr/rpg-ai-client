import 'package:flutter/material.dart';

import '../../../../app/layout/responsive.dart';
import '../../../../app/theme/nexus_theme.dart';
import '../../models/group_chat_models.dart';
import '../../state/group_chat_cubit.dart';
import '../../state/group_chat_state.dart';
import 'member_avatar.dart';

/// Sheet listing every member with last direct message and pending indicator.
class MembersSheet extends StatelessWidget {
  final GroupChatCubit cubit;
  final GroupChatState state;
  final ValueChanged<GroupMember> onSelectMember;

  const MembersSheet({
    super.key,
    required this.cubit,
    required this.state,
    required this.onSelectMember,
  });

  static Future<void> show(
    BuildContext context, {
    required GroupChatCubit cubit,
    required GroupChatState state,
    required ValueChanged<GroupMember> onSelectMember,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MembersSheet(
        cubit: cubit,
        state: state,
        onSelectMember: onSelectMember,
      ),
    );
  }

  String _lastDirectLine(String memberId) {
    for (final summary in state.threadSummaries) {
      if (summary.memberId == memberId) {
        if (summary.lastLine.trim().isNotEmpty) return summary.lastLine;
      }
    }
    return 'No direct messages yet';
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = context.layout.sheetBodyMaxHeight(chrome: 70);

    return Container(
      decoration: const BoxDecoration(
        color: EverloreTheme.void1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(
          top: BorderSide(color: EverloreTheme.goldDim, width: 1.2),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: EverloreTheme.ash.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Text('MEMBERS', style: EverloreTheme.sectionHeader),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: EverloreTheme.ash),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: EverloreTheme.white10, height: 1),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: state.members.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No members found',
                          style: EverloreTheme.bodyDim,
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: state.members.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: EverloreTheme.white10, height: 1),
                      itemBuilder: (context, index) {
                        final member = state.members[index];
                        final hasPending = state.pendingFrom.contains(member.id);
                        final lastLine = _lastDirectLine(member.id);

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 4,
                          ),
                          leading: MemberAvatar(
                            member: member,
                            size: 44,
                            hasPending: hasPending,
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  member.name,
                                  style: EverloreTheme.ui(
                                    size: 15,
                                    weight: FontWeight.w600,
                                    color: EverloreTheme.parchment,
                                  ),
                                ),
                              ),
                              if (hasPending)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: EverloreTheme.aetherBright
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: EverloreTheme.aetherBright,
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    'Waiting',
                                    style: EverloreTheme.caption.copyWith(
                                      color: EverloreTheme.aetherBright,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            lastLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: EverloreTheme.caption.copyWith(
                              color: hasPending
                                  ? EverloreTheme.parchment
                                  : EverloreTheme.ash,
                              fontStyle: lastLine == 'No direct messages yet'
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: EverloreTheme.ash,
                            size: 20,
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            onSelectMember(member);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
