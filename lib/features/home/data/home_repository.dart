import '../../../core/network/api_client.dart';
import '../../../shared/models/world_instance.dart';

class HomeRepository {
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
    final response = await ApiClient.post('/instances', body: {
      'template_id': templateId,
    });
    final instance = response['instance'];
    return WorldInstance.fromJson(instance);
  }

  static Future<void> archiveInstance(String instanceId) async {
    await ApiClient.post('/instances/$instanceId/archive');
  }
}
