import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/nexus_theme.dart';
import '../../../../core/guide/guide_anchor.dart';
import '../../../../core/guide/guide_controller.dart';
import '../../../../core/guide/guide_flows.dart';
import '../../../../core/guide/guide_ids.dart';
import '../../../../shared/widgets/everlore_top_bar.dart';
import '../../state/notifications_cubit.dart';
import '../../state/notifications_state.dart';

/// A quiet bell in the top bar headers (Realms and Chats).
/// A small gold dot at the top right means unread notifications are waiting.
class NotificationsBellButton extends StatefulWidget {
  final NotificationsCubit? cubit;

  const NotificationsBellButton({super.key, this.cubit});

  @override
  State<NotificationsBellButton> createState() =>
      _NotificationsBellButtonState();
}

class _NotificationsBellButtonState extends State<NotificationsBellButton> {
  @override
  Widget build(BuildContext context) {
    NotificationsCubit? effectiveCubit = widget.cubit;
    if (effectiveCubit == null) {
      try {
        effectiveCubit = context.read<NotificationsCubit>();
      } catch (_) {
        effectiveCubit = null;
      }
    }

    if (effectiveCubit == null) {
      return GuideAnchor(
        id: GuideIds.notificationsBell,
        child: EverloreTopBarIcon(
          icon: Icons.notifications_none_rounded,
          tooltip: 'Notifications',
          onTap: () => context.push('/notifications'),
        ),
      );
    }

    return BlocBuilder<NotificationsCubit, NotificationsState>(
      bloc: effectiveCubit,
      buildWhen: (previous, current) => previous.hasUnread != current.hasUnread,
      builder: (context, state) {
        if (state.hasUnread) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _maybeGuide(state);
          });
        }
        return GuideAnchor(
          id: GuideIds.notificationsBell,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              EverloreTopBarIcon(
                icon: Icons.notifications_none_rounded,
                tooltip: 'Notifications',
                onTap: () => context.push('/notifications'),
              ),
              if (state.hasUnread)
                Positioned(
                  top: 2,
                  right: 2,
                  child: IgnorePointer(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: EverloreTheme.gold,
                        boxShadow: [
                          BoxShadow(
                            color: EverloreTheme.goldGlow,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _maybeGuide(NotificationsState state) {
    if (!state.hasUnread) return;
    if (guide.canAutoStart(GuideFlows.notifications)) {
      guide.maybeStart(
        GuideFlows.notifications,
        delay: const Duration(milliseconds: 400),
      );
    }
  }
}
