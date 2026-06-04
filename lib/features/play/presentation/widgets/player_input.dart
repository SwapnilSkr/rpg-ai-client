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

  void _insertNarrationMarkers() {
    if (widget.isGenerating) return;

    final value = _controller.value;
    final text = value.text;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final lo = start < end ? start : end;
    final hi = start < end ? end : start;
    final selected = text.substring(lo, hi);
    final markerText = selected.isEmpty ? '**' : '*$selected*';
    final next = text.replaceRange(lo, hi, markerText);
    final cursor = selected.isEmpty ? lo + 1 : hi + 2;

    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: cursor),
    );
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
                            ? EverloreTheme.glow(
                                EverloreTheme.gold,
                                blur: 14,
                                alpha: 0.12,
                              )
                            : null,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _NarrationMarkerButton(
                            enabled: !widget.isGenerating && widget.isConnected,
                            onTap: _insertNarrationMarkers,
                          ),
                          Container(
                            width: 1,
                            height: 24,
                            margin: const EdgeInsets.only(bottom: 10),
                            color: EverloreTheme.goldDim.withValues(
                              alpha: 0.16,
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              readOnly: widget.isGenerating,
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
                                  color: EverloreTheme.ash.withValues(
                                    alpha: 0.45,
                                  ),
                                  fontStyle: FontStyle.italic,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.fromLTRB(
                                  12,
                                  12,
                                  16,
                                  12,
                                ),
                              ),
                              textInputAction: TextInputAction.newline,
                              onSubmitted: (_) => _submit(),
                            ),
                          ),
                        ],
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

class _NarrationMarkerButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _NarrationMarkerButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Add narration/action markers',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 7, 4, 7),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: enabled ? onTap : null,
            child: SizedBox(
              width: 34,
              height: 32,
              child: Center(
                child: Text(
                  '*',
                  style: EverloreTheme.ui(
                    size: 18,
                    weight: FontWeight.w800,
                    color: enabled
                        ? EverloreTheme.gold.withValues(alpha: 0.9)
                        : EverloreTheme.ash.withValues(alpha: 0.4),
                    spacing: 0.5,
                  ),
                ),
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
      child: ClipOval(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
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
      ),
    );
  }
}
