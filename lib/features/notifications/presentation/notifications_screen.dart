import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/nexus_theme.dart';
import '../../../shared/widgets/everlore_network_image.dart';
import '../models/app_notification.dart';
import '../state/notifications_cubit.dart';
import '../state/notifications_state.dart';

/// The notifications screen: lists events that arrived while the player was elsewhere,
/// grouped into Today and Earlier, with quiet, generous spacing.
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
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: EverloreTheme.ash,
          ),
          tooltip: 'Back',
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
                    child: Text(
                      'Mark all read',
                      style: EverloreTheme.ui(
                        size: 13,
                        weight: FontWeight.w600,
                        color: EverloreTheme.goldDim,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: BlocBuilder<NotificationsCubit, NotificationsState>(
        builder: (context, state) {
          if (state.items.isEmpty) {
            if (state.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Could not load notifications.',
                        textAlign: TextAlign.center,
                        style: EverloreTheme.aiText.copyWith(
                          color: EverloreTheme.ash,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () =>
                            context.read<NotificationsCubit>().load(),
                        child: Text(
                          'Try again',
                          style: EverloreTheme.ui(
                            size: 14,
                            weight: FontWeight.w600,
                            color: EverloreTheme.goldDim,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (state.isLoading || !state.hasLoaded) {
              return const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: EverloreTheme.goldDim,
                ),
              );
            }

            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Nothing has happened while you were away.',
                  textAlign: TextAlign.center,
                  style: EverloreTheme.aiText.copyWith(
                    color: EverloreTheme.ash,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ),
            );
          }

          final now = DateTime.now();
          final todayStart = DateTime(now.year, now.month, now.day);
          final today = <AppNotification>[];
          final earlier = <AppNotification>[];

          for (final item in state.items) {
            final local = item.createdAt.toLocal();
            final itemDay = DateTime(local.year, local.month, local.day);
            if (!itemDay.isBefore(todayStart)) {
              today.add(item);
            } else {
              earlier.add(item);
            }
          }

          return RefreshIndicator(
            color: EverloreTheme.gold,
            backgroundColor: EverloreTheme.void2,
            onRefresh: () => context.read<NotificationsCubit>().load(),
            child: ListView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                if (today.isNotEmpty) ...[
                  _SectionHeader(title: 'Today'),
                  for (final item in today) _NotificationRow(item: item),
                ],
                if (earlier.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'Earlier',
                    topPadding: today.isNotEmpty ? 24 : 8,
                  ),
                  for (final item in earlier) _NotificationRow(item: item),
                ],
                if (state.isLoadingMore)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: EverloreTheme.goldDim,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final double topPadding;

  const _SectionHeader({required this.title, this.topPadding = 8});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(0, topPadding, 0, 10),
      child: Text(title, style: EverloreTheme.sectionHeader),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  final AppNotification item;

  const _NotificationRow({required this.item});

  String _formatRelativeTime(DateTime created) {
    final now = DateTime.now();
    final local = created.toLocal();
    final diff = now.difference(local);

    if (diff.isNegative || diff.inSeconds < 60) {
      return '1 min';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min';
    }

    final today = DateTime(now.year, now.month, now.day);
    final itemDay = DateTime(local.year, local.month, local.day);
    final daysDiff = today.difference(itemDay).inDays;

    if (daysDiff == 0) {
      return '${diff.inHours}h';
    }
    if (daysDiff == 1) {
      return 'Yesterday';
    }
    if (now.year == local.year) {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[local.month - 1]} ${local.day}';
    }
    return '${local.month}/${local.day}/${local.year % 100}';
  }

  @override
  Widget build(BuildContext context) {
    final unread = item.isUnread;
    final isFilm = item.kind == NotificationKind.filmReady;

    return Semantics(
      button: true,
      label: '${item.title}, ${item.body}',
      child: GestureDetector(
        onTap: () => context.read<NotificationsCubit>().open(item),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(isFilm),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: EverloreTheme.ui(
                              size: 15,
                              weight: unread
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: unread
                                  ? EverloreTheme.parchment
                                  : EverloreTheme.parchment.withValues(
                                      alpha: 0.70,
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatRelativeTime(item.createdAt),
                          style: EverloreTheme.ui(
                            size: 12,
                            weight: unread ? FontWeight.w600 : FontWeight.w400,
                            color: unread
                                ? EverloreTheme.goldDim
                                : EverloreTheme.ash,
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 6),
                          Container(
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
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      style: EverloreTheme.aiText.copyWith(
                        fontSize: 15,
                        height: 1.45,
                        color: unread
                            ? EverloreTheme.parchment.withValues(alpha: 0.90)
                            : EverloreTheme.ash,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(bool isFilm) {
    final fallback = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: isFilm ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: isFilm ? BorderRadius.circular(12) : null,
        color: EverloreTheme.void3,
      ),
      alignment: Alignment.center,
      child: isFilm
          ? const Icon(
              Icons.movie_creation_outlined,
              size: 26,
              color: EverloreTheme.gold,
            )
          : Text(
              item.title.trim().isNotEmpty
                  ? item.title.trim()[0].toUpperCase()
                  : '?',
              style: EverloreTheme.ui(
                size: 20,
                weight: FontWeight.w700,
                color: EverloreTheme.gold,
              ),
            ),
    );

    if (item.imageUrl == null || item.imageUrl!.isEmpty) {
      return fallback;
    }

    final image = EverloreNetworkImage(
      imageUrl: item.imageUrl!,
      fit: BoxFit.cover,
      placeholder: fallback,
      errorWidget: fallback,
    );

    if (isFilm) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(width: 56, height: 56, child: image),
      );
    }

    return ClipOval(child: SizedBox(width: 56, height: 56, child: image));
  }
}
