import 'package:flutter/material.dart';

import '../../../../app/theme/nexus_theme.dart';
import '../../models/group_chat_models.dart';
import '../../state/group_chat_state.dart';
import 'group_chat_backdrop.dart';
import 'member_avatar.dart';

/// Bottom composer for group and direct threads with actions toggle, `@` member suggestions,
/// typing indicator, and failed send banners.
class GroupComposer extends StatefulWidget {
  final List<GroupMember> members;
  final String? typingName;
  final List<FailedSend> failedSends;
  final void Function(String text, bool isAction) onSend;
  final ValueChanged<String> onRetryFailed;
  final ValueChanged<String> onDiscardFailed;
  final bool enableMentions;
  final bool enableActionToggle;

  const GroupComposer({
    super.key,
    this.members = const [],
    this.typingName,
    this.failedSends = const [],
    required this.onSend,
    required this.onRetryFailed,
    required this.onDiscardFailed,
    this.enableMentions = true,
    this.enableActionToggle = true,
  });

  @override
  State<GroupComposer> createState() => _GroupComposerState();
}

class _GroupComposerState extends State<GroupComposer> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isAction = false;
  List<GroupMember> _mentionSuggestions = [];
  int _mentionStartIndex = -1;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (!widget.enableMentions) {
      if (_mentionSuggestions.isNotEmpty) {
        setState(() => _mentionSuggestions = []);
      }
      return;
    }

    final text = _controller.text;
    final selection = _controller.selection;
    if (selection.baseOffset < 0) {
      if (_mentionSuggestions.isNotEmpty) {
        setState(() => _mentionSuggestions = []);
      }
      return;
    }

    final cursor = selection.baseOffset;
    final prefix = text.substring(0, cursor);
    final lastAt = prefix.lastIndexOf('@');

    if (lastAt >= 0) {
      final query = prefix.substring(lastAt + 1);
      // Ensure there are no spaces between '@' and the cursor (active mention typing)
      if (!query.contains(' ') && (lastAt == 0 || prefix[lastAt - 1] == ' ')) {
        final matches = widget.members.where((m) {
          return m.name.toLowerCase().contains(query.toLowerCase());
        }).toList();

        setState(() {
          _mentionStartIndex = lastAt;
          _mentionSuggestions = matches;
        });
        return;
      }
    }

    if (_mentionSuggestions.isNotEmpty) {
      setState(() {
        _mentionSuggestions = [];
        _mentionStartIndex = -1;
      });
    }
  }

  void _chooseMention(GroupMember member) {
    if (_mentionStartIndex < 0) return;
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset;
    final before = text.substring(0, _mentionStartIndex);
    final after = cursor <= text.length ? text.substring(cursor) : '';
    final replacement = '@${member.name} ';
    final newText = '$before$replacement$after';

    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: before.length + replacement.length,
      ),
    );

    setState(() {
      _mentionSuggestions = [];
      _mentionStartIndex = -1;
    });
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final wasAction = _isAction;
    widget.onSend(text, wasAction);
    _controller.clear();
    // Keep or reset action toggle? Resetting allows smooth alternating typing.
    setState(() {
      _isAction = false;
      _mentionSuggestions = [];
      _mentionStartIndex = -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hint = _isAction
        ? "Say what you do. They'll react."
        : 'Type a message…';

    return Container(
      decoration: BoxDecoration(
        color: EverloreTheme.void0.withValues(alpha: kGroupChromeAlpha),
        border: const Border(
          top: BorderSide(color: EverloreTheme.white10, width: 0.9),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Typing line
            if (widget.typingName != null) _buildTypingBar(widget.typingName!),
            // Failed send bar
            if (widget.failedSends.isNotEmpty) ...[
              for (final failed in widget.failedSends) _buildFailedBar(failed),
            ],
            // Mention suggestions
            if (_mentionSuggestions.isNotEmpty) _buildMentionSuggestions(),
            // Input row
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Action toggle button (Group only)
                  if (widget.enableActionToggle)
                    IconButton(
                      icon: Icon(
                        _isAction
                            ? Icons.auto_awesome
                            : Icons.auto_awesome_outlined,
                        color: _isAction
                            ? EverloreTheme.goldGlow
                            : EverloreTheme.ash,
                        size: 22,
                      ),
                      tooltip: _isAction ? 'Action mode on' : 'Write an action',
                      onPressed: () => setState(() => _isAction = !_isAction),
                    ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: EverloreTheme.void2,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isAction
                              ? EverloreTheme.goldDim
                              : EverloreTheme.white10,
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        maxLines: 4,
                        minLines: 1,
                        style: EverloreTheme.body.copyWith(
                          fontSize: 15,
                          fontStyle: _isAction
                              ? FontStyle.italic
                              : FontStyle.normal,
                          color: EverloreTheme.parchment,
                        ),
                        decoration: InputDecoration(
                          hintText: hint,
                          hintStyle: EverloreTheme.caption.copyWith(
                            color: EverloreTheme.ash.withValues(alpha: 0.7),
                            fontStyle: _isAction
                                ? FontStyle.italic
                                : FontStyle.normal,
                            fontSize: 14,
                          ),
                          // The app theme fills and outlines inputs; here the
                          // surrounding pill is the only box.
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                        ),
                        onSubmitted: (_) => _handleSend(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Send button (always usable)
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_upward_rounded,
                      color: EverloreTheme.gold,
                      size: 24,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: EverloreTheme.void3,
                      padding: const EdgeInsets.all(8),
                      shape: const CircleBorder(
                        side: BorderSide(
                          color: EverloreTheme.goldDim,
                          width: 1,
                        ),
                      ),
                    ),
                    onPressed: _handleSend,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingBar(String name) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      alignment: Alignment.centerLeft,
      color: EverloreTheme.void2.withValues(alpha: 0.5),
      child: Text(
        '$name is typing…',
        style: EverloreTheme.caption.copyWith(
          color: EverloreTheme.goldDim,
          fontStyle: FontStyle.italic,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildFailedBar(FailedSend failed) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: EverloreTheme.void3,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: EverloreTheme.crimson.withValues(alpha: 0.45),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: EverloreTheme.crimson,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              failed.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: EverloreTheme.caption.copyWith(
                color: EverloreTheme.parchment,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => widget.onRetryFailed(failed.id),
            child: Text(
              'Retry',
              style: EverloreTheme.caption.copyWith(
                color: EverloreTheme.gold,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16),
            color: EverloreTheme.ash,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => widget.onDiscardFailed(failed.id),
          ),
        ],
      ),
    );
  }

  Widget _buildMentionSuggestions() {
    return Material(
      color: EverloreTheme.void2,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 140),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: _mentionSuggestions.length,
          separatorBuilder: (_, __) =>
              const Divider(color: EverloreTheme.white10, height: 1),
          itemBuilder: (context, index) {
            final member = _mentionSuggestions[index];
            return ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: MemberAvatar(member: member, size: 28),
              title: Text(
                member.name,
                style: EverloreTheme.ui(
                  size: 13,
                  weight: FontWeight.w600,
                  color: EverloreTheme.parchment,
                ),
              ),
              subtitle: member.role.isNotEmpty
                  ? Text(
                      member.role,
                      style: EverloreTheme.caption.copyWith(fontSize: 11),
                    )
                  : null,
              onTap: () => _chooseMention(member),
            );
          },
        ),
      ),
    );
  }
}
