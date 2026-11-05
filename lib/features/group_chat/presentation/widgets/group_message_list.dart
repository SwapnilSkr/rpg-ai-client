import 'package:flutter/material.dart';

import '../../../../app/theme/nexus_theme.dart';
import '../../../play/presentation/widgets/anchored_menu_popup.dart';
import '../../models/group_chat_models.dart';
import 'group_message_bubble.dart';

/// Scrollable message thread list sticking to bottom when new lines arrive unless scrolled up.
class GroupMessageList extends StatefulWidget {
  final List<GroupLine> lines;
  final Map<String, GroupMember> memberMap;
  final ValueChanged<GroupMember>? onCharacterTap;
  final void Function(GroupLine line, String speakerName)? onReportLine;

  /// Null while rewinding is not possible; see [GroupMessageBubble.onRewindLine].
  final void Function(GroupLine line)? onRewindLine;

  /// Offered when a character can send a selfie. Null during rewind.
  final void Function(GroupLine line)? onRequestSelfie;
  final void Function(GroupLine line, String mediaId, String speakerName)?
      onReportSelfie;

  /// Someone is about to speak, so an empty room isn't waiting on the player.
  final bool someoneTyping;
  final double? Function()? composerTop;

  const GroupMessageList({
    super.key,
    required this.lines,
    this.memberMap = const {},
    this.onCharacterTap,
    this.onReportLine,
    this.onRewindLine,
    this.onRequestSelfie,
    this.onReportSelfie,
    this.someoneTyping = false,
    this.composerTop,
  });

  @override
  State<GroupMessageList> createState() => _GroupMessageListState();
}

class _GroupMessageListState extends State<GroupMessageList> {
  final _scrollController = ScrollController();
  int _lastLineCount = 0;

  @override
  void initState() {
    super.initState();
    _lastLineCount = widget.lines.length;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(force: true));
  }

  @override
  void didUpdateWidget(covariant GroupMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lines.length != _lastLineCount) {
      final wasAtBottom = _isNearBottom();
      _lastLineCount = widget.lines.length;
      if (wasAtBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.offset;
    return (max - current) < 90;
  }

  void _scrollToBottom({bool force = false}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (force) {
      _scrollController.jumpTo(target);
    } else {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  double? _resolveComposerTop() {
    if (widget.composerTop != null) {
      final explicit = widget.composerTop!();
      if (explicit != null) return explicit;
    }
    return globalRectOf(context)?.bottom;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lines.isEmpty) {
      if (widget.someoneTyping) return const SizedBox.expand();
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'The conversation begins with you.',
            textAlign: TextAlign.center,
            style: EverloreTheme.aiText.copyWith(
              fontSize: 16,
              color: EverloreTheme.ash,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: widget.lines.length,
      itemBuilder: (context, index) {
        final line = widget.lines[index];
        final member = line.characterId != null
            ? widget.memberMap[line.characterId!]
            : null;

        final isFirstInGroup = index == 0 ||
            widget.lines[index - 1].characterId != line.characterId ||
            widget.lines[index - 1].isPlayer != line.isPlayer ||
            widget.lines[index - 1].isAction != line.isAction;

        final isLastInGroup = index == widget.lines.length - 1 ||
            widget.lines[index + 1].characterId != line.characterId ||
            widget.lines[index + 1].isPlayer != line.isPlayer ||
            widget.lines[index + 1].isAction != line.isAction;

        return GroupMessageBubble(
          key: ValueKey(line.key),
          line: line,
          member: member,
          isFirstInGroup: isFirstInGroup,
          isLastInGroup: isLastInGroup,
          onCharacterTap: member != null && widget.onCharacterTap != null
              ? () => widget.onCharacterTap!(member)
              : null,
          onReportLine: widget.onReportLine,
          onRewindLine: widget.onRewindLine,
          onRequestSelfie: widget.onRequestSelfie,
          onReportSelfie: widget.onReportSelfie,
          composerTop: _resolveComposerTop,
        );
      },
    );
  }
}
