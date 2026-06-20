import 'dart:async';

import '../../../core/auth/auth_service.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/world_template.dart';

class TemplateRepository {
  static final Map<String, Map<String, dynamic>> _listCache = {};
  static final Map<String, WorldTemplate> _templateCache = {};
  static int _cacheEpoch = AuthService.sessionEpoch.value;

  static void invalidate() {
    _cacheEpoch = AuthService.sessionEpoch.value;
    _listCache.clear();
    _templateCache.clear();
  }

  static void _syncSessionCache() {
    final epoch = AuthService.sessionEpoch.value;
    if (_cacheEpoch == epoch) return;
    _cacheEpoch = epoch;
    _listCache.clear();
    _templateCache.clear();
  }

  static Future<Map<String, dynamic>> listPublished({
    int page = 1,
    int limit = 20,
    String? search,
    bool forceRefresh = false,
  }) async {
    _syncSessionCache();
    String path = '/templates?page=$page&limit=$limit';
    if (search != null && search.isNotEmpty) path += '&search=$search';
    final cached = _listCache[path];
    if (!forceRefresh && cached != null) {
      _fetchPublished(path).ignore();
      return cached;
    }
    return _fetchPublished(path);
  }

  static Future<Map<String, dynamic>> _fetchPublished(String path) async {
    _syncSessionCache();
    final response = await ApiClient.get(path);
    final templates = (response['templates'] as List)
        .map((e) => WorldTemplate.fromJson(e))
        .toList();
    final result = {'templates': templates, 'total': response['total']};
    _listCache[path] = result;
    for (final template in templates) {
      _templateCache[template.id] = template;
    }
    return result;
  }

  static Future<WorldTemplate> getById(
    String id, {
    bool forceRefresh = false,
  }) async {
    _syncSessionCache();
    final cached = _templateCache[id];
    if (!forceRefresh && cached != null) {
      _fetchById(id).ignore();
      return cached;
    }
    return _fetchById(id);
  }

  static Future<WorldTemplate> _fetchById(String id) async {
    _syncSessionCache();
    final response = await ApiClient.get('/templates/$id');
    final template = WorldTemplate.fromJson(response);
    _templateCache[id] = template;
    return template;
  }
}
