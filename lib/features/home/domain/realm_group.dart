import '../../../shared/models/world_instance.dart';

/// One published world the player has entered — may have several stories in progress.
class RealmGroup {
  final String templateId;
  final Map<String, dynamic>? template;
  final List<WorldInstance> stories;
  final int? totalStoryCount;

  const RealmGroup({
    required this.templateId,
    required this.template,
    required this.stories,
    this.totalStoryCount,
  });

  WorldInstance get latest => stories.first;
  int get storyCount => totalStoryCount ?? stories.length;
  bool get hasMultipleStories => storyCount > 1;

  String get title =>
      template?['title'] as String? ??
      latest.template?['title'] as String? ??
      'Untitled Realm';
}

RealmGroup realmGroupFromJson(Map<String, dynamic> json) {
  final template = json['template'] is Map
      ? Map<String, dynamic>.from(json['template'] as Map)
      : null;
  final latestRaw = Map<String, dynamic>.from(json['latest'] as Map? ?? {});
  if (template != null) latestRaw['template'] = template;
  final latest = WorldInstance.fromJson(latestRaw);
  return RealmGroup(
    templateId: json['template_id']?.toString() ?? latest.templateId,
    template: template,
    stories: [latest],
    totalStoryCount: (json['story_count'] as num?)?.toInt() ?? 1,
  );
}

List<RealmGroup> groupInstancesByRealm(List<WorldInstance> instances) {
  final byTemplate = <String, List<WorldInstance>>{};
  for (final instance in instances) {
    byTemplate.putIfAbsent(instance.templateId, () => []).add(instance);
  }

  final groups = byTemplate.entries.map((entry) {
    final stories = List<WorldInstance>.from(entry.value)
      ..sort((a, b) {
        final aAt = a.meta.lastActiveAt ?? a.createdAt ?? DateTime(0);
        final bAt = b.meta.lastActiveAt ?? b.createdAt ?? DateTime(0);
        return bAt.compareTo(aAt);
      });
    return RealmGroup(
      templateId: entry.key,
      template: stories.first.template,
      stories: stories,
    );
  }).toList();

  groups.sort((a, b) {
    final aAt = a.latest.meta.lastActiveAt ?? a.latest.createdAt ?? DateTime(0);
    final bAt = b.latest.meta.lastActiveAt ?? b.latest.createdAt ?? DateTime(0);
    return bAt.compareTo(aAt);
  });

  return groups;
}
