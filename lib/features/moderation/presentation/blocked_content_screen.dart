import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/nexus_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/widgets/everlore_empty_state.dart';
import '../../../shared/widgets/everlore_network_image.dart';
import '../../../shared/widgets/everlore_session_loader.dart';
import '../../../shared/widgets/top_confirmation_toast.dart';
import '../../templates/data/template_repository.dart';
import '../data/moderation_repository.dart';

/// Everything this player has hidden, and the way back.
///
/// A block that cannot be undone is a trap, and Play expects the list to be
/// inspectable, so this screen is reachable from Profile rather than buried.
class BlockedContentScreen extends StatefulWidget {
  const BlockedContentScreen({super.key});

  @override
  State<BlockedContentScreen> createState() => _BlockedContentScreenState();
}

class _BlockedContentScreenState extends State<BlockedContentScreen> {
  BlockedContent _blocks = BlockedContent.empty;
  bool _loading = true;
  String? _error;
  final Set<String> _pending = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final blocks = await ModerationRepository.listBlocks();
      if (!mounted) return;
      setState(() {
        _blocks = blocks;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load your blocked content.';
      });
    }
  }

  Future<void> _unblock({
    required String id,
    required bool isCreator,
    required String label,
  }) async {
    if (_pending.contains(id)) return;
    setState(() => _pending.add(id));
    try {
      if (isCreator) {
        await ModerationRepository.unblockCreator(id);
      } else {
        await ModerationRepository.unblockWorld(id);
      }
      // Discovery lists are cached per query, so an unblock has to invalidate
      // them or the restored world stays missing until the cache expires.
      TemplateRepository.invalidate();
      if (!mounted) return;
      setState(() {
        _pending.remove(id);
        _blocks = BlockedContent(
          creators: _blocks.creators.where((c) => c.id != id).toList(),
          worlds: _blocks.worlds.where((w) => w.id != id).toList(),
        );
      });
      showTopConfirmationToast(
        context,
        icon: Icons.visibility_outlined,
        message: isCreator
            ? '$label unblocked. Their worlds are back.'
            : '$label is visible again.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _pending.remove(id));
      showTopConfirmationToast(
        context,
        icon: Icons.error_outline_rounded,
        message: 'Could not undo that. Try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EverloreTheme.void1,
      appBar: AppBar(
        backgroundColor: EverloreTheme.void0,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: EverloreTheme.ash,
            size: 18,
          ),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text(
          'Blocked content',
          style: EverloreTheme.serifDisplay(
            size: 19,
            color: EverloreTheme.parchment,
          ),
        ),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: EverloreSessionLoader(message: 'Loading your blocks'),
      );
    }

    if (_error != null) {
      return EverloreEmptyState(
        icon: Icons.cloud_off_rounded,
        eyebrow: 'OFFLINE',
        title: 'Could not load your blocks',
        message: _error!,
        actionLabel: 'Try again',
        actionIcon: Icons.refresh_rounded,
        onAction: _load,
        accent: EverloreTheme.gold,
      );
    }

    if (_blocks.isEmpty) {
      return const EverloreEmptyState(
        icon: Icons.shield_outlined,
        eyebrow: 'ALL CLEAR',
        title: 'Nothing is blocked',
        message:
            'Worlds and creators you hide will collect here, so you can let '
            'them back in whenever you want.',
        accent: EverloreTheme.gold,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      backgroundColor: EverloreTheme.void2,
      color: EverloreTheme.gold,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Text(
            'These only affect what you see. Nobody is told they were blocked.',
            style: EverloreTheme.ui(
              size: 12.5,
              color: EverloreTheme.ash,
              height: 1.5,
            ),
          ),
          if (_blocks.creators.isNotEmpty) ...[
            const SizedBox(height: 26),
            _SectionHeader(
              label: 'BLOCKED CREATORS',
              count: _blocks.creators.length,
            ),
            const SizedBox(height: 12),
            for (final creator in _blocks.creators)
              _BlockRow(
                title: creator.username,
                subtitle: 'Every world they publish is hidden',
                busy: _pending.contains(creator.id),
                leading: CircleAvatar(
                  radius: 22,
                  backgroundColor: EverloreTheme.void4,
                  child: Text(
                    creator.username.isNotEmpty
                        ? creator.username[0].toUpperCase()
                        : '?',
                    style: EverloreTheme.ui(
                      size: 16,
                      color: EverloreTheme.gold,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
                onUndo: () => _unblock(
                  id: creator.id,
                  isCreator: true,
                  label: creator.username,
                ),
              ),
          ],
          if (_blocks.worlds.isNotEmpty) ...[
            const SizedBox(height: 26),
            _SectionHeader(
              label: 'HIDDEN WORLDS',
              count: _blocks.worlds.length,
            ),
            const SizedBox(height: 12),
            for (final world in _blocks.worlds)
              _BlockRow(
                title: world.title,
                subtitle: 'Hidden from Explore and search',
                busy: _pending.contains(world.id),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: world.imageUrl.isNotEmpty
                        ? EverloreNetworkImage(
                            imageUrl: world.imageUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: 132,
                            semanticLabel: world.title,
                          )
                        : Container(
                            color: EverloreTheme.void4,
                            child: const Icon(
                              Icons.auto_stories_outlined,
                              size: 20,
                              color: EverloreTheme.ash,
                            ),
                          ),
                  ),
                ),
                onUndo: () => _unblock(
                  id: world.id,
                  isCreator: false,
                  label: world.title,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;

  const _SectionHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: EverloreTheme.sectionHeader),
        const SizedBox(width: 8),
        Text(
          '$count',
          style: EverloreTheme.ui(
            size: 11,
            color: EverloreTheme.gold,
            weight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: EverloreTheme.goldDim.withValues(alpha: 0.2),
          ),
        ),
      ],
    );
  }
}

class _BlockRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget leading;
  final bool busy;
  final VoidCallback onUndo;

  const _BlockRow({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.busy,
    required this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EverloreTheme.void2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: EverloreTheme.goldDim.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EverloreTheme.ui(
                    size: 14,
                    color: EverloreTheme.parchment,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: EverloreTheme.ui(
                    size: 11.5,
                    color: EverloreTheme.ash,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: busy ? null : onUndo,
            style: TextButton.styleFrom(
              foregroundColor: EverloreTheme.gold,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: busy
                ? const SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: EverloreTheme.gold,
                    ),
                  )
                : Text(
                    'Undo',
                    style: EverloreTheme.ui(
                      size: 13,
                      color: EverloreTheme.gold,
                      weight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
