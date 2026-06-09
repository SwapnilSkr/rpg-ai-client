import 'package:flutter/material.dart';
import '../../../../../app/theme/nexus_theme.dart';
import 'advance_time_button.dart';

class PlayerInput extends StatefulWidget {
  final bool isGenerating;
  final bool isConnected;
  final ValueChanged<String> onSend;

  /// Tap on the hourglass — quiet continue. Null hides the control.
  final VoidCallback? onContinue;

  /// Long-press time-skip ('hours' | 'day' | 'days' | 'season').
  final ValueChanged<String>? onAdvance;

  /// One-shot composer prefill (bond actions: "Approach Mira…"). The input
  /// consumes the value (fills + focuses) and resets it to null.
  final ValueNotifier<String?>? draft;

  const PlayerInput({
    super.key,
    required this.isGenerating,
    required this.isConnected,
    required this.onSend,
    this.onContinue,
    this.onAdvance,
    this.draft,
  });

  @override
  State<PlayerInput> createState() => _PlayerInputState();
}

class _PlayerInputState extends State<PlayerInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _focusedNotifier = ValueNotifier(false);
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
    _focusedNotifier.value = _focusNode.hasFocus;
    widget.draft?.addListener(_consumeDraft);
  }

  @override
  void didUpdateWidget(PlayerInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isGenerating && widget.isGenerating) {
      _focusNode.unfocus();
    }
    if (!identical(oldWidget.draft, widget.draft)) {
      oldWidget.draft?.removeListener(_consumeDraft);
      widget.draft?.addListener(_consumeDraft);
    }
  }

  @override
  void dispose() {
    widget.draft?.removeListener(_consumeDraft);
    _controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    _focusedNotifier.dispose();
    super.dispose();
  }

  void _consumeDraft() {
    final d = widget.draft?.value;
    if (d == null || d.isEmpty) return;
    widget.draft?.value = null;
    _controller.value = TextEditingValue(
      text: d,
      selection: TextSelection.collapsed(offset: d.length),
    );
    _focusNode.requestFocus();
  }

  void _onTextChanged() {
    final has = _controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  void _onFocusChanged() {
    final focused = _focusNode.hasFocus;
    if (_focusedNotifier.value != focused) {
      _focusedNotifier.value = focused;
    }
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isGenerating) return;
    widget.onSend(text);
    _controller.clear();
    _focusNode.unfocus();
  }

  void _insertNarrationMarkers() {
    if (widget.isGenerating || !widget.isConnected) return;

    void insert() {
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
      final cursor = selected.isEmpty ? lo + 1 : lo + markerText.length;

      _controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: cursor),
        composing: TextRange.empty,
      );
    }

    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) insert();
      });
      return;
    }
    insert();
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _hasText && !widget.isGenerating && widget.isConnected;
    final enabled = !widget.isGenerating && widget.isConnected;

    return Container(
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
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _focusedNotifier,
                      builder: (context, focused, child) {
                        return AnimatedContainer(
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
                          padding: const EdgeInsets.only(left: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _NarrationMarkerButton(
                                enabled: enabled,
                                focused: focused,
                                onTap: _insertNarrationMarkers,
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 11),
                                child: _InputPrefixDivider(focused: focused),
                              ),
                              Expanded(child: child!),
                            ],
                          ),
                        );
                      },
                      child: _ComposerTextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        enabled: enabled,
                        hintText: _hintText(),
                        onSubmit: enabled ? _submit : null,
                      ),
                    ),
                  ),
                  // The hourglass appears when the composer is empty (the
                  // "nothing to say — let the world move" affordance) and
                  // yields its spot to the send orb once the player types.
                  if (!_hasText &&
                      widget.onContinue != null &&
                      widget.onAdvance != null) ...[
                    const SizedBox(width: 10),
                    AdvanceTimeButton(
                      enabled: enabled,
                      onContinue: widget.onContinue!,
                      onAdvance: widget.onAdvance!,
                    ),
                  ],
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

/// Stable text field — kept out of focus-driven rebuilds so taps place a cursor
/// instead of wedging selection on the last grapheme (especially around *).
class _ComposerTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final String hintText;
  final VoidCallback? onSubmit;

  const _ComposerTextField({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.hintText,
    this.onSubmit,
  });

  @override
  State<_ComposerTextField> createState() => _ComposerTextFieldState();
}

class _ComposerTextFieldState extends State<_ComposerTextField> {
  void _onTap() {
    // Let the platform handle the tap first, then collapse accidental
    // single-character selections (common when retapping near * markers).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.focusNode.hasFocus) return;
      _collapseStuckSingleCharSelection();
    });
  }

  void _collapseStuckSingleCharSelection() {
    final sel = widget.controller.selection;
    if (!sel.isValid || sel.isCollapsed) return;
    if (sel.end - sel.start != 1) return;
    widget.controller.selection = TextSelection.collapsed(offset: sel.end);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      maxLines: 5,
      minLines: 1,
      style: EverloreTheme.ui(
        size: 15,
        color: EverloreTheme.parchment,
        height: 1.4,
      ),
      decoration: InputDecoration(
        isCollapsed: true,
        filled: false,
        hintText: widget.hintText,
        hintStyle: EverloreTheme.ui(
          size: 14,
          color: EverloreTheme.ash.withValues(alpha: 0.45),
          fontStyle: FontStyle.italic,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        contentPadding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
      ),
      textInputAction: TextInputAction.newline,
      onTap: _onTap,
      onSubmitted: widget.onSubmit != null ? (_) => widget.onSubmit!() : null,
    );
  }
}

/// Hairline between the narration prefix and the text capture area.
class _InputPrefixDivider extends StatelessWidget {
  final bool focused;

  const _InputPrefixDivider({required this.focused});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 22,
      color: (focused ? EverloreTheme.gold : EverloreTheme.goldDim).withValues(
        alpha: 0.28,
      ),
    );
  }
}

class _NarrationMarkerButton extends StatelessWidget {
  final bool enabled;
  final bool focused;
  final VoidCallback onTap;

  const _NarrationMarkerButton({
    required this.enabled,
    required this.focused,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Wrap selection in *action* markers',
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
        splashColor: EverloreTheme.gold.withValues(alpha: 0.08),
        highlightColor: EverloreTheme.gold.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
          child: Text(
            '**',
            style: EverloreTheme.ui(
              size: 17,
              weight: FontWeight.w800,
              color: !enabled
                  ? EverloreTheme.ash.withValues(alpha: 0.35)
                  : focused
                  ? EverloreTheme.gold
                  : EverloreTheme.gold.withValues(alpha: 0.75),
              spacing: 0.5,
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
    this.onTap,
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
