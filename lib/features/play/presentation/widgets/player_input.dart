import 'package:flutter/material.dart';
import '../../../../../app/theme/nexus_theme.dart';

class PlayerInput extends StatefulWidget {
  final bool isGenerating;
  final bool isConnected;
  final ValueChanged<String> onSend;

  const PlayerInput({
    super.key,
    required this.isGenerating,
    required this.isConnected,
    required this.onSend,
  });

  @override
  State<PlayerInput> createState() => _PlayerInputState();
}

class _PlayerInputState extends State<PlayerInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isGenerating) return;
    widget.onSend(text);
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _hasText && !widget.isGenerating && widget.isConnected;

    return Container(
      decoration: const BoxDecoration(
        color: EverloreTheme.void0,
        border: Border(
          top: BorderSide(color: EverloreTheme.white10),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: EverloreTheme.void2,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _focusNode.hasFocus
                          ? EverloreTheme.goldDim.withValues(alpha: 0.6)
                          : EverloreTheme.goldDim.withValues(alpha: 0.2),
                    ),
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    enabled: !widget.isGenerating,
                    maxLines: 5,
                    minLines: 1,
                    onTap: () => setState(() {}),
                    style: const TextStyle(
                      color: EverloreTheme.parchment,
                      fontSize: 15,
                      height: 1.4,
                    ),
                    decoration: InputDecoration(
                      hintText: _hintText(),
                      hintStyle: TextStyle(
                        color: EverloreTheme.ash.withValues(alpha: 0.4),
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    textInputAction: TextInputAction.newline,
                    onSubmitted: (_) => _submit(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isGenerating
                      ? EverloreTheme.void3
                      : canSend
                          ? EverloreTheme.gold
                          : EverloreTheme.void3,
                  border: Border.all(
                    color: widget.isGenerating || canSend
                        ? Colors.transparent
                        : EverloreTheme.goldDim.withValues(alpha: 0.2),
                  ),
                  boxShadow: canSend
                      ? [
                          BoxShadow(
                            color: EverloreTheme.gold.withValues(alpha: 0.3),
                            blurRadius: 12,
                          )
                        ]
                      : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: canSend ? _submit : null,
                    borderRadius: BorderRadius.circular(22),
                    child: Center(
                      child: widget.isGenerating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: EverloreTheme.gold,
                              ),
                            )
                          : Icon(
                              Icons.send_rounded,
                              size: 18,
                              color: canSend
                                  ? EverloreTheme.void0
                                  : EverloreTheme.ash.withValues(alpha: 0.3),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _hintText() {
    if (widget.isGenerating) return 'The story unfolds...';
    if (!widget.isConnected) return 'Reconnecting to the realm...';
    return 'What do you do?';
  }
}
