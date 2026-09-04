import 'package:flutter/material.dart';

import '../../../../core/guide/guide_anchor.dart';
import '../../../../core/guide/guide_ids.dart';
import '../../../../../app/theme/nexus_theme.dart';
import '../../../../../shared/models/character_profile.dart';
import '../../../../../shared/models/relation_candidate.dart';
import 'world_actions_button.dart';
import '../../../../app/layout/responsive.dart';

class PlayerInput extends StatefulWidget {
  /// Locks the text field and send orb (prose still revealing, rewind, replay).
  final bool composerLocked;

  /// Locks continue / travel / relationship while a turn is still persisting.
  final bool worldActionsLocked;

  /// A send is waiting for the in-flight turn to persist.
  final bool hasQueuedSend;

  final bool isConnected;
  final ValueChanged<String> onSend;

  /// Explicit world controls shown while the composer is empty.
  final VoidCallback? onContinue;

  /// Long-press time-skip ('hours' | 'day' | 'days' | 'season').
  final ValueChanged<String>? onAdvance;

  final void Function(
    String destination,
    List<String> companions,
    String? advance,
  )?
  onTravel;
  final Future<bool> Function(
    String character,
    String relation,
    bool correction,
    String? replacesRelation,
  )?
  onRelationship;
  final List<CharacterProfile> characters;

  /// Latest settled scene cast. The journey control must not offer people who
  /// exist in the codex but are currently elsewhere.
  final List<String> presentCharacters;
  final Future<List<String>> Function()? loadKnownDestinations;
  final Future<bool> Function(CharacterProfile character, String newName)?
  onRenameCharacter;
  final Future<List<RelationCandidate>> Function()? loadRelationCandidates;
  final Future<Map<String, String>> Function()? loadConfirmedKinship;
  final Future<bool> Function(
    String candidateId,
    String action,
    String? relation,
  )?
  onResolveRelationCandidate;

  /// One-shot composer prefill (bond actions: "Approach Mira…"). The input
  /// consumes the value (fills + focuses) and resets it to null.
  final ValueNotifier<String?>? draft;

  /// Transient in-flight status (e.g. retrying after a hiccup). When set during
  /// generation it replaces the default "unfolds" hint so a stalled-looking
  /// stream reads as "still coming" instead of dead.
  final String? notice;

  const PlayerInput({
    super.key,
    required this.composerLocked,
    required this.worldActionsLocked,
    required this.hasQueuedSend,
    required this.isConnected,
    required this.onSend,
    this.onContinue,
    this.onAdvance,
    this.onTravel,
    this.onRelationship,
    this.characters = const [],
    this.presentCharacters = const [],
    this.loadKnownDestinations,
    this.onRenameCharacter,
    this.loadRelationCandidates,
    this.loadConfirmedKinship,
    this.onResolveRelationCandidate,
    this.draft,
    this.notice,
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
    if (!oldWidget.composerLocked && widget.composerLocked) {
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
    if (text.isEmpty || widget.composerLocked) return;
    widget.onSend(text);
    _controller.clear();
    _focusNode.unfocus();
  }

  void _insertNarrationMarkers() {
    if (widget.composerLocked || !widget.isConnected) return;

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
    final canSend = _hasText && !widget.composerLocked && widget.isConnected;
    final composerEnabled = !widget.composerLocked && widget.isConnected;
    final worldEnabled = !widget.worldActionsLocked && widget.isConnected;

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
                    child: GuideAnchor(
                      id: GuideIds.playComposer,
                      child: ValueListenableBuilder<bool>(
                        valueListenable: _focusedNotifier,
                        builder: (context, focused, child) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: EverloreTheme.void2.withValues(
                                alpha: 0.85,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: focused
                                    ? EverloreTheme.gold.withValues(alpha: 0.55)
                                    : EverloreTheme.goldDim.withValues(
                                        alpha: 0.22,
                                      ),
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
                                GuideAnchor(
                                  id: GuideIds.playNarrationMarker,
                                  child: _NarrationMarkerButton(
                                    enabled: composerEnabled,
                                    focused: focused,
                                    onTap: _insertNarrationMarkers,
                                  ),
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
                          enabled: composerEnabled,
                          hintText: _hintText(),
                          onSubmit: composerEnabled ? _submit : null,
                        ),
                      ),
                    ),
                  ),
                  // World actions appear when the composer is empty and
                  // yields its spot to the send orb once the player types.
                  if (!_hasText &&
                      widget.onContinue != null &&
                      widget.onAdvance != null &&
                      widget.onTravel != null &&
                      widget.onRelationship != null) ...[
                    const SizedBox(width: 10),
                    GuideAnchor(
                      id: GuideIds.playWorldActions,
                      child: WorldActionsButton(
                        enabled: worldEnabled,
                        onContinue: widget.onContinue!,
                        onAdvance: widget.onAdvance!,
                        onTravel: widget.onTravel!,
                        onRelationship: widget.onRelationship!,
                        characters: widget.characters,
                        presentCharacters: widget.presentCharacters,
                        loadKnownDestinations: widget.loadKnownDestinations,
                        onRenameCharacter: widget.onRenameCharacter,
                        loadRelationCandidates: widget.loadRelationCandidates,
                        loadConfirmedKinship: widget.loadConfirmedKinship,
                        onResolveRelationCandidate:
                            widget.onResolveRelationCandidate,
                      ),
                    ),
                  ],
                  const SizedBox(width: 10),
                  GuideAnchor(
                    id: GuideIds.playSend,
                    child: _SendOrb(
                      canSend: canSend,
                      onTap: canSend ? _submit : null,
                    ),
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
    if (!widget.isConnected) return 'Reconnecting…';
    if (widget.composerLocked) {
      return widget.notice ?? 'The story unfolds…';
    }
    if (widget.hasQueuedSend) {
      return widget.notice ?? 'Sending when this scene settles…';
    }
    if (widget.worldActionsLocked) {
      return widget.notice ?? 'You can reply — the scene is still settling.';
    }
    if (widget.notice != null) return widget.notice!;
    // Two round controls and the action-marker button leave the field about
    // half a narrow phone wide, and at large system text "What do you do?"
    // came out as "What do y...". Ask it in fewer words instead of in fewer
    // letters.
    return EvLayout.of(context).isCompact ? 'What now?' : 'What do you do?';
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
        // The field's height follows what has been typed, not the hint, so a
        // hint that wraps is simply drawn past the bottom of the box — which
        // is what a narrow phone at large text does to "What do you do?".
        hintMaxLines: 1,
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
  final bool canSend;
  final VoidCallback? onTap;

  const _SendOrb({required this.canSend, this.onTap});

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
              // Keep the send affordance visually stable while a turn is in
              // progress. The hourglass already communicates generation; a
              // second spinner in the send orb looked actionable and implied a
              // separate loading operation. [onTap] is null while disabled.
              child: Icon(
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
