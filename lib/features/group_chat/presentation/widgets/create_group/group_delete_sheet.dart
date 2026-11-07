import 'package:flutter/material.dart';

import 'package:everlore/app/theme/nexus_theme.dart';
import 'package:everlore/shared/widgets/everlore_sheet.dart';

/// Shows the confirmation sheet before deleting a group.
///
/// Plain, calm words: "Delete this group? Chats already started with it keep going."
Future<bool> showGroupDeleteSheet(BuildContext context) async {
  final result = await showEverloreSheet<bool>(
    context: context,
    builder: (sheetContext) => const _GroupDeleteSheetContent(),
  );
  return result == true;
}

class _GroupDeleteSheetContent extends StatelessWidget {
  const _GroupDeleteSheetContent();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetGrabHandle(),
            const SizedBox(height: 16),
            Text(
              'Delete this group?',
              style: EverloreTheme.serifDisplay(
                size: 20,
                color: EverloreTheme.parchment,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Chats already started with it keep going.',
              style: EverloreTheme.aiText.copyWith(
                fontSize: 14,
                color: EverloreTheme.ash,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: EverloreTheme.parchment,
                      side: BorderSide(
                        color: EverloreTheme.goldDim.withValues(alpha: 0.35),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Keep',
                      style: TextStyle(
                        fontFamily: EverloreTheme.uiFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: EverloreTheme.crimson,
                      foregroundColor: Colors.white,
                      disabledForegroundColor: EverloreTheme.ash.withValues(
                        alpha: 0.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Delete',
                      style: TextStyle(
                        fontFamily: EverloreTheme.uiFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
