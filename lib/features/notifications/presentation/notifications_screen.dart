import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/nexus_theme.dart';
import '../models/app_notification.dart';
import '../state/notifications_cubit.dart';
import '../state/notifications_state.dart';

/// A plain list for now: the real look comes later, on top of the same state.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationsCubit>().load();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 400) {
      context.read<NotificationsCubit>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EverloreTheme.void1,
      appBar: AppBar(
        backgroundColor: EverloreTheme.void1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text('Notifications', style: EverloreTheme.screenTitle),
        actions: [
          BlocBuilder<NotificationsCubit, NotificationsState>(
            buildWhen: (a, b) => a.hasUnread != b.hasUnread,
            builder: (context, state) => state.hasUnread
                ? TextButton(
                    onPressed: () =>
                        context.read<NotificationsCubit>().markAllRead(),
                    child: const Text('Mark all read'),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: BlocBuilder<NotificationsCubit, NotificationsState>(
        builder: (context, state) {
          if (state.items.isEmpty) {
            return Center(
              child: Text(
                state.isLoading || !state.hasLoaded
                    ? (state.hasError
                          ? 'Could not load. Pull to try again.'
                          : '')
                    : 'Nothing new yet.',
                style: EverloreTheme.aiText.copyWith(color: EverloreTheme.ash),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => context.read<NotificationsCubit>().load(),
            child: ListView.builder(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: state.items.length,
              itemBuilder: (context, i) => _Row(item: state.items[i]),
            ),
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final AppNotification item;
  const _Row({required this.item});

  @override
  Widget build(BuildContext context) {
    final unread = item.isUnread;
    return ListTile(
      onTap: () => context.read<NotificationsCubit>().open(item),
      title: Text(
        item.title,
        style: EverloreTheme.aiText.copyWith(
          color: unread ? EverloreTheme.parchment : EverloreTheme.ash,
        ),
      ),
      subtitle: Text(
        item.body,
        style: EverloreTheme.aiText.copyWith(
          color: EverloreTheme.ash,
          fontSize: 14,
        ),
      ),
      trailing: unread
          ? const Icon(Icons.circle, size: 8, color: EverloreTheme.gold)
          : null,
    );
  }
}
