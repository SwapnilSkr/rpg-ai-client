import 'package:flutter/material.dart';

import '../../../../app/theme/nexus_theme.dart';
import '../../../../core/reminders/push_ask.dart';
import '../../../../shared/widgets/everlore_sheet.dart';

/// Asks, after the player's first reply in a group chat, whether to be told
/// when someone writes back. Same look as the story reminder sheet.
class PushAskSheet extends StatefulWidget {
  const PushAskSheet({super.key});

  /// Presents the sheet on the root navigator and records the answer.
  /// Dismissal (swipe, back, barrier tap) counts as "Not now".
  static Future<void> show(BuildContext context, {PushAsk? ask}) async {
    final policy = ask ?? PushAsk.instance;
    if (!policy.claim()) return;
    final answer = await showEverloreSheet<bool>(
      context: context,
      builder: (_) => const PushAskSheet(),
    );
    await policy.answer(yes: answer ?? false);
  }

  @override
  State<PushAskSheet> createState() => _PushAskSheetState();
}

class _PushAskSheetState extends State<PushAskSheet> {
  bool _answered = false;

  void _onAnswer(bool yes) {
    if (_answered) return;
    _answered = true;
    Navigator.of(context).pop(yes);
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
              'Hear when they write back?',
              style: EverloreTheme.aiText.copyWith(
                fontSize: 20,
                color: EverloreTheme.parchment,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "We'll let you know when someone in your chats writes to you. Never at night.",
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
                onPressed: () => _onAnswer(true),
                style: FilledButton.styleFrom(
                  backgroundColor: EverloreTheme.gold,
                  foregroundColor: EverloreTheme.void0,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Yes, let me know',
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
                onPressed: () => _onAnswer(false),
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
