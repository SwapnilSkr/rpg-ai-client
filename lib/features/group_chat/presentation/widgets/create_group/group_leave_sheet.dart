import 'package:flutter/material.dart';

import 'package:everlore/app/theme/nexus_theme.dart';
import 'package:everlore/shared/widgets/everlore_sheet.dart';

/// Asks if the user wants to leave with unsaved changes:
/// "Leave without saving?" (Leave / Keep editing).
Future<bool> showLeaveUnsavedSheet(BuildContext context) async {
  final result = await showEverloreSheet<bool>(
    context: context,
    builder: (sheetContext) => const _GroupConfirmSheetContent(
      title: 'Leave without saving?',
      body: 'Your unsaved changes will be lost.',
      confirmLabel: 'Leave',
      cancelLabel: 'Keep editing',
    ),
  );
  return result == true;
}

/// Asks if the user wants to stop drafting:
/// "Stop writing this group?" (Stop / Keep waiting).
Future<bool> showStopDraftingSheet(BuildContext context) async {
  final result = await showEverloreSheet<bool>(
    context: context,
    builder: (sheetContext) => const _GroupConfirmSheetContent(
      title: 'Stop writing this group?',
      body: 'You can always write it again from the form.',
      confirmLabel: 'Stop',
      cancelLabel: 'Keep waiting',
    ),
  );
  return result == true;
}

class _GroupConfirmSheetContent extends StatelessWidget {
  final String title;
  final String body;
  final String confirmLabel;
  final String cancelLabel;

  const _GroupConfirmSheetContent({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.cancelLabel,
  });

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
              title,
              style: EverloreTheme.serifDisplay(
                size: 20,
                color: EverloreTheme.parchment,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
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
                    child: Text(
                      cancelLabel,
                      style: const TextStyle(
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
                    child: Text(
                      confirmLabel,
                      style: const TextStyle(
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
