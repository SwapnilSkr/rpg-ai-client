import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/nexus_theme.dart';
import '../../../../shared/widgets/everlore_top_bar.dart';
import '../../state/notifications_cubit.dart';
import '../../state/notifications_state.dart';

/// A quiet bell in the top bar headers (Realms and Chats).
/// A small gold dot at the top right means unread notifications are waiting.
class NotificationsBellButton extends StatelessWidget {
  final NotificationsCubit? cubit;

  const NotificationsBellButton({super.key, this.cubit});

  @override
  Widget build(BuildContext context) {
    NotificationsCubit? effectiveCubit = cubit;
    if (effectiveCubit == null) {
      try {
        effectiveCubit = context.read<NotificationsCubit>();
      } catch (_) {
        effectiveCubit = null;
      }
    }

    if (effectiveCubit == null) {
      return EverloreTopBarIcon(
        icon: Icons.notifications_none_rounded,
        tooltip: 'Notifications',
        onTap: () => context.push('/notifications'),
      );
    }

    return BlocBuilder<NotificationsCubit, NotificationsState>(
      bloc: effectiveCubit,
      buildWhen: (previous, current) => previous.hasUnread != current.hasUnread,
      builder: (context, state) {
        return Stack(
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
                        BoxShadow(color: EverloreTheme.goldGlow, blurRadius: 4),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
