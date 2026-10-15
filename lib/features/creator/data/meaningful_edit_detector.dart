import 'dart:convert';
import '../../../shared/models/world_template.dart';

/// Detects whether an edit to a world touches any of the fields that require
/// admin re-review under the world-review contract.
///
/// Meaningful fields:
/// - title, description, image_url
/// - seed_prompt, global_lore, opening_line
/// - protagonist, seed_cast
/// - is_nsfw_capable, kind, is_sentient
///
/// Other fields (stats, flags, limits, preferences) do not trigger re-review.
class MeaningfulEditDetector {
  static const Set<String> meaningfulFields = {
    'title',
    'description',
    'image_url',
    'seed_prompt',
    'global_lore',
    'opening_line',
    'protagonist',
    'seed_cast',
    'is_nsfw_capable',
    'kind',
    'is_sentient',
  };

  /// Compares an existing [WorldTemplate] against an update payload map.
  static bool hasMeaningfulChanges(
    WorldTemplate original,
    Map<String, dynamic> payload,
  ) {
    if (payload.containsKey('title') &&
        _differs(payload['title'], original.title)) {
      return true;
    }
    if (payload.containsKey('description') &&
        _differs(payload['description'], original.description)) {
      return true;
    }
    if (payload.containsKey('image_url') &&
        payload['image_url'] != original.imageUrl) {
      return true;
    }
    if (payload.containsKey('seed_prompt') &&
        _differs(payload['seed_prompt'], original.seedPrompt)) {
      return true;
    }
    if (payload.containsKey('global_lore') &&
        _differs(payload['global_lore'], original.globalLore)) {
      return true;
    }
    if (payload.containsKey('opening_line') &&
        _differs(payload['opening_line'], original.openingLine)) {
      return true;
    }
    if (payload.containsKey('is_nsfw_capable') &&
        payload['is_nsfw_capable'] != original.isNsfwCapable) {
      return true;
    }
    if (payload.containsKey('kind') && payload['kind'] != original.kind) {
      return true;
    }
    if (payload.containsKey('is_sentient') &&
        payload['is_sentient'] != original.isSentient) {
      return true;
    }
    if (payload.containsKey('protagonist')) {
      final p = jsonEncode(payload['protagonist']);
      if (p != 'null' && p != '{}') return true;
    }
    if (payload.containsKey('seed_cast')) {
      final sc = jsonEncode(payload['seed_cast']);
      if (sc != 'null' && sc != '[]') return true;
    }
    return false;
  }

  // The forge trims text fields before saving, so a world whose stored text
  // carries stray whitespace must not read as edited.
  static bool _differs(Object? next, String original) =>
      next is String ? next.trim() != original.trim() : next != original;

  /// Compares two [WorldTemplate] instances for meaningful changes.
  static bool hasMeaningfulTemplateChanges(
    WorldTemplate original,
    WorldTemplate updated,
  ) {
    return original.title != updated.title ||
        original.description != updated.description ||
        original.imageUrl != updated.imageUrl ||
        original.seedPrompt != updated.seedPrompt ||
        original.globalLore != updated.globalLore ||
        original.openingLine != updated.openingLine ||
        original.isNsfwCapable != updated.isNsfwCapable ||
        original.kind != updated.kind ||
        original.isSentient != updated.isSentient;
  }

  /// Determines whether saving [payload] to [original] requires confirmation.
  static bool shouldConfirmResubmit(
    WorldTemplate original,
    Map<String, dynamic> payload,
  ) {
    if (!original.isPublished) return false;
    final isApproved =
        original.reviewStatus == 'approved' ||
        (original.visibility != 'private' && original.reviewStatus == null);
    if (!isApproved) return false;
    return hasMeaningfulChanges(original, payload);
  }
}
