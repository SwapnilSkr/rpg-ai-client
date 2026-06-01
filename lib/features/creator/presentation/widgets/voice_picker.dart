import 'package:flutter/material.dart';
import '../../../../app/theme/nexus_theme.dart';
import '../../../../shared/narrative_styles.dart';

/// Reusable narrative-voice picker: a labelled grid of preset chips with a
/// one-line blurb for the selected voice. Used in both character and world
/// creation so the writing register is chosen up front (the strongest lever on
/// how the story actually reads).
class VoicePicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  final String label;

  /// Optional free-text refinements layered ON TOP of the chosen preset. When
  /// [onNotesChanged] is null the notes field is hidden (e.g. in-chat sheet).
  final String notes;
  final ValueChanged<String>? onNotesChanged;

  const VoicePicker({
    super.key,
    required this.selected,
    required this.onSelect,
    this.label = 'VOICE & STYLE',
    this.notes = '',
    this.onNotesChanged,
  });

  @override
  Widget build(BuildContext context) {
    final current = kNarrativeStyles.firstWhere(
      (s) => s.key == selected,
      orElse: () => kNarrativeStyles.first,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: EverloreTheme.ui(
                    size: 13,
                    color: EverloreTheme.parchment,
                    weight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'How it should read — diction, energy, and rhythm. This is locked to your world; players can\'t change it.',
          style: EverloreTheme.ui(size: 12, color: EverloreTheme.ash, height: 1.4),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kNarrativeStyles.map((s) {
            final isSel = s.key == selected;
            return GestureDetector(
              onTap: () => onSelect(s.key),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: isSel
                      ? EverloreTheme.gold.withValues(alpha: 0.12)
                      : EverloreTheme.void3,
                  border: Border.all(
                    color: isSel
                        ? EverloreTheme.gold.withValues(alpha: 0.5)
                        : EverloreTheme.goldDim.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  s.label,
                  style: EverloreTheme.ui(
                    size: 13,
                    color: isSel ? EverloreTheme.gold : EverloreTheme.ash,
                    weight: isSel ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (current.blurb.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            current.blurb,
            style: EverloreTheme.ui(
                size: 12,
                color: EverloreTheme.gold.withValues(alpha: 0.8),
                height: 1.4),
          ),
        ],
        if (onNotesChanged != null) ...[
          const SizedBox(height: 14),
          Text('CUSTOM NOTES (OPTIONAL)',
              style: EverloreTheme.ui(
                  size: 11,
                  color: EverloreTheme.ash,
                  weight: FontWeight.w700,
                  spacing: 1.2)),
          const SizedBox(height: 6),
          TextFormField(
            // Uncontrolled: initialValue seeds it once; the field keeps its own
            // cursor/state across parent rebuilds (e.g. tapping a voice chip).
            initialValue: notes,
            onChanged: onNotesChanged,
            maxLines: 3,
            minLines: 2,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            style: EverloreTheme.ui(
                size: 13, color: EverloreTheme.parchment, height: 1.5),
            decoration: InputDecoration(
              hintText:
                  'Refine the voice — e.g. "she swears when flustered; dry, deadpan humor".',
              hintStyle: EverloreTheme.ui(size: 12, color: EverloreTheme.ash),
              counterText: '',
              filled: true,
              fillColor: EverloreTheme.void4.withValues(alpha: 0.5),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: EverloreTheme.goldDim.withValues(alpha: 0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: EverloreTheme.goldDim.withValues(alpha: 0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: EverloreTheme.gold, width: 1.2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
