import 'package:flutter/material.dart';
import '../../../../../app/theme/nexus_theme.dart';
import '../../../../../shared/models/world_template.dart';

/// In-page notice card for Your Worlds screen.
///
/// Under the Oct 15 2026 contract:
/// - changes_requested: "{title} needs changes", then the note, then "Edit world".
/// - approved: "{title} is now shared with every traveller".
class WorldReviewNoticeCard extends StatelessWidget {
  final WorldTemplate template;
  final VoidCallback onDismiss;
  final VoidCallback? onEdit;

  const WorldReviewNoticeCard({
    super.key,
    required this.template,
    required this.onDismiss,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isChangesRequested =
        template.reviewStatus == 'changes_requested';
    final accentColor =
        isChangesRequested ? EverloreTheme.crimson : EverloreTheme.verdant;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: EverloreTheme.void2.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isChangesRequested
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline,
                size: 20,
                color: accentColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isChangesRequested
                      ? '${template.title} needs changes'
                      : '${template.title} is now shared with every traveller',
                  style: EverloreTheme.ui(
                    size: 14,
                    weight: FontWeight.w700,
                    color: EverloreTheme.parchment,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onDismiss,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: EverloreTheme.ash.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
          if (isChangesRequested &&
              template.reviewNote != null &&
              template.reviewNote!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: Text(
                template.reviewNote!.trim(),
                style: EverloreTheme.aiText.copyWith(
                  fontSize: 13,
                  color: EverloreTheme.ash,
                  height: 1.4,
                ),
              ),
            ),
          ],
          if (isChangesRequested && onEdit != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: OutlinedButton(
                onPressed: onEdit,
                style: OutlinedButton.styleFrom(
                  foregroundColor: EverloreTheme.gold,
                  side: BorderSide(
                    color: EverloreTheme.gold.withValues(alpha: 0.6),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Edit world',
                  style: EverloreTheme.ui(
                    size: 12,
                    weight: FontWeight.w600,
                    color: EverloreTheme.gold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
