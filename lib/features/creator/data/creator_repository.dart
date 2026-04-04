import '../../../core/network/api_client.dart';
import '../../../shared/models/world_template.dart';

class CreatorRepository {
  static Future<WorldTemplate> getById(String id) async {
    final response = await ApiClient.get('/templates/$id');
    return WorldTemplate.fromJson(Map<String, dynamic>.from(response as Map));
  }

  static Future<List<WorldTemplate>> listMine() async {
    final response = await ApiClient.get('/templates/mine/list');
    final raw = response is List ? response : (response['templates'] as List);
    return raw.map((e) => WorldTemplate.fromJson(e)).toList();
  }

  static Future<WorldTemplate> create(Map<String, dynamic> body) async {
    final response = await ApiClient.post('/templates', body: body);
    final json = (response is Map && response.containsKey('template'))
        ? response['template']
        : response;
    return WorldTemplate.fromJson(json);
  }

  static Future<WorldTemplate> update(String id, Map<String, dynamic> body) async {
    final response = await ApiClient.put('/templates/$id', body: body);
    final json = (response is Map && response.containsKey('template'))
        ? response['template']
        : response;
    return WorldTemplate.fromJson(json);
  }

  static Future<void> publish(String id) async {
    await ApiClient.post('/templates/$id/publish');
  }
}
