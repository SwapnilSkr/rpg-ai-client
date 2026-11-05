import 'package:flutter/material.dart';

import '../../../../app/theme/nexus_theme.dart';
import '../../../../shared/widgets/everlore_notice.dart';
import '../../../../shared/widgets/everlore_session_loader.dart';
import '../../state/group_chat_state.dart';

/// Whether the Rewind item may be offered right now: nothing is being written
/// or waiting, and no rewind is running.
bool canRewindGroup(GroupChatState state) =>
    !state.rewinding && !state.turnInFlight && state.queuedSends == 0;

/// Covers the chat while a rewind runs: it blocks taps and typing, and keeps
/// the old lines from reading as already gone if the rewind fails.
class GroupRewindVeil extends StatelessWidget {
  final bool active;

  const GroupRewindVeil({super.key, required this.active});

  @override
  Widget build(BuildContext context) {
    if (!active) return const SizedBox.shrink();
    return Positioned.fill(
      child: AbsorbPointer(
        child: ColoredBox(
          color: EverloreTheme.void0.withValues(alpha: 0.82),
          child: const Center(
            child: EverloreSessionLoader(message: 'Rewinding the chat'),
          ),
        ),
      ),
    );
  }
}

/// The plain notice for a rewind that did not go through. Only the screen on
/// top shows it, so a room under a direct thread does not repeat it.
void showGroupRewindError(BuildContext context, GroupChatError error) {
  if (ModalRoute.of(context)?.isCurrent == false) return;
  final message = switch (error) {
    GroupChatError.busy => 'Wait for the reply to finish, then try again.',
    GroupChatError.offline => 'You are offline. Try again once you are back.',
    GroupChatError.signInRequired => 'Sign in to rewind this chat.',
    _ => 'Could not rewind the chat. Please try again.',
  };
  showEverloreNotice(context, message, tone: NoticeTone.error);
}
