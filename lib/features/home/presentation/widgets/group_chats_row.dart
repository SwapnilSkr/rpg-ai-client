import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/nexus_theme.dart';
import '../../../../shared/models/world_instance.dart';
import '../../../../shared/models/world_template.dart';
import '../../../../shared/widgets/everlore_network_image.dart';
import '../../../../shared/widgets/everlore_session_loader.dart';
import '../../data/home_repository.dart';

/// Horizontal row on the Home screen displaying group templates and active group chats.
class GroupChatsRow extends StatelessWidget {
  final List<WorldTemplate> templates;
  final List<WorldInstance> existingChats;
  final VoidCallback onRefreshed;

  const GroupChatsRow({
    super.key,
    required this.templates,
    required this.existingChats,
    required this.onRefreshed,
  });

  @override
  Widget build(BuildContext context) {
    if (templates.isEmpty) return const SizedBox.shrink();

    // Map instances by templateId
    final instanceByTemplate = {
      for (final chat in existingChats) chat.templateId: chat,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
            child: Row(
              children: [
                const Icon(
                  Icons.forum_outlined,
                  color: EverloreTheme.gold,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text('GROUP CHATS', style: EverloreTheme.sectionHeader),
              ],
            ),
          ),
          SizedBox(
            height: 148,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: templates.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final template = templates[index];
                final instance = instanceByTemplate[template.id];
                return _GroupCard(
                  template: template,
                  instance: instance,
                  onRefreshed: onRefreshed,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatefulWidget {
  final WorldTemplate template;
  final WorldInstance? instance;
  final VoidCallback onRefreshed;

  const _GroupCard({
    required this.template,
    this.instance,
    required this.onRefreshed,
  });

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  bool _opening = false;

  Future<void> _handleTap() async {
    if (_opening) return;

    if (widget.instance != null) {
      await context.push(
        '/group/${widget.instance!.id}',
        extra: {'title': widget.template.title},
      );
      widget.onRefreshed();
      return;
    }

    setState(() => _opening = true);
    try {
      final instance = await showEverloreSessionLoading(
        context,
        message: 'Opening conversation',
        task: () => HomeRepository.createInstance(widget.template.id),
      );
      if (!mounted || instance == null) return;
      await context.push(
        '/group/${instance.id}',
        extra: {'title': widget.template.title},
      );
      widget.onRefreshed();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStarted = widget.instance != null;
    final imageUrl = widget.template.imageUrl;

    return Container(
      width: 170,
      decoration: BoxDecoration(
        color: EverloreTheme.void2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isStarted
              ? EverloreTheme.goldDim.withValues(alpha: 0.5)
              : EverloreTheme.white10,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(1, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover area
              SizedBox(
                height: 72,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl.isNotEmpty)
                      EverloreNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: Container(color: EverloreTheme.void3),
                      )
                    else
                      Container(
                        color: EverloreTheme.void3,
                        child: const Center(
                          child: Icon(
                            Icons.group_rounded,
                            color: EverloreTheme.goldDim,
                            size: 28,
                          ),
                        ),
                      ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            EverloreTheme.void2.withValues(alpha: 0.85),
                          ],
                        ),
                      ),
                    ),
                    if (isStarted)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: EverloreTheme.void0.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: EverloreTheme.gold,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            'Active',
                            style: EverloreTheme.caption.copyWith(
                              color: EverloreTheme.gold,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Title and action
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.template.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: EverloreTheme.ui(
                          size: 12.5,
                          weight: FontWeight.w600,
                          color: EverloreTheme.parchment,
                        ),
                      ),
                      Text(
                        isStarted ? 'Continue' : 'Start chat',
                        style: EverloreTheme.caption.copyWith(
                          color: isStarted
                              ? EverloreTheme.goldDim
                              : EverloreTheme.ash,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
