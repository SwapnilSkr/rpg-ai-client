import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/nexus_theme.dart';
import '../../../../shared/widgets/everlore_notice.dart';
import '../../../moderation/presentation/report_sheet.dart';
import '../../../play/presentation/widgets/anchored_menu_popup.dart';
import '../../models/group_chat_models.dart';
import 'member_avatar.dart';

/// Single message bubble or action line in a group or direct thread.
class GroupMessageBubble extends StatelessWidget {
  final GroupLine line;
  final GroupMember? member;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final VoidCallback? onCharacterTap;
  final void Function(GroupLine line, String speakerName)? onReportLine;
  final double? Function()? composerTop;

  const GroupMessageBubble({
    super.key,
    required this.line,
    this.member,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
    this.onCharacterTap,
    this.onReportLine,
    this.composerTop,
  });

  @override
  Widget build(BuildContext context) {
    if (line.isAction) {
      return _buildActionLine();
    }
    if (line.isPlayer) {
      return _buildPlayerBubble();
    }
    return _buildCharacterBubble(context);
  }

  void _openMenu(BuildContext bubbleContext) {
    HapticFeedback.lightImpact();

    final displayName = line.name.isNotEmpty
        ? line.name
        : (member?.name ?? 'Someone');

    final canReport = !line.isPlayer &&
        !line.isAction &&
        line.eventId != null &&
        line.characterId != null &&
        line.characterId!.isNotEmpty;

    final rect = globalRectOf(bubbleContext);

    showAnchoredMenu<void>(
      context: bubbleContext,
      anchorRect: rect,
      composerTop: composerTop?.call(),
      items: [
        AnchoredMenuItem(
          icon: const Icon(
            Icons.copy_rounded,
            color: EverloreTheme.ash,
            size: 16,
          ),
          label: 'Copy',
          onTap: () {
            Clipboard.setData(
              ClipboardData(text: line.text.trim()),
            );
            if (!bubbleContext.mounted) return;
            showEverloreNotice(
              bubbleContext,
              'Copied',
              tone: NoticeTone.info,
            );
          },
        ),
        if (canReport)
          AnchoredMenuItem(
            icon: const Icon(
              Icons.flag_outlined,
              color: EverloreTheme.crimson,
              size: 16,
            ),
            label: 'Report',
            onTap: () {
              if (!bubbleContext.mounted) return;
              if (onReportLine != null) {
                onReportLine!(line, displayName);
              } else {
                showReportLineSheet(
                  bubbleContext,
                  eventId: line.eventId!,
                  characterId: line.characterId!,
                  text: line.text,
                  speakerName: displayName,
                );
              }
            },
          ),
      ],
    );
  }

  Widget _buildActionLine() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Center(
        child: Builder(
          builder: (bubbleContext) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: () => _openMenu(bubbleContext),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: EverloreTheme.void2.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: EverloreTheme.goldDim.withValues(alpha: 0.3),
                  width: 0.8,
                ),
              ),
              child: Text(
                line.text,
                textAlign: TextAlign.center,
                style: EverloreTheme.aiText.copyWith(
                  fontSize: 15,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                  color: EverloreTheme.goldGlow,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerBubble() {
    String? statusNote;
    if (line.status == GroupLineStatus.queued) {
      statusNote = 'Queued';
    } else if (line.status == GroupLineStatus.sending) {
      statusNote = 'Sending…';
    }

    final topPadding = isFirstInGroup ? 8.0 : 2.0;
    final bottomPadding = isLastInGroup ? 8.0 : 2.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(54, topPadding, 16, bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Builder(
            builder: (bubbleContext) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: () => _openMenu(bubbleContext),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: EverloreTheme.void3,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: Radius.circular(isFirstInGroup ? 16 : 4),
                    bottomLeft: const Radius.circular(16),
                    bottomRight: Radius.circular(isLastInGroup ? 16 : 4),
                  ),
                  border: Border.all(
                    color: EverloreTheme.goldDim.withValues(alpha: 0.28),
                    width: 0.9,
                  ),
                ),
                child: Text(
                  line.text,
                  style: EverloreTheme.aiText.copyWith(
                    fontSize: 16,
                    height: 1.45,
                    color: EverloreTheme.parchment,
                  ),
                ),
              ),
            ),
          ),
          if (statusNote != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 4),
              child: Text(
                statusNote,
                style: EverloreTheme.caption.copyWith(
                  color: EverloreTheme.ash.withValues(alpha: 0.7),
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCharacterBubble(BuildContext context) {
    final topPadding = isFirstInGroup ? 8.0 : 2.0;
    final bottomPadding = isLastInGroup ? 8.0 : 2.0;
    final displayName = line.name.isNotEmpty
        ? line.name
        : (member?.name ?? 'Someone');

    return Padding(
      padding: EdgeInsets.fromLTRB(16, topPadding, 54, bottomPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar: show only on last line of the consecutive group, or keep placeholder space
          SizedBox(
            width: 34,
            child: isLastInGroup
                ? MemberAvatar(
                    member: member,
                    name: displayName,
                    size: 34,
                    onTap: onCharacterTap,
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isFirstInGroup)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: GestureDetector(
                      onTap: onCharacterTap,
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        displayName,
                        style: EverloreTheme.caption.copyWith(
                          color: EverloreTheme.goldDim,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                Builder(
                  builder: (bubbleContext) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onLongPress: () => _openMenu(bubbleContext),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: EverloreTheme.void2,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(isFirstInGroup ? 16 : 4),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isLastInGroup ? 16 : 4),
                          bottomRight: const Radius.circular(16),
                        ),
                        border: Border.all(
                          color: EverloreTheme.white10,
                          width: 0.9,
                        ),
                      ),
                      child: Text(
                        line.text,
                        style: EverloreTheme.aiText.copyWith(
                          fontSize: 16,
                          height: 1.45,
                          color: EverloreTheme.parchment,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
