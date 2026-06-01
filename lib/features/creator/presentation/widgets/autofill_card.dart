import 'package:flutter/material.dart';
import '../../../../app/theme/nexus_theme.dart';

/// "Generate with AI" entry point shown at the top of the creation flows.
///
/// Tapping it opens a modal that asks the creator — in their own words — what
/// they want this world/character to be. That single response (which can be as
/// short or vague as they like, or even blank for a surprise) drives the entire
/// AI draft: every field plus the image prompt. If the creator never uses this,
/// the whole form — image prompt included — stays empty for them to fill by hand.
///
/// The two settings that steer the draft — World Type and Mature — live inside
/// the modal itself. Flipping them writes straight back to the cubit, so the
/// form and the modal always agree and nothing is lost when the sheet closes.
class AutofillLauncher extends StatelessWidget {
  /// 'world' or 'character' — tailors the modal's wording.
  final String target;
  final bool busy;
  final String? error;
  final void Function(String brief) onGenerate;

  /// Current World Type. Only meaningful for worlds (`true` = Conscious Soul,
  /// `false` = Game Master); pass `null` for characters (always conscious).
  final bool? isSentient;

  /// Current Mature toggle — loosens the themes the draft may explore.
  final bool isNsfwCapable;

  /// Write-through setters so the modal toggles update the single source of
  /// truth (the cubit). [onSetSentient] is only used for worlds.
  final void Function(bool v)? onSetSentient;
  final void Function(bool v) onSetNsfw;

  const AutofillLauncher({
    super.key,
    required this.target,
    required this.busy,
    required this.error,
    required this.onGenerate,
    this.isSentient,
    required this.isNsfwCapable,
    this.onSetSentient,
    required this.onSetNsfw,
  });

  bool get _isChar => target == 'character';

  Future<void> _open(BuildContext context) async {
    final brief = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AutofillSheet(
        isChar: _isChar,
        isSentient: isSentient,
        isNsfwCapable: isNsfwCapable,
        onSetSentient: onSetSentient,
        onSetNsfw: onSetNsfw,
      ),
    );
    if (brief != null) onGenerate(brief);
  }

  @override
  Widget build(BuildContext context) {
    final subject = _isChar ? 'character' : 'world';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: busy ? null : () => _open(context),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: [
                  EverloreTheme.violet.withValues(alpha: 0.18),
                  EverloreTheme.violetBright.withValues(alpha: 0.06),
                ],
              ),
              border: Border.all(
                  color: EverloreTheme.violetBright.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: EverloreTheme.violet.withValues(alpha: 0.25),
                  ),
                  alignment: Alignment.center,
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: EverloreTheme.violetBright),
                        )
                      : const Icon(Icons.auto_awesome,
                          size: 18, color: EverloreTheme.violetBright),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(busy ? 'Drafting…' : 'Generate with AI',
                          style: EverloreTheme.ui(
                              size: 14,
                              color: EverloreTheme.parchment,
                              weight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                          busy
                              ? 'Conjuring your $subject — one moment.'
                              : 'Tell the AI your idea and set the tone — it drafts everything for you to edit.',
                          style: EverloreTheme.ui(
                              size: 12,
                              color: EverloreTheme.ash,
                              height: 1.35)),
                    ],
                  ),
                ),
                if (!busy)
                  const Icon(Icons.chevron_right,
                      size: 20, color: EverloreTheme.violetBright),
              ],
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(error!,
              style: EverloreTheme.ui(size: 12, color: EverloreTheme.crimson)),
        ],
      ],
    );
  }
}

/// Modal that collects the creator's free-text idea for the AI draft, plus the
/// settings that steer it (World Type / Mature). Toggling those writes straight
/// back through the setter callbacks, so the cubit is always the source of truth
/// and the form stays in sync after the sheet closes.
class _AutofillSheet extends StatefulWidget {
  final bool isChar;
  final bool? isSentient;
  final bool isNsfwCapable;
  final void Function(bool v)? onSetSentient;
  final void Function(bool v) onSetNsfw;
  const _AutofillSheet({
    required this.isChar,
    required this.isSentient,
    required this.isNsfwCapable,
    required this.onSetSentient,
    required this.onSetNsfw,
  });

