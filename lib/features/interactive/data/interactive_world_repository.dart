import '../../../core/network/api_client.dart';
import '../domain/interactive_world.dart';

/// Transport boundary for the illustrated-world renderer. Presentation code
/// receives typed maps from here; it never constructs route unlocks itself.
class InteractiveWorldRepository {
  const InteractiveWorldRepository();

  Future<Map<String, dynamic>> loadWorld(String worldKey) async {
    final value = await ApiClient.get('/interactive-worlds/$worldKey');
    return Map<String, dynamic>.from(value as Map);
  }

  /// The walkable worlds this player may enter.
  ///
  /// Asked for rather than known: the client used to name one world by hand,
  /// so a second one would not have appeared. An empty list is an ordinary
  /// answer — a player with no walkable world open to them is offered none.
  Future<List<InteractiveWorldEntrance>> listPlayable() async {
    final value = await ApiClient.get('/interactive-worlds');
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((raw) =>
            InteractiveWorldEntrance.fromJson(Map<String, dynamic>.from(raw)))
        .where((world) => world.worldKey.isNotEmpty)
        .toList();
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
      },
    );
    return Map<String, dynamic>.from(value as Map);
  }
}
