import 'package:flutter/material.dart';
import '../../../app/theme/nexus_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/widgets/everlore_notice.dart';
import '../data/moderation_repository.dart';
import 'report_sheet.dart';
import '../../../shared/widgets/everlore_sheet.dart';

/// What the player did, so the calling screen can react — a hidden or reported
/// world should leave the list, and a detail screen should pop.
enum ContentActionResult { none, reported, worldHidden, creatorBlocked }

/// The safety menu for a world someone else created: report it, hide it, or
/// hide everything by that creator.
///
/// Deliberately not shown for a player's own worlds — there is nothing to
/// report or block, and the server refuses both.
Future<ContentActionResult> showContentActionsSheet(
  BuildContext context, {
  required String worldId,
  required String worldTitle,
  required String creatorId,
}) async {
  final result = await showModalBottomSheet<ContentActionResult>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (_) => _ContentActionsSheet(
      worldId: worldId,
      worldTitle: worldTitle,
      creatorId: creatorId,
    ),
  );
  return result ?? ContentActionResult.none;
}

class _ContentActionsSheet extends StatefulWidget {
  final String worldId;
  final String worldTitle;
  final String creatorId;

  const _ContentActionsSheet({
    required this.worldId,
    required this.worldTitle,
    required this.creatorId,
  });

  @override
  State<_ContentActionsSheet> createState() => _ContentActionsSheetState();
}

class _ContentActionsSheetState extends State<_ContentActionsSheet> {
  bool _busy = false;

  Future<void> _run(
    Future<void> Function() action, {
    required String confirmation,
    required ContentActionResult result,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    try {
      await action();
      if (!mounted) return;
      navigator.pop(result);
      showEverloreNotice(
        context,
        confirmation,
        tone: NoticeTone.success,
        icon: Icons.visibility_off_outlined,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showEverloreNotice(
        context,
        e.message,
        tone: NoticeTone.error,
        icon: Icons.error_outline_rounded,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      showEverloreNotice(
        context,
        'Something went wrong. Try again.',
        tone: NoticeTone.error,
        icon: Icons.error_outline_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: EverloreTheme.void2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      // Three tiles of two-line prose plus a footnote: taller than a small
      // phone at large text, where this used to run 139pt off the bottom.
      child: SheetFrame(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.worldTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EverloreTheme.ui(
                    size: 13,
                    color: EverloreTheme.gold,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            _ActionTile(
              icon: Icons.flag_outlined,
              title: 'Report this world',
              subtitle: 'Tell us it breaks the rules. Private and anonymous.',
              enabled: !_busy,
              onTap: () async {
                final navigator = Navigator.of(context);
                final filed = await showReportWorldSheet(
                  context,
                  worldId: widget.worldId,
                  worldTitle: widget.worldTitle,
                );
                if (!mounted) return;
                navigator.pop(
                  filed
                      ? ContentActionResult.reported
                      : ContentActionResult.none,
                );
              },
            ),
            _ActionTile(
              icon: Icons.visibility_off_outlined,
              title: 'Hide this world',
              subtitle: 'Remove it from your Explore and search results.',
              enabled: !_busy,
              onTap: () => _run(
                () => ModerationRepository.blockWorld(widget.worldId),
                confirmation: 'Hidden. You will not see this world again.',
                result: ContentActionResult.worldHidden,
              ),
            ),
            _ActionTile(
              icon: Icons.block_outlined,
              title: 'Block this creator',
              subtitle: 'Hide every world they publish, now and later.',
              danger: true,
              enabled: !_busy,
              onTap: () => _run(
                () => ModerationRepository.blockCreator(widget.creatorId),
                confirmation: 'Creator blocked. Their worlds are hidden.',
                result: ContentActionResult.creatorBlocked,
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                'Hiding and blocking only affect what you see. Manage them any '
                'time in Profile → Blocked content.',
                style: EverloreTheme.ui(
                  size: 11.5,
                  color: EverloreTheme.ash,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool danger;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = danger ? EverloreTheme.crimson : EverloreTheme.gold;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: ListTile(
        enabled: enabled,
        onTap: enabled ? onTap : null,
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 19, color: accent),
        ),
        title: Text(
          title,
          style: EverloreTheme.ui(
            size: 14.5,
            color: EverloreTheme.parchment,
            weight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            subtitle,
            style: EverloreTheme.ui(
              size: 12,
              color: EverloreTheme.ash,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}
