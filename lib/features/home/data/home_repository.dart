import 'dart:async';

import '../../../core/network/api_client.dart';
import '../../../shared/models/realm_play_status.dart';
import '../../../shared/models/world_instance.dart';

enum RealmChangeKind { created, updated, removed }

class RealmChange {
  final RealmChangeKind kind;
  final String instanceId;
  final WorldInstance? instance;

  const RealmChange._(this.kind, this.instanceId, this.instance);

  RealmChange.created(WorldInstance instance)
    : this._(RealmChangeKind.created, instance.id, instance);

  const RealmChange.updated(String instanceId)
    : this._(RealmChangeKind.updated, instanceId, null);

  const RealmChange.removed(String instanceId)
    : this._(RealmChangeKind.removed, instanceId, null);
}

class HomeRepository {
  static final StreamController<RealmChange> _realmChanges =
      StreamController<RealmChange>.broadcast();

  static Stream<RealmChange> get realmChanges => _realmChanges.stream;

  /// Fast check before entering a world — has the player been here before?
  static Future<RealmPlayStatus> getPlayStatus(String templateId) async {
    final response = await ApiClient.get('/instances/play-status/$templateId');
    return RealmPlayStatus.fromJson(Map<String, dynamic>.from(response));
  }

  /// All in-progress stories for one world, with a one-line preview each.
  static Future<RealmTemplateStories> getStoriesByTemplate(
    String templateId,
  ) async {
    final response = await ApiClient.get('/instances/by-template/$templateId');
    return RealmTemplateStories.fromJson(Map<String, dynamic>.from(response));
  }

  static Future<List<WorldInstance>> getInstances({
    bool includeArchived = false,
  }) async {
    final response = await ApiClient.get(
      '/instances?include_archived=$includeArchived',
    );
    final list = response as List;
    return list.map((e) => WorldInstance.fromJson(e)).toList();
  }

  static Future<WorldInstance> createInstance(String templateId) async {
    final response = await ApiClient.post(
      '/instances',
      body: {'template_id': templateId},
    );
    final instance = response['instance'];
    final created = WorldInstance.fromJson(instance);
    _realmChanges.add(RealmChange.created(created));
    return created;
  }

  static Future<void> archiveInstance(String instanceId) async {
    await ApiClient.post('/instances/$instanceId/archive');
    _realmChanges.add(RealmChange.removed(instanceId));
  }

  static Future<void> deleteInstance(String instanceId) async {
    await ApiClient.delete('/instances/$instanceId');
    _realmChanges.add(RealmChange.removed(instanceId));
  }

  /// Reset a playthrough to its opening line: server wipes all events, memories
  /// (incl. Pinecone vectors), scene summaries and emergent characters, restores
  /// default world state, and re-seeds the protagonist + opening greeting.
  static Future<void> resetInstance(String instanceId) async {
    await ApiClient.post('/instances/$instanceId/reset');
    _realmChanges.add(RealmChange.updated(instanceId));
  }
}
