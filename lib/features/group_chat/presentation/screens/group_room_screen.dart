import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/nexus_theme.dart';
import '../../../../core/notifications/on_screen.dart';
import '../../../../core/network/ws_manager.dart';
import '../../../../shared/widgets/everlore_notice.dart';
import '../../../../shared/widgets/everlore_session_loader.dart';
import '../../../play/presentation/widgets/anchored_menu_popup.dart';
import '../../data/group_chat_gateway.dart';
import '../../models/group_chat_models.dart';
import '../../state/chats_cubit.dart';
import '../../state/group_chat_cubit.dart';
import '../../state/group_chat_state.dart';
import '../widgets/actions_tab.dart';
import '../widgets/bond_sheet.dart';
import '../widgets/character_sheet.dart';
import '../widgets/group_chat_backdrop.dart';
import '../widgets/group_composer.dart';
import '../widgets/group_message_list.dart';
import '../widgets/group_rewind.dart';
import '../widgets/member_avatar.dart';
import '../widgets/members_sheet.dart';
import '../widgets/push_ask_sheet.dart';
import 'direct_thread_screen.dart';

/// Main room screen for group chats, hosting Chat and Actions tabs.
class GroupRoomScreen extends StatefulWidget {
  final String instanceId;
  final String? title;
  final String? initialMemberId;
  final GroupChatCubit? cubit; // Optional for testing injection

  const GroupRoomScreen({
    super.key,
    required this.instanceId,
    this.title,
    this.initialMemberId,
    this.cubit,
  });

  @override
  State<GroupRoomScreen> createState() => _GroupRoomScreenState();
}

