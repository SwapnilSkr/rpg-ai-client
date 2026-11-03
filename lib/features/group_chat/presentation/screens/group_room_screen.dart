import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/nexus_theme.dart';
import '../../../../core/network/ws_manager.dart';
import '../../../../shared/widgets/everlore_notice.dart';
import '../../../../shared/widgets/everlore_session_loader.dart';
import '../../data/group_chat_gateway.dart';
import '../../models/group_chat_models.dart';
import '../../state/group_chat_cubit.dart';
import '../../state/group_chat_state.dart';
import '../widgets/actions_tab.dart';
import '../widgets/bond_sheet.dart';
import '../widgets/character_sheet.dart';
import '../widgets/group_composer.dart';
import '../widgets/group_message_list.dart';
import '../widgets/members_sheet.dart';
import 'direct_thread_screen.dart';

/// Main room screen for group chats, hosting Chat and Actions tabs.
class GroupRoomScreen extends StatefulWidget {
  final String instanceId;
  final String? title;
  final GroupChatCubit? cubit; // Optional for testing injection

  const GroupRoomScreen({
    super.key,
    required this.instanceId,
    this.title,
    this.cubit,
  });

  @override
  State<GroupRoomScreen> createState() => _GroupRoomScreenState();
}

class _GroupRoomScreenState extends State<GroupRoomScreen>
    with SingleTickerProviderStateMixin {
  late final GroupChatCubit _cubit;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.cubit != null) {
      _cubit = widget.cubit!;
    } else {
      _cubit = GroupChatCubit(
        instanceId: widget.instanceId,
        gateway: WsGroupChatGateway(WsManager()),
      );
      unawaited(_cubit.start());
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (widget.cubit == null) {
      _cubit.close();
    }
    super.dispose();
  }

  void _onStateError(BuildContext context, GroupChatError error) {
    switch (error) {
      case GroupChatError.insufficientInk:
        showEverloreNotice(
          context,
          'The story ink runs low. Restore your reserve to continue.',
          tone: NoticeTone.error,
        );
        _showInkOptions(context);
        break;
      case GroupChatError.offline:
        showEverloreNotice(
          context,
          'You are offline. Reconnecting…',
          tone: NoticeTone.info,
        );
        break;
      case GroupChatError.busy:
        showEverloreNotice(
          context,
          'Someone is already replying. One moment…',
          tone: NoticeTone.info,
        );
        break;
      case GroupChatError.rateLimited:
        showEverloreNotice(
          context,
          'Slow down a moment before sending again.',
          tone: NoticeTone.error,
        );
        break;
      case GroupChatError.signInRequired:
        showEverloreNotice(
          context,
          'Sign in to send messages.',
          tone: NoticeTone.error,
        );
        break;
      case GroupChatError.resting:
        showEverloreNotice(
          context,
          'The ink is resting. It will return soon.',
          tone: NoticeTone.info,
        );
        break;
      case GroupChatError.notFound:
        showEverloreNotice(
          context,
          'That conversation could not be found.',
          tone: NoticeTone.error,
        );
        break;
      case GroupChatError.rejected:
        showEverloreNotice(
          context,
          'That message could not be sent.',
          tone: NoticeTone.error,
        );
        break;
      case GroupChatError.failed:
        showEverloreNotice(
          context,
          'Could not complete that request.',
          tone: NoticeTone.error,
        );
        break;
    }
  }

  void _showInkOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: const BoxDecoration(
          color: EverloreTheme.void1,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(
            top: BorderSide(color: EverloreTheme.goldDim, width: 1.2),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: EverloreTheme.ash.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'The Ink Runs Low',
              style: EverloreTheme.cardTitle.copyWith(
                color: EverloreTheme.parchment,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your ink reserve has run dry. Restore your Story Ink to keep the words flowing.',
              textAlign: TextAlign.center,
              style: EverloreTheme.bodyDim.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: EverloreTheme.goldDeep,
                foregroundColor: EverloreTheme.parchment,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.of(sheetContext).pop();
                context.push('/membership?source=ink');
              },
              child: Text(
                'RESTORE STORY INK',
                style: EverloreTheme.ui(
                  size: 13,
                  weight: FontWeight.w700,
                  spacing: 1.5,
                  color: EverloreTheme.parchment,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCharacterSheet(GroupMember member) {
    CharacterSheet.show(
      context,
      member: member,
      onMessage: () => _openDirectThread(member),
      onBond: () => BondSheet.show(context, cubit: _cubit, member: member),
    );
  }

  void _openDirectThread(GroupMember member) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DirectThreadScreen(cubit: _cubit, member: member),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<GroupChatCubit, GroupChatState>(
        bloc: _cubit,
        listenWhen: (prev, curr) => curr.error != null && prev.error != curr.error,
        listener: (context, state) {
          if (state.error != null) {
            _onStateError(context, state.error!);
          }
        },
        builder: (context, state) {
          if (state.load == GroupChatLoad.loading) {
            return const Scaffold(
              backgroundColor: EverloreTheme.void1,
              body: Center(
                child: EverloreSessionLoader(message: 'Entering chat'),
              ),
            );
          }

          if (state.load == GroupChatLoad.failed) {
            return Scaffold(
              backgroundColor: EverloreTheme.void1,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: EverloreTheme.ash,
                    size: 18,
                  ),
                  onPressed: () => context.canPop() ? context.pop() : context.go('/'),
                ),
              ),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off_rounded,
                        color: EverloreTheme.ash,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Could not open chat',
                        style: EverloreTheme.cardTitle.copyWith(
                          color: EverloreTheme.parchment,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The connection could not be established. Check your network and try again.',
                        textAlign: TextAlign.center,
                        style: EverloreTheme.bodyDim.copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: EverloreTheme.goldDeep,
                          foregroundColor: EverloreTheme.parchment,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _cubit.retryLoad,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final chatTitle = widget.title != null && widget.title!.isNotEmpty
              ? widget.title!
              : (state.members.isNotEmpty
                  ? state.members.map((m) => m.name).join(', ')
                  : 'Group Chat');

          final memberNamesSubtitle = state.members.map((m) => m.name).join(', ');

          final groupThread = state.thread(kGroupThreadKey);
          final typingMember = groupThread.typingId != null
              ? state.member(groupThread.typingId!)
              : null;
          final typingName = typingMember?.name;

          final memberMap = {for (final m in state.members) m.id: m};

          final failedSends = state.failedSends
              .where((f) => f.directWith == null || f.directWith == kGroupThreadKey)
              .toList();

          return Scaffold(
            backgroundColor: EverloreTheme.void1,
            appBar: AppBar(
              backgroundColor: EverloreTheme.void0,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: EverloreTheme.ash,
                  size: 18,
                ),
                onPressed: () => context.canPop() ? context.pop() : context.go('/'),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chatTitle,
                    style: EverloreTheme.screenTitle.copyWith(
                      fontSize: 16,
                      color: EverloreTheme.parchment,
                    ),
                  ),
                  if (memberNamesSubtitle.isNotEmpty)
                    Text(
                      memberNamesSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EverloreTheme.caption.copyWith(
                        fontSize: 11,
                        color: EverloreTheme.ash,
                      ),
                    ),
                ],
              ),
              actions: [
                IconButton(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(
                        Icons.people_alt_outlined,
                        color: EverloreTheme.parchment,
                        size: 22,
                      ),
                      if (state.pendingFrom.isNotEmpty)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: EverloreTheme.aetherBright,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  tooltip: 'Members',
                  onPressed: () => MembersSheet.show(
                    context,
                    cubit: _cubit,
                    state: state,
                    onSelectMember: _openCharacterSheet,
                  ),
                ),
              ],
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: EverloreTheme.gold,
                indicatorWeight: 2.2,
                dividerColor: EverloreTheme.gold.withValues(alpha: 0.12),
                labelColor: EverloreTheme.gold,
                unselectedLabelColor: EverloreTheme.ash,
                labelStyle: EverloreTheme.ui(
                  size: 13,
                  weight: FontWeight.w600,
                  spacing: 1.2,
                ),
                unselectedLabelStyle: EverloreTheme.ui(
                  size: 13,
                  weight: FontWeight.w500,
                ),
                tabs: const [
                  Tab(text: 'Chat'),
                  Tab(text: 'Actions'),
                ],
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                // Chat tab
                Column(
                  children: [
                    Expanded(
                      child: GroupMessageList(
                        lines: groupThread.lines,
                        memberMap: memberMap,
                        onCharacterTap: _openCharacterSheet,
                      ),
                    ),
                    GroupComposer(
                      members: state.members,
                      typingName: typingName,
                      failedSends: failedSends,
                      enableMentions: true,
                      enableActionToggle: true,
                      onSend: (text, isAction) {
                        _cubit.send(text, action: isAction);
                      },
                      onRetryFailed: _cubit.retryFailed,
                      onDiscardFailed: _cubit.discardFailed,
                    ),
                  ],
                ),
                // Actions tab
                ActionsTab(cubit: _cubit),
              ],
            ),
          );
        },
      ),
    );
  }
}
