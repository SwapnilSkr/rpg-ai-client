import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/nexus_theme.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/guide/guide_anchor.dart';
import '../../../../core/guide/guide_flows.dart';
import '../../../../core/guide/guide_ids.dart';
import '../../../../core/guide/guide_trigger.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/widgets/everlore_network_image.dart';
import '../../../../shared/widgets/everlore_top_bar.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../state/chats_cubit.dart';
import '../../state/chats_state.dart';
import '../widgets/group_cover_card.dart';
import '../widgets/member_avatar.dart';

/// Chats tab screen: lists conversations and joinable group chats.
class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  User? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
    AuthService.sessionEpoch.addListener(_loadUser);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ChatsCubit>().refresh();
      }
    });
  }

  @override
  void dispose() {
    AuthService.sessionEpoch.removeListener(_loadUser);
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await AuthService.resolveSessionUser();
    if (mounted) {
      setState(() => _user = user);
    }
  }

  Future<void> _openConversation(ChatConversation conversation) async {
    final cubit = context.read<ChatsCubit>();
    await cubit.markOpened(
      conversation.instanceId,
      memberId: conversation.memberId,
    );

    if (!mounted) return;
    if (conversation.isDirect) {
      await context.push(
        '/group/${conversation.instanceId}?member=${conversation.memberId}',
      );
    } else {
      await context.push('/group/${conversation.instanceId}');
    }

    if (mounted) {
      await cubit.markOpened(
        conversation.instanceId,
        memberId: conversation.memberId,
      );
      await cubit.refresh();
    }
  }

  String _formatRelativeTime(DateTime? at) {
    if (at == null) return '';
    final diff = DateTime.now().difference(at);
    if (diff.isNegative || diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${at.month}/${at.day}';
  }

  Widget _buildGroupActionsRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: EverloreTheme.goldDim.withValues(alpha: 0.28),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/art/forge-group-cover.webp',
              fit: BoxFit.cover,
              alignment: const Alignment(0.4, -0.2),
              cacheWidth: 800,
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      EverloreTheme.void0.withValues(alpha: 0.92),
                      EverloreTheme.void0.withValues(alpha: 0.35),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => context.push('/groups/new'),
                      child: Container(
                        height: 72,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.centerLeft,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Make your own group',
                              style: EverloreTheme.ui(
                                size: 15,
                                weight: FontWeight.w700,
                                color: EverloreTheme.parchment,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Your people, your words.',
                              style: EverloreTheme.aiText.copyWith(
                                fontSize: 14,
                                color: EverloreTheme.ash,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Container(width: 1, height: 72, color: EverloreTheme.white10),
                SizedBox(
                  width: 92,
                  height: 72,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => context.push('/groups/mine'),
                      child: Center(
                        child: Text(
                          'Your groups',
                          textAlign: TextAlign.center,
                          style: EverloreTheme.ui(
                            size: 12,
                            weight: FontWeight.w600,
                            color: EverloreTheme.parchment,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EverloreTheme.void0,
      body: Column(
        children: [
          const EverloreTopBar(
            title: 'Chats',
            backgroundOpacity: 0.68,
            showNotifications: true,
          ),
          Expanded(
            child: BlocBuilder<ChatsCubit, ChatsState>(
              builder: (context, state) {
                // Show shimmer only while not yet loaded
                if (state.isLoading && !state.hasLoaded) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 110),
                    child: Column(
                      children: [
                        for (var i = 0; i < 5; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildShimmerRow(),
                          ),
                      ],
                    ),
                  );
                }

                final conversations = state.conversations;
                final joinable = state.joinable;

                return GuideOnEnter(
                  flow: GuideFlows.chats,
                  enabled: state.hasLoaded,
                  child: RefreshIndicator(
                    color: EverloreTheme.gold,
                    backgroundColor: EverloreTheme.void2,
                    onRefresh: () => context.read<ChatsCubit>().refresh(),
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              if (AuthService.canAccessForge(_user))
                                _buildGroupActionsRow(context),
                              if (conversations.isEmpty) ...[
                                // Empty state: cover cards are main content
                                if (joinable.isEmpty)
                                  GuideAnchor(
                                    id: GuideIds.chatsFirst,
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        4,
                                        16,
                                        4,
                                        24,
                                      ),
                                      child: Text(
                                        'Group chats are always going. Walk in and say something.',
                                        style: EverloreTheme.aiText.copyWith(
                                          fontSize: 16,
                                          color: EverloreTheme.parchment
                                              .withValues(alpha: 0.88),
                                          height: 1.45,
                                        ),
                                      ),
                                    ),
                                  )
                                else ...[
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      4,
                                      16,
                                      4,
                                      24,
                                    ),
                                    child: Text(
                                      'Group chats are always going. Walk in and say something.',
                                      style: EverloreTheme.aiText.copyWith(
                                        fontSize: 16,
                                        color: EverloreTheme.parchment
                                            .withValues(alpha: 0.88),
                                        height: 1.45,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: 210,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: joinable.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(width: 14),
                                      itemBuilder: (context, index) {
                                        final card = GroupCoverCard(
                                          template: joinable[index],
                                          width: 132,
                                          height: 198,
                                        );
                                        if (index == 0) {
                                          return GuideAnchor(
                                            id: GuideIds.chatsFirst,
                                            child: card,
                                          );
                                        }
                                        return card;
                                      },
                                    ),
                                  ),
                                ],
                              ] else ...[
                                // Conversations list
                                for (
                                  var i = 0;
                                  i < conversations.length;
                                  i++
                                ) ...[
                                  _buildConversationRow(
                                    conversations[i],
                                    isFirst: i == 0,
                                  ),
                                  if (i < conversations.length - 1)
                                    const Divider(
                                      color: EverloreTheme.white10,
                                      height: 16,
                                      indent: 72,
                                    ),
                                ],

                                // Join a group section below conversations
                                if (joinable.isNotEmpty) ...[
                                  const SizedBox(height: 32),
                                  Text(
                                    'JOIN A GROUP',
                                    style: EverloreTheme.ui(
                                      size: 11,
                                      weight: FontWeight.w700,
                                      color: EverloreTheme.goldDim,
                                      spacing: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    height: 210,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: joinable.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(width: 14),
                                      itemBuilder: (context, index) {
                                        return GroupCoverCard(
                                          template: joinable[index],
                                          width: 132,
                                          height: 198,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ],
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationRow(
    ChatConversation conversation, {
    required bool isFirst,
  }) {
    final previewText = conversation.last != null
        ? (conversation.last!.isPlayer
              ? 'You: ${conversation.last!.text}'
              : (conversation.last!.name.isNotEmpty
                    ? '${conversation.last!.name}: ${conversation.last!.text}'
                    : conversation.last!.text))
        : null;

    final avatarWidget = conversation.isDirect
        ? MemberAvatar(
            member: conversation.faces.firstOrNull,
            name: conversation.title,
            portraitUrl: conversation.faces.firstOrNull?.portraitUrl,
            portraitThumbUrl: conversation.faces.firstOrNull?.portraitThumbUrl,
            size: 56,
          )
        : SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: EverloreTheme.void2,
                      border: Border.all(
                        color: EverloreTheme.goldDim.withValues(alpha: 0.3),
                      ),
                    ),
                    child:
                        conversation.imageUrl != null &&
                            conversation.imageUrl!.isNotEmpty
                        ? EverloreNetworkImage(
                            imageUrl:
                                conversation.imageThumbUrl != null &&
                                    conversation.imageThumbUrl!.isNotEmpty
                                ? conversation.imageThumbUrl!
                                : conversation.imageUrl!,
                            fallbackUrl: conversation.imageUrl,
                            fit: BoxFit.cover,
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                if (conversation.faces.isNotEmpty)
                  Positioned(
                    left: 2,
                    bottom: -3,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (
                          var f = 0;
                          f < conversation.faces.length && f < 3;
                          f++
                        )
                          Align(
                            widthFactor: 0.72,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: EverloreTheme.void0,
                                  width: 1.2,
                                ),
                              ),
                              child: MemberAvatar(
                                member: conversation.faces[f],
                                size: 20,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          );

    Widget row = GestureDetector(
      onTap: () => _openConversation(conversation),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            avatarWidget,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: EverloreTheme.ui(
                            size: 15,
                            weight: conversation.unread
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: EverloreTheme.parchment,
                          ),
                        ),
                      ),
                      if (conversation.at != null)
                        Text(
                          _formatRelativeTime(conversation.at),
                          style: EverloreTheme.caption.copyWith(
                            color: EverloreTheme.ash,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: previewText != null
                            ? Text(
                                previewText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: EverloreTheme.ui(
                                  size: 13,
                                  color: EverloreTheme.ash,
                                ),
                              )
                            : const SizedBox(height: 16),
                      ),
                      if (conversation.unread) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: EverloreTheme.gold,
                            shape: BoxShape.circle,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (isFirst) {
      return GuideAnchor(id: GuideIds.chatsFirst, child: row);
    }
    return row;
  }

  Widget _buildShimmerRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const LoadingShimmer(width: 56, height: 56, radius: 14),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                LoadingShimmer(width: 140, height: 14, radius: 4),
                SizedBox(height: 8),
                LoadingShimmer(width: double.infinity, height: 12, radius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
