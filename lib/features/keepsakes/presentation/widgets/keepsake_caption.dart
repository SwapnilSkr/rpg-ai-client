import 'package:flutter/material.dart';

import '../../../../app/theme/nexus_theme.dart';
import '../../../../shared/widgets/story_prose.dart';
import '../../models/keepsake_item.dart';

/// Formats the caption spans for a Keepsake item in the feed and viewer.
///
/// For a line film, the spoken excerpt is passed enclosed in quotes through
/// [storyProseSpans] so that it renders as dialogue (upright, bold speech)
/// rather than muted italic narration.
List<InlineSpan> keepsakeCaptionSpans(
  KeepsakeItem item, {
  required double fontSize,
  required double height,
}) {
  final excerpt = item.excerpt?.trim();
  if (excerpt == null || excerpt.isEmpty) return const [];

  final baseStyle = EverloreTheme.aiText.copyWith(
    fontSize: fontSize,
    height: height,
  );

  final isQuoted = (excerpt.startsWith('"') && excerpt.endsWith('"')) ||
      (excerpt.startsWith('“') && excerpt.endsWith('”'));
  final text = item.isLineFilm
      ? (isQuoted ? excerpt : '"$excerpt"')
      : excerpt;

  return storyProseSpans(
    text,
    narrationStyle: baseStyle.copyWith(
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w400,
      color: EverloreTheme.parchment.withValues(alpha: 0.95),
    ),
    dialogueStyle: baseStyle.copyWith(
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.w600,
      color: EverloreTheme.parchment,
    ),
  );
}
