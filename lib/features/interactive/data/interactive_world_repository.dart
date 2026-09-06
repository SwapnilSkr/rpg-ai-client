import '../../../core/network/api_client.dart';

/// Transport boundary for the illustrated-world renderer. Presentation code
/// receives typed maps from here; it never constructs route unlocks itself.
class InteractiveWorldRepository {
  const InteractiveWorldRepository();

  Future<Map<String, dynamic>> loadWorld(String worldKey) async {
    final value = await ApiClient.get('/interactive-worlds/$worldKey');
    return Map<String, dynamic>.from(value as Map);
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
  }) async {
    final value = await ApiClient.post(
      '/interactive-worlds/$worldKey/instances/$instanceId/actions',
      body: {
        'type': type,
        if (locationId != null) 'location_id': locationId,
        if (choiceId != null) 'choice_id': choiceId,
        if (petitionId != null) 'petition_id': petitionId,
        if (resolutionId != null) 'resolution_id': resolutionId,
      },
    );
    return Map<String, dynamic>.from(value as Map);
  }
}
