import 'package:flutter/material.dart';
import '../../../../../app/theme/nexus_theme.dart';
import '../../../../../shared/models/world_template.dart';

/// Renders the review and visibility status of a world template.
///
/// States:
/// - unpublished: 'Draft'
/// - private: 'Just for you'
/// - pending: 'Awaiting the seal'
/// - approved: 'Shared with all'
/// - changes_requested: 'Needs changes', with review note underneath in quotes.
class WorldStatusChip extends StatelessWidget {
  final WorldTemplate template;
  final bool isWorking;
  final bool showNote;
  final double maxNoteWidth;

  const WorldStatusChip({
    super.key,
    required this.template,
    this.isWorking = false,
    this.showNote = true,
    this.maxNoteWidth = 160,
  });

  Color _statusColor(WorldReviewState state) {
    if (isWorking) return EverloreTheme.gold;
    return switch (state) {
      WorldReviewState.unpublished => EverloreTheme.ember,
      WorldReviewState.private => EverloreTheme.ash,
      WorldReviewState.pending => EverloreTheme.gold,
      WorldReviewState.approved => EverloreTheme.verdant,
      WorldReviewState.changesRequested => EverloreTheme.crimson,
    };
  }

  IconData _statusIcon(WorldReviewState state) {
    return switch (state) {
      WorldReviewState.unpublished => Icons.edit_note,
      WorldReviewState.private => Icons.lock_outline,
      WorldReviewState.pending => Icons.hourglass_empty,
      WorldReviewState.approved => Icons.public,
      WorldReviewState.changesRequested => Icons.warning_amber_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = template.reviewState;
    final color = _statusColor(state);
    final label = isWorking ? 'Publishing…' : template.reviewStateLabel;
    final note = template.reviewNote?.trim();
    final hasNote = showNote &&
        state == WorldReviewState.changesRequested &&
        note != null &&
        note.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isWorking)
                SizedBox(
                  width: 11,
                  height: 11,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.4,
                    color: color,
                  ),
                )
              else
                Icon(_statusIcon(state), size: 11, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        if (hasNote) ...[
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxNoteWidth),
            child: Text(
              '"$note"',
              textAlign: TextAlign.end,
              style: EverloreTheme.aiText.copyWith(
                color: EverloreTheme.crimson,
                fontSize: 11,
                fontStyle: FontStyle.italic,
                height: 1.3,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
