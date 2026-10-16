import 'package:flutter/material.dart';

import '../../../../app/theme/nexus_theme.dart';
import '../../../../shared/widgets/neu.dart';

/// Shared Keepsakes empty/error state composition (§3.5):
/// soft illustrated vignette, title in Cinzel display caps,
/// body copy, and one primary action within thumb reach.
class KeepsakesStateView extends StatelessWidget {
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;
  final bool compact;
  final bool isError;

  const KeepsakesStateView({
    super.key,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
    this.compact = false,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = isError ? EverloreTheme.ember : EverloreTheme.gold;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: 32,
          vertical: compact ? 24 : 48,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Crest glyph over the painting
              Container(
                padding: EdgeInsets.all(compact ? 12 : 16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: EverloreTheme.void0.withValues(alpha: 0.6),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.15),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(
                  isError
                      ? Icons.cloud_off_rounded
                      : (compact
                          ? Icons.collections_bookmark_outlined
                          : Icons.auto_stories_rounded),
                  color: accentColor,
                  size: compact ? 24 : 36,
                ),
              ),
              SizedBox(height: compact ? 16 : 24),
              // Title in Cinzel display caps
              Text(
                title.toUpperCase(),
                textAlign: TextAlign.center,
                style: EverloreTheme.serifDisplay(
                  size: compact ? 16 : 19,
                  color: EverloreTheme.parchment,
                  spacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              // Body copy
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: EverloreTheme.aiText.fontFamily,
                  fontSize: compact ? 13.5 : 15,
                  height: 1.5,
                  color: EverloreTheme.ash,
                ),
              ),
              SizedBox(height: compact ? 20 : 28),
              // Primary action
              NeuButton(
                label: actionLabel,
                primary: true,
                accent: accentColor,
                onTap: onAction,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
