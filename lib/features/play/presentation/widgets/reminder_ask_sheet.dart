import 'package:flutter/material.dart';

import '../../../../app/theme/nexus_theme.dart';
import '../../../../core/reminders/reminder_service.dart';
import '../../../../shared/widgets/everlore_sheet.dart';

/// In-story bottom sheet asking whether the player wants story reminders.
/// Spec: `everlore-docs/phases/notifications.md` §1.3.
class ReminderAskSheet extends StatefulWidget {
  const ReminderAskSheet({super.key});

  /// Presents the sheet on the root navigator and records the player's answer.
  /// Dismissal (swipe, back, barrier tap) counts as [ReminderAskAnswer.notNow].
  static Future<void> show(BuildContext context) async {
    final answer = await showEverloreSheet<ReminderAskAnswer>(
      context: context,
      builder: (_) => const ReminderAskSheet(),
    );
    final effective = answer ?? ReminderAskAnswer.notNow;
    await ReminderService.instance.recordAsk(effective);
    if (effective == ReminderAskAnswer.yes) {
      await ReminderService.instance.requestSystemPermission();
    }
  }

  @override
  State<ReminderAskSheet> createState() => _ReminderAskSheetState();
}

class _ReminderAskSheetState extends State<ReminderAskSheet> {
  bool _answered = false;

  void _onAnswer(ReminderAskAnswer answer) {
    if (_answered) return;
    _answered = true;
    Navigator.of(context).pop(answer);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetGrabHandle(),
            const SizedBox(height: 16),
            Text(
              "Want a nudge when your story's waiting?",
              style: EverloreTheme.serifDisplay(
                size: 20,
                color: EverloreTheme.parchment,
                weight: FontWeight.w600,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "We'll let you know now and then, never at night.",
              style: EverloreTheme.aiText.copyWith(
                fontSize: 15,
                color: EverloreTheme.ash,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => _onAnswer(ReminderAskAnswer.yes),
                style: FilledButton.styleFrom(
                  backgroundColor: EverloreTheme.gold,
                  foregroundColor: EverloreTheme.void0,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Yes, remind me',
                  style: EverloreTheme.ui(
                    size: 15,
                    weight: FontWeight.w700,
                    color: EverloreTheme.void0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: () => _onAnswer(ReminderAskAnswer.notNow),
                style: TextButton.styleFrom(
                  foregroundColor: EverloreTheme.ash,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Not now',
                  style: EverloreTheme.ui(
                    size: 14,
                    weight: FontWeight.w600,
                    color: EverloreTheme.ash,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
