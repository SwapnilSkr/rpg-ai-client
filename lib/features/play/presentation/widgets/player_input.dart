import 'package:flutter/material.dart';
import '../../../../../app/theme/nexus_theme.dart';

class PlayerInput extends StatefulWidget {
  final bool isGenerating;
  final bool isConnected;
  final ValueChanged<String> onSend;
  final VoidCallback onContinue;

  const PlayerInput({
    super.key,
    required this.isGenerating,
    required this.isConnected,
    required this.onSend,
    required this.onContinue,
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
    _focusNode.addListener(() => setState(() {}));
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
    final focused = _focusNode.hasFocus;

    return Container(
      // Bottom scrim so the field floats over the immersive backdrop
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x0006060D), Color(0xF206060D)],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 14, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Continue: let the world advance on its own (no typing).
                  _ContinueButton(
                    enabled: !widget.isGenerating && widget.isConnected,
                    onTap: widget.onContinue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: EverloreTheme.void2.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: focused
                              ? EverloreTheme.gold.withValues(alpha: 0.55)
                              : EverloreTheme.goldDim.withValues(alpha: 0.22),
                          width: focused ? 1.4 : 1,
                        ),
                        boxShadow: focused
                            ? EverloreTheme.glow(EverloreTheme.gold,
                                blur: 14, alpha: 0.12)
                            : null,
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        enabled: !widget.isGenerating,
                        maxLines: 5,
                        minLines: 1,
                        style: EverloreTheme.ui(
                          size: 15,
                          color: EverloreTheme.parchment,
                          height: 1.4,
                        ),
                        decoration: InputDecoration(
                          hintText: _hintText(),
                          hintStyle: EverloreTheme.ui(
                            size: 14,
                            color: EverloreTheme.ash.withValues(alpha: 0.45),
                            fontStyle: FontStyle.italic,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        textInputAction: TextInputAction.newline,
                        onSubmitted: (_) => _submit(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _SendOrb(
                    isGenerating: widget.isGenerating,
                    canSend: canSend,
                    onTap: canSend ? _submit : null,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Everlore is A.I. — stories are imagined, not real.',
                style: EverloreTheme.ui(
                  size: 10,
                  color: EverloreTheme.ash.withValues(alpha: 0.4),
                  spacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _hintText() {
    if (widget.isGenerating) return 'The story unfolds…';
    if (!widget.isConnected) return 'Reconnecting to the realm…';
    return 'What do you do?';
  }
}

class _ContinueButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _ContinueButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Let the story continue on its own',
      child: SizedBox(
        width: 46,
        height: 46,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(23),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EverloreTheme.void2.withValues(alpha: 0.85),
                border: Border.all(
                  color: enabled
                      ? EverloreTheme.violet.withValues(alpha: 0.4)
                      : EverloreTheme.goldDim.withValues(alpha: 0.18),
                ),
              ),
              child: Icon(
                Icons.fast_forward_rounded,
                size: 20,
                color: enabled
                    ? EverloreTheme.violetBright
                    : EverloreTheme.ash.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SendOrb extends StatelessWidget {
  final bool isGenerating;
  final bool canSend;
  final VoidCallback? onTap;

  const _SendOrb({
    required this.isGenerating,
    required this.canSend,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: canSend
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [EverloreTheme.goldGlow, EverloreTheme.gold],
              )
            : null,
        color: canSend ? null : EverloreTheme.void3,
        border: Border.all(
          color: canSend
              ? Colors.transparent
              : EverloreTheme.goldDim.withValues(alpha: 0.2),
        ),
        boxShadow: canSend
            ? EverloreTheme.glow(EverloreTheme.gold, blur: 14, alpha: 0.4)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(23),
          child: Center(
            child: isGenerating
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
                    size: 19,
                    color: canSend
                        ? EverloreTheme.void0
                        : EverloreTheme.ash.withValues(alpha: 0.3),
                  ),
          ),
        ),
      ),
    );
  }
}
