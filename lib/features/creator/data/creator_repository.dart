import 'dart:async';

import '../../../core/auth/auth_service.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/world_template.dart';
import '../../templates/data/template_repository.dart';

class CreatorRepository {
  static List<WorldTemplate>? _mineCache;
  static int _cacheEpoch = AuthService.sessionEpoch.value;

  static void _syncSessionCache() {
    final epoch = AuthService.sessionEpoch.value;
    if (_cacheEpoch == epoch) return;
    _cacheEpoch = epoch;
    _mineCache = null;
  }

  static Future<WorldTemplate> getById(String id) async {
    _syncSessionCache();
    final response = await ApiClient.get('/templates/$id');
    return WorldTemplate.fromJson(Map<String, dynamic>.from(response as Map));
  }

  static Future<List<WorldTemplate>> listMine({
    bool forceRefresh = false,
  }) async {
    _syncSessionCache();
    final cached = _mineCache;
    if (!forceRefresh && cached != null) {
      _fetchMine().ignore();
      return cached;
    }
    return _fetchMine();
  }

  static Future<List<WorldTemplate>> _fetchMine() async {
    _syncSessionCache();
    final response = await ApiClient.get('/templates/mine/list');
    final raw = response is List ? response : (response['templates'] as List);
    final rows = raw.map((e) => WorldTemplate.fromJson(e)).toList();
    _mineCache = rows;
    return rows;
  }

  static void invalidate() {
    _cacheEpoch = AuthService.sessionEpoch.value;
    _mineCache = null;
    TemplateRepository.invalidate();
  }

  static Future<WorldTemplate> create(Map<String, dynamic> body) async {
    final response = await ApiClient.post('/templates', body: body);
    final json = (response is Map && response.containsKey('template'))
        ? response['template']
        : response;
    invalidate();
    return WorldTemplate.fromJson(json);
  }

  static Future<WorldTemplate> update(
    String id,
    Map<String, dynamic> body,
  ) async {
    final response = await ApiClient.put('/templates/$id', body: body);
    final json = (response is Map && response.containsKey('template'))
        ? response['template']
        : response;
    invalidate();
    return WorldTemplate.fromJson(json);
  }

  static Future<void> publish(String id) async {
    await ApiClient.post('/templates/$id/publish');
    invalidate();
  }

  static Future<void> delete(String id) async {
    await ApiClient.delete('/templates/$id');
    invalidate();
  }

  /// One-shot AI autofill — drafts an entire world/character from an optional
  /// brief. Returns the raw draft map for the caller to apply + edit.
  static Future<Map<String, dynamic>> autofill(
    Map<String, dynamic> body,
  ) async {
    final response = await ApiClient.post('/templates/autofill', body: body);
    final map = Map<String, dynamic>.from(response as Map);
    return Map<String, dynamic>.from(map['draft'] as Map? ?? {});
  }

  /// Generate a preview image from a prompt → returns its CDN URL. Re-callable
  /// to re-roll until the creator is satisfied.
  static Future<String> generateImage(String prompt) async {
    final response = await ApiClient.post(
      '/templates/image/generate',
      body: {'prompt': prompt},
    );
    final map = Map<String, dynamic>.from(response as Map);
    return (map['url'] ?? '').toString();
  }
}
