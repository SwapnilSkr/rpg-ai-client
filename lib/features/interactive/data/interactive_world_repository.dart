import '../../../core/network/api_client.dart';
import '../../../shared/models/world_template.dart';

/// Transport boundary for the illustrated-world renderer. Presentation code
/// receives typed maps from here; it never constructs route unlocks itself.
class InteractiveWorldRepository {
  const InteractiveWorldRepository();

  Future<Map<String, dynamic>> loadWorld(String worldKey) async {
    final value = await ApiClient.get('/interactive-worlds/$worldKey');
    return Map<String, dynamic>.from(value as Map);
  }

  /// Published walkable worlds for Explore. No sign-in required.
  Future<List<WorldTemplate>> listPublished({String search = ''}) async {
    final query = search.trim().isEmpty
        ? ''
        : '?search=${Uri.encodeQueryComponent(search.trim())}';
    final value = await ApiClient.get('/interactive-worlds$query');
    final raw = value is List ? value : const [];
    return raw
        .whereType<Map>()
        .map((row) => WorldTemplate.fromJson(Map<String, dynamic>.from(row)))
        .where((world) => world.interactiveWorldKey != null)
        .toList();
  }

  Future<({List<WorldTemplate> worlds, int total, int page})> listMine({
    int page = 1,
    int limit = 20,
    String search = '',
  }) async {
    final query = <String>['page=$page', 'limit=$limit'];
    if (search.trim().isNotEmpty) {
      query.add('search=${Uri.encodeQueryComponent(search.trim())}');
    }
    final response = await ApiClient.get(
      '/interactive-worlds/mine?${query.join('&')}',
    );
    final raw = (response['templates'] as List?) ?? const [];
    final worlds = raw
        .map((e) => WorldTemplate.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return (
      worlds: worlds,
      total: (response['total'] as num?)?.toInt() ?? worlds.length,
      page: (response['page'] as num?)?.toInt() ?? page,
    );
  }

  Future<void> publish(String worldKey) async {
    await ApiClient.post('/interactive-worlds/$worldKey/publish');
  }

  Future<void> delete(String worldKey) async {
    await ApiClient.delete('/interactive-worlds/$worldKey');
  }

  Future<String> createInstance(String worldKey) async {
    final value = await ApiClient.post('/interactive-worlds/$worldKey/instances');
    final map = Map<String, dynamic>.from(value as Map);
    final instance = Map<String, dynamic>.from(map['instance'] as Map? ?? map);
    final id = instance['_id']?.toString().trim() ?? '';
    if (id.isEmpty) {
      throw ApiException(statusCode: 502, message: 'Unknown error');
    }
    return id;
  }

  /// The player's save for this world, created on first walk.
  ///
  /// Opening the map without this id is the authoring preview, which is how
  /// play used to land with nothing persisting.
  Future<String> resolveInstance(String worldKey) async {
    final value = await ApiClient.get('/interactive-worlds/$worldKey/instance');
    final map = Map<String, dynamic>.from(value as Map);
    final id = map['instance_id']?.toString().trim() ?? '';
    if (id.isEmpty) {
      throw ApiException(statusCode: 502, message: 'Unknown error');
    }
    return id;
  }

  Future<Map<String, dynamic>> loadInstance({
    required String worldKey,
    required String instanceId,
  }) async {
    final value = await ApiClient.get(
      '/interactive-worlds/$worldKey/instances/$instanceId',
    );
    return Map<String, dynamic>.from(value as Map);
  }

  Future<Map<String, dynamic>> act({
    required String worldKey,
    required String instanceId,
    required String type,
    String? locationId,
    String? choiceId,
    String? petitionId,
    String? resolutionId,
    String? characterId,
    String? said,
    String? checkpointId,
    String? drillId,
  }) async {
    final value = await ApiClient.post(
      '/interactive-worlds/$worldKey/instances/$instanceId/actions',
      body: {
        'type': type,
        if (locationId != null) 'location_id': locationId,
        if (choiceId != null) 'choice_id': choiceId,
        if (petitionId != null) 'petition_id': petitionId,
        if (resolutionId != null) 'resolution_id': resolutionId,
        if (characterId != null) 'character_id': characterId,
        if (said != null) 'said': said,
        if (checkpointId != null) 'checkpoint_id': checkpointId,
        if (drillId != null) 'drill_id': drillId,
      },
    );
    return Map<String, dynamic>.from(value as Map);
  }
}