  @override
  State<_AutofillSheet> createState() => _AutofillSheetState();
}

class _AutofillSheetState extends State<_AutofillSheet> {
  final _ctrl = TextEditingController();

  // Local mirrors for instant UI; each change is written through to the cubit.
  late bool _sentient;
  late bool _nsfw;

  @override
  void initState() {
    super.initState();
    _sentient = widget.isSentient ?? true;
    _nsfw = widget.isNsfwCapable;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _setSentient(bool v) {
    setState(() => _sentient = v);
    widget.onSetSentient?.call(v);
  }

  void _setNsfw(bool v) {
    setState(() => _nsfw = v);
    widget.onSetNsfw(v);
  }

  @override
  Widget build(BuildContext context) {
    final subject = widget.isChar ? 'character' : 'world';
    final hint = widget.isChar
        ? 'e.g. a tsundere childhood friend who is secretly an idol'
        : 'e.g. a cozy magical coffee shop in a floating sky-city';
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        // Cap height so the sheet never exceeds the visible area; the body
        // scrolls when the keyboard is up, so nothing overflows.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: EverloreTheme.void1,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: EverloreTheme.ash.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome,
                            size: 18, color: EverloreTheme.violetBright),
                        const SizedBox(width: 8),
                        Text('GENERATE WITH AI',
                            style: EverloreTheme.ui(
                                size: 13,
                                color: EverloreTheme.violetBright,
                                weight: FontWeight.w800,
                                spacing: 1.5)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'What should this $subject be? Describe it however you like — a few '
                      'words is plenty. The AI fills in every detail (including the image '
                      'prompt), and you can edit all of it afterward.',
                      style: EverloreTheme.ui(
                          size: 13, color: EverloreTheme.ash, height: 1.45),
                    ),
                    const SizedBox(height: 16),
                    _SteerControls(
                      isChar: widget.isChar,
                      showWorldType: !widget.isChar && widget.isSentient != null,
                      sentient: _sentient,
                      nsfw: _nsfw,
                      onSentient: _setSentient,
                      onNsfw: _setNsfw,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _ctrl,
                      autofocus: true,
                      maxLines: 4,
                      minLines: 3,
                      maxLength: 1000,
                      textCapitalization: TextCapitalization.sentences,
                      style: EverloreTheme.ui(
                          size: 14,
                          color: EverloreTheme.parchment,
                          height: 1.5),
                      decoration: InputDecoration(
                        hintText: hint,
                        hintStyle: EverloreTheme.ui(
                            size: 13, color: EverloreTheme.ash),
                        counterText: '',
                        filled: true,
                        fillColor: EverloreTheme.void0.withValues(alpha: 0.6),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                              color: EverloreTheme.violetBright
                                  .withValues(alpha: 0.25)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                              color: EverloreTheme.violetBright
                                  .withValues(alpha: 0.25)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: EverloreTheme.violetBright, width: 1.2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            Navigator.of(context).pop(_ctrl.text.trim()),
                        icon: const Icon(Icons.auto_fix_high, size: 18),
                        label: const Text('Draft it'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: EverloreTheme.violet,
                          foregroundColor: EverloreTheme.parchment,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(''),
                        child: Text('Surprise me',
                            style: EverloreTheme.ui(
                                size: 13, color: EverloreTheme.ash)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Interactive settings that steer the draft, living in the modal. Changes are
/// pushed back to the cubit immediately via the callbacks, so the form reflects
/// them too. World Type decides a Conscious-Soul persona vs a Game-Master
/// narrator; Mature decides whether the draft may explore mature themes.
class _SteerControls extends StatelessWidget {
  final bool isChar;
  final bool showWorldType;
  final bool sentient;
  final bool nsfw;
  final void Function(bool) onSentient;
  final void Function(bool) onNsfw;
  const _SteerControls({
    required this.isChar,
    required this.showWorldType,
    required this.sentient,
    required this.nsfw,
    required this.onSentient,
    required this.onNsfw,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: EverloreTheme.void0.withValues(alpha: 0.5),
        border: Border.all(color: EverloreTheme.goldDim.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, size: 14, color: EverloreTheme.gold),
              const SizedBox(width: 6),
              Text('STEERS THIS DRAFT',
                  style: EverloreTheme.ui(
                      size: 10.5,
                      color: EverloreTheme.gold,
                      weight: FontWeight.w700,
                      spacing: 1.2)),
            ],
          ),
          if (showWorldType) ...[
            const SizedBox(height: 12),
            _Segmented(
              label: 'World Type',
              valueIsLeft: sentient,
              leftIcon: Icons.psychology_alt,
              leftLabel: 'Conscious Soul',
              leftColor: EverloreTheme.violet,
              rightIcon: Icons.auto_stories,
              rightLabel: 'Game Master',
              rightColor: EverloreTheme.cyan,
              onLeft: () => onSentient(true),
              onRight: () => onSentient(false),
            ),
          ],
          const SizedBox(height: 12),
          _MatureRow(value: nsfw, onChanged: onNsfw, isChar: isChar),
        ],
      ),
    );
  }
}

/// Two-option segmented control (World Type).
class _Segmented extends StatelessWidget {
  final String label;
  final bool valueIsLeft;
  final IconData leftIcon;
  final String leftLabel;
  final Color leftColor;
  final IconData rightIcon;
  final String rightLabel;
  final Color rightColor;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  const _Segmented({
    required this.label,
    required this.valueIsLeft,
    required this.leftIcon,
    required this.leftLabel,
    required this.leftColor,
    required this.rightIcon,
    required this.rightLabel,
    required this.rightColor,
    required this.onLeft,
    required this.onRight,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: EverloreTheme.ui(
                size: 10.5,
                color: EverloreTheme.ash,
                weight: FontWeight.w700,
                spacing: 1.0)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _segBtn(leftIcon, leftLabel, leftColor, valueIsLeft, onLeft),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _segBtn(
                  rightIcon, rightLabel, rightColor, !valueIsLeft, onRight),
            ),
          ],
        ),
      ],
    );
  }

  Widget _segBtn(
      IconData icon, String label, Color color, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          color: active
              ? color.withValues(alpha: 0.16)
              : EverloreTheme.void0.withValues(alpha: 0.4),
          border: Border.all(
            color: active
                ? color.withValues(alpha: 0.6)
                : EverloreTheme.ash.withValues(alpha: 0.15),
            width: active ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 15,
                color: active ? color : EverloreTheme.ash),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: EverloreTheme.ui(
                      size: 12.5,
                      color:
                          active ? EverloreTheme.parchment : EverloreTheme.ash,
                      weight: active ? FontWeight.w700 : FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mature on/off row with a switch.
class _MatureRow extends StatelessWidget {
  final bool value;
  final void Function(bool) onChanged;
  final bool isChar;
  const _MatureRow(
      {required this.value, required this.onChanged, required this.isChar});

  @override
  Widget build(BuildContext context) {
    final subject = isChar ? 'character' : 'world';
    return Row(
      children: [
        Icon(Icons.shield_outlined,
            size: 16,
            color: value ? EverloreTheme.crimson : EverloreTheme.ash),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mature',
                  style: EverloreTheme.ui(
                      size: 13,
                      color: EverloreTheme.parchment,
                      weight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                  value
                      ? 'The draft may explore mature, NSFW-capable themes for this $subject.'
                      : 'The draft stays within safe-for-all themes.',
                  style: EverloreTheme.ui(
                      size: 11.5, color: EverloreTheme.ash, height: 1.35)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: EverloreTheme.crimson,
        ),
      ],
    );
  }
}