class _GroupRoomScreenState extends State<GroupRoomScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey _composerKey = GlobalKey();
  late final GroupChatCubit _cubit;
  late final TabController _tabController;
  late final ChatsCubit _chats;
  bool _openedDirectThreadOnce = false;
  StreamSubscription<void>? _pushAskSub;

  double? get _composerTop => globalRectOf(_composerKey.currentContext)?.top;

  @override
  void initState() {
    super.initState();
    // Kept in a field: a context can't be read once the State is going away.
    _chats = context.read<ChatsCubit>();
    OnScreen.instance.enter(this, Place.room(widget.instanceId));
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
    _pushAskSub = _cubit.pushAskDue.listen((_) {
      if (mounted) unawaited(PushAskSheet.show(context));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _callMarkOpened();
      // A cubit that already holds the cast raises no state change to listen to.
      if (mounted) _openInitialThread(_cubit.state);
    });
  }

  /// A thread opened from the Chats list sits on top of this room. Once, and
  /// only when the cast is known.
  void _openInitialThread(GroupChatState state) {
    final id = widget.initialMemberId;
    if (_openedDirectThreadOnce || id == null || state.members.isEmpty) return;
    final target = state.member(id);
    if (target == null) return;
    _openedDirectThreadOnce = true;
    _openDirectThread(target, closeRoomAfter: true);
  }

  void _callMarkOpened() {
    // Opened only to carry a direct thread, this room was never read.
    if (widget.initialMemberId != null) return;
    unawaited(_chats.markOpened(widget.instanceId));
  }

  @override
  void dispose() {
    OnScreen.instance.leave(this);
    unawaited(_pushAskSub?.cancel());
    _tabController.dispose();
    if (widget.cubit == null) {
      _cubit.close();
    }
    _callMarkOpened();
    unawaited(_chats.refresh());
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

  void _rewindTo(GroupLine line) {
    final sequence = line.sequence;
    if (sequence == null) return;
    // The Chats list must not keep a removed message as its last line.
    unawaited(_cubit.rewind(sequence).whenComplete(_chats.refresh));
  }

  void _requestSelfie(GroupLine line) {
    unawaited(_cubit.requestSelfie(line));
  }

  void _openCharacterSheet(GroupMember member) {
    CharacterSheet.show(
      context,
      member: member,
      onMessage: () => _openDirectThread(member),
      onBond: () => BondSheet.show(context, cubit: _cubit, member: member),
    );
  }

  /// [closeRoomAfter]: the player asked for the thread, not the room, so
  /// leaving the thread returns to wherever they came from.
  void _openDirectThread(GroupMember member, {bool closeRoomAfter = false}) {
    unawaited(_chats.markOpened(widget.instanceId, memberId: member.id));
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => DirectThreadScreen(cubit: _cubit, member: member),
      ),
    )
        .then((_) {
      unawaited(_chats.markOpened(widget.instanceId, memberId: member.id));
      unawaited(_chats.refresh());
      if (closeRoomAfter && mounted && context.canPop()) context.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<GroupChatCubit, GroupChatState>(
        bloc: _cubit,
        listenWhen: (prev, curr) =>
            (curr.error != null && prev.error != curr.error) ||
            (curr.rewindError != null && prev.rewindError != curr.rewindError) ||
            (!_openedDirectThreadOnce &&
                widget.initialMemberId != null &&
                curr.members.isNotEmpty),
        listener: (context, state) {
          if (state.error != null) {
            _onStateError(context, state.error!);
          }
          if (state.rewindError != null) {
            showGroupRewindError(context, state.rewindError!);
          }
          if (!_openedDirectThreadOnce && widget.initialMemberId != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _openInitialThread(state);
            });
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

          final chatTitle = widget.title?.isNotEmpty == true
              ? widget.title!
              : state.title;

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

          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: GroupChatBackdrop(
                  imageUrl: state.imageUrl,
                ),
              ),
              Scaffold(
                backgroundColor: Colors.transparent,
                appBar: AppBar(
                  backgroundColor: EverloreTheme.void0.withValues(alpha: kGroupChromeAlpha),
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
                    GestureDetector(
                      onTap: () => MembersSheet.show(
                        context,
                        cubit: _cubit,
                        state: state,
                        onSelectMember: _openCharacterSheet,
                      ),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Center(
                          child: _buildHeaderAvatars(context, state),
                        ),
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
                            someoneTyping: typingName != null,
                            composerTop: () => _composerTop,
                            onRewindLine: canRewindGroup(state) ? _rewindTo : null,
                            onRequestSelfie: !state.rewinding ? _requestSelfie : null,
                          ),
                        ),
                        GroupComposer(
                          key: _composerKey,
                          members: state.members,
                          typingName: typingName,
                          failedSends: failedSends,
                          replyIdeas: state.replyIdeasFor(),
                          onSendIdea: (idea) => _cubit.sendIdea(idea),
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
              ),
              GroupRewindVeil(active: state.rewinding),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderAvatars(BuildContext context, GroupChatState state) {
    final members = state.members;
    if (members.isEmpty) {
      return const Icon(
        Icons.people_alt_outlined,
        color: EverloreTheme.parchment,
        size: 22,
      );
    }
    final displayMembers = members.take(5).toList();
    final extraCount = members.length - displayMembers.length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 28,
          width: displayMembers.length * 18.0 +
              10.0 +
              (extraCount > 0 ? 24.0 : 0.0),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              for (var i = 0; i < displayMembers.length; i++)
                Positioned(
                  left: i * 18.0,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: EverloreTheme.void0,
                        width: 1.5,
                      ),
                    ),
                    child: MemberAvatar(
                      member: displayMembers[i],
                      size: 24,
                    ),
                  ),
                ),
              if (extraCount > 0)
                Positioned(
                  left: displayMembers.length * 18.0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: EverloreTheme.void3,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: EverloreTheme.void0,
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '+$extraCount',
                      style: EverloreTheme.caption.copyWith(
                        color: EverloreTheme.parchment,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (state.pendingFrom.isNotEmpty) ...[
          const SizedBox(width: 4),
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: EverloreTheme.aetherBright,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    );
  }
}
