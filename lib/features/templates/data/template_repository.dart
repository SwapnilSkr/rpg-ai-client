import '../../../core/network/api_client.dart';
import '../../../shared/models/world_template.dart';

class TemplateRepository {
  static Future<Map<String, dynamic>> listPublished({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    String path = '/templates?page=$page&limit=$limit';
    if (search != null && search.isNotEmpty) path += '&search=$search';
    final response = await ApiClient.get(path);
    final templates = (response['templates'] as List)
        .map((e) => WorldTemplate.fromJson(e))
        .toList();
    return {
      'templates': templates,
      'total': response['total'],
    };
  }

  static Future<WorldTemplate> getById(String id) async {
    final response = await ApiClient.get('/templates/$id');
    return WorldTemplate.fromJson(response);
  }
}
