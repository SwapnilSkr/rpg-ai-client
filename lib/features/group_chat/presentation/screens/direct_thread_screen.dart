import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/nexus_theme.dart';
import '../../../play/presentation/widgets/anchored_menu_popup.dart';
import '../../models/group_chat_models.dart';
import '../../state/chats_cubit.dart';
import '../../state/group_chat_cubit.dart';
import '../../state/group_chat_state.dart';
import '../widgets/bond_sheet.dart';
import '../widgets/group_chat_backdrop.dart';
import '../widgets/group_composer.dart';
import '../widgets/group_message_list.dart';
import '../widgets/group_rewind.dart';
import '../widgets/member_avatar.dart';

/// Direct thread screen with one character: same list and composer, no `@` and no action toggle.
class DirectThreadScreen extends StatefulWidget {
  final GroupChatCubit cubit;
  final GroupMember member;

  const DirectThreadScreen({
    super.key,
    required this.cubit,
    required this.member,
  });

  @override
  State<DirectThreadScreen> createState() => _DirectThreadScreenState();
}

class _DirectThreadScreenState extends State<DirectThreadScreen> {
  final GlobalKey _composerKey = GlobalKey();
  late final ChatsCubit _chats;

  double? get _composerTop => globalRectOf(_composerKey.currentContext)?.top;

  @override
  void initState() {
    super.initState();
    // Kept in a field: a context can't be read once the State is going away.
    _chats = context.read<ChatsCubit>();
    widget.cubit.selectThread(widget.member.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        _chats.markOpened(
          widget.cubit.instanceId,
          memberId: widget.member.id,
        ),
      );
    });
  }

  @override
  void dispose() {
    widget.cubit.selectThread(kGroupThreadKey);
    unawaited(
      _chats.markOpened(widget.cubit.instanceId, memberId: widget.member.id),
    );
    unawaited(_chats.refresh());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GroupChatCubit, GroupChatState>(
      bloc: widget.cubit,
      listenWhen: (prev, curr) =>
          curr.rewindError != null && prev.rewindError != curr.rewindError,
      listener: (context, state) =>
          showGroupRewindError(context, state.rewindError!),
      builder: (context, state) {
        final thread = state.thread(widget.member.id);
        final typingName = thread.typingId == widget.member.id
            ? widget.member.name
            : null;
        final failedSends = state.failedSends
            .where((f) => f.directWith == widget.member.id)
            .toList();

        final memberMap = {widget.member.id: widget.member};

        final portrait = widget.member.portraitUrl?.trim();
        final hasPortrait = portrait != null && portrait.isNotEmpty;
        final backdropUrl = hasPortrait ? portrait : state.imageUrl;
        final backdropAlignment = hasPortrait
            ? const Alignment(0, -0.6)
            : Alignment.center;

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: GroupChatBackdrop(
                imageUrl: backdropUrl,
                alignment: backdropAlignment,
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
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: Row(
                  children: [
                    MemberAvatar(member: widget.member, size: 34),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.member.name,
                            style: EverloreTheme.screenTitle.copyWith(
                              fontSize: 16,
                              color: EverloreTheme.parchment,
                            ),
                          ),
                          if (widget.member.role.isNotEmpty)
                            Text(
                              widget.member.role,
                              style: EverloreTheme.caption.copyWith(
                                fontSize: 11,
                                color: EverloreTheme.ash,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(
                      Icons.favorite_outline_rounded,
                      color: EverloreTheme.gold,
                    ),
                    tooltip: 'Bond',
                    onPressed: () => BondSheet.show(
                      context,
                      cubit: widget.cubit,
                      member: widget.member,
                    ),
                  ),
                ],
              ),
              body: Column(
                children: [
                  Expanded(
                    child: GroupMessageList(
                      lines: thread.lines,
                      memberMap: memberMap,
                      composerTop: () => _composerTop,
                      onRewindLine: canRewindGroup(state) ? _rewindTo : null,
                      onCharacterTap: (_) => BondSheet.show(
                        context,
                        cubit: widget.cubit,
                        member: widget.member,
                      ),
                    ),
                  ),
                  GroupComposer(
                    key: _composerKey,
                    members: [widget.member],
                    typingName: typingName,
                    failedSends: failedSends,
                    enableMentions: false, // No @ in direct threads
                    enableActionToggle: false, // No action toggle in direct threads
                    onSend: (text, _) {
                      widget.cubit.send(text, directWith: widget.member.id);
                    },
                    onRetryFailed: widget.cubit.retryFailed,
                    onDiscardFailed: widget.cubit.discardFailed,
                  ),
                ],
              ),
            ),
            GroupRewindVeil(active: state.rewinding),
          ],
        );
      },
    );
  }

  void _rewindTo(GroupLine line) {
    final sequence = line.sequence;
    if (sequence == null) return;
    // The Chats list must not keep a removed message as its last line.
    unawaited(widget.cubit.rewind(sequence).whenComplete(_chats.refresh));
  }
}
