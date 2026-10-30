import 'package:flutter/material.dart';

import '../../app/theme/nexus_theme.dart';
import '../../shared/widgets/everlore_sheet.dart';

/// The player's choice in [KeepStorySheet].
enum KeepStoryResult {
  /// The player wants to sign in and keep their story.
  signIn,

  /// The player chose "Not now" or dismissed the sheet.
  notNow,
}

/// In-story bottom sheet inviting guests to sign in and keep their progress.
/// Spec: `everlore-docs/phases/first-run.md` FR-5.
class KeepStorySheet extends StatefulWidget {
  const KeepStorySheet({super.key});

  /// Presents the sheet on the root navigator.
  static Future<KeepStoryResult?> show(BuildContext context) {
    return showEverloreSheet<KeepStoryResult>(
      context: context,
      builder: (_) => const KeepStorySheet(),
    );
  }

  @override
  State<KeepStorySheet> createState() => _KeepStorySheetState();
}

class _KeepStorySheetState extends State<KeepStorySheet> {
  bool _answered = false;

  void _onAnswer(KeepStoryResult result) {
    if (_answered) return;
    _answered = true;
    Navigator.of(context).pop(result);
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
              'Keep your story',
              style: EverloreTheme.serifDisplay(
                size: 20,
                color: EverloreTheme.parchment,
                weight: FontWeight.w600,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "You've played the first part as a guest. Sign in and everything you've done stays yours: this story, your name and your choices.",
              style: EverloreTheme.aiText.copyWith(
                fontSize: 16,
                color: EverloreTheme.ash,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => _onAnswer(KeepStoryResult.signIn),
                style: FilledButton.styleFrom(
                  backgroundColor: EverloreTheme.gold,
                  foregroundColor: EverloreTheme.void0,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Sign in to keep it',
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
                onPressed: () => _onAnswer(KeepStoryResult.notNow),
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
