import 'dart:async';

import '../../../core/auth/auth_service.dart';
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
  static final Map<bool, List<WorldInstance>> _instancesCache = {};
  static final Map<String, RealmTemplateStories> _storiesByTemplateCache = {};
  static final Map<String, RealmPlayStatus> _playStatusCache = {};
  static int _cacheEpoch = AuthService.sessionEpoch.value;

  static Stream<RealmChange> get realmChanges => _realmChanges.stream;

  static void invalidate({String? templateId}) {
    _cacheEpoch = AuthService.sessionEpoch.value;
    _instancesCache.clear();
    if (templateId == null) {
      _storiesByTemplateCache.clear();
      _playStatusCache.clear();
    } else {
      _storiesByTemplateCache.remove(templateId);
      _playStatusCache.remove(templateId);
    }
  }

  static void _syncSessionCache() {
    final epoch = AuthService.sessionEpoch.value;
    if (_cacheEpoch == epoch) return;
    _cacheEpoch = epoch;
    _instancesCache.clear();
    _storiesByTemplateCache.clear();
    _playStatusCache.clear();
  }

  /// Fast check before entering a world — has the player been here before?
  static Future<RealmPlayStatus> getPlayStatus(
    String templateId, {
    bool forceRefresh = false,
  }) async {
    _syncSessionCache();
    final cached = _playStatusCache[templateId];
    if (!forceRefresh && cached != null) {
      _fetchPlayStatus(templateId).ignore();
      return cached;
    }
    return _fetchPlayStatus(templateId);
  }

  static Future<RealmPlayStatus> _fetchPlayStatus(String templateId) async {
    _syncSessionCache();
    final response = await ApiClient.get('/instances/play-status/$templateId');
    final status = RealmPlayStatus.fromJson(
      Map<String, dynamic>.from(response),
    );
    _playStatusCache[templateId] = status;
    return status;
  }

  /// All in-progress stories for one world, with a one-line preview each.
  static Future<RealmTemplateStories> getStoriesByTemplate(
    String templateId, {
    bool forceRefresh = false,
  }) async {
    _syncSessionCache();
    final cached = _storiesByTemplateCache[templateId];
    if (!forceRefresh && cached != null) {
      _fetchStoriesByTemplate(templateId).ignore();
      return cached;
    }
    return _fetchStoriesByTemplate(templateId);
  }

  static Future<RealmTemplateStories> _fetchStoriesByTemplate(
    String templateId,
  ) async {
    _syncSessionCache();
    final response = await ApiClient.get('/instances/by-template/$templateId');
    final stories = RealmTemplateStories.fromJson(
      Map<String, dynamic>.from(response),
    );
    _storiesByTemplateCache[templateId] = stories;
    return stories;
  }

  static Future<List<WorldInstance>> getInstances({
    bool includeArchived = false,
    bool forceRefresh = false,
  }) async {
    _syncSessionCache();
    final cached = _instancesCache[includeArchived];
    if (!forceRefresh && cached != null) {
      _fetchInstances(includeArchived: includeArchived).ignore();
      return cached;
    }
    return _fetchInstances(includeArchived: includeArchived);
  }

  static Future<List<WorldInstance>> _fetchInstances({
    bool includeArchived = false,
  }) async {
    _syncSessionCache();
    final response = await ApiClient.get(
      '/instances?include_archived=$includeArchived',
    );
    final list = response as List;
    final instances = list.map((e) => WorldInstance.fromJson(e)).toList();
    _instancesCache[includeArchived] = instances;
    return instances;
  }

  static Future<WorldInstance> createInstance(String templateId) async {
    final response = await ApiClient.post(
      '/instances',
      body: {'template_id': templateId},
    );
    final instance = response['instance'];
    final created = WorldInstance.fromJson(instance);
    invalidate(templateId: templateId);
    _realmChanges.add(RealmChange.created(created));
    return created;
  }

  static Future<void> archiveInstance(String instanceId) async {
    await ApiClient.post('/instances/$instanceId/archive');
    invalidate();
    _realmChanges.add(RealmChange.removed(instanceId));
  }

  static Future<void> deleteInstance(String instanceId) async {
    await ApiClient.delete('/instances/$instanceId');
    invalidate();
    _realmChanges.add(RealmChange.removed(instanceId));
  }

  /// Reset a playthrough to its opening line: server wipes all events, memories
  /// (incl. Pinecone vectors), scene summaries and emergent characters, restores
  /// default world state, and re-seeds the protagonist + opening greeting.
  static Future<void> resetInstance(String instanceId) async {
    await ApiClient.post('/instances/$instanceId/reset');
    invalidate();
    _realmChanges.add(RealmChange.updated(instanceId));
  }
}
