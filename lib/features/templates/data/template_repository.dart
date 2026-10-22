import 'dart:async';

import 'package:flutter/foundation.dart';

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
    listPublishedOverride = null;
  }

  static void _syncSessionCache() {
    final epoch = AuthService.sessionEpoch.value;
    if (_cacheEpoch == epoch) return;
    _cacheEpoch = epoch;
    _listCache.clear();
    _templateCache.clear();
  }

  static String buildPublishedPath({
    int page = 1,
    int limit = 20,
    String? search,
    String? genre,
    String? kind,
    Iterable<String>? styles,
    String? sort,
  }) {
    final queryParameters = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (search != null && search.trim().isNotEmpty) {
      queryParameters['search'] = search.trim();
    }
    if (genre != null && genre.isNotEmpty) {
      queryParameters['genre'] = genre;
    }
    if (kind != null && kind.isNotEmpty) {
      queryParameters['kind'] = kind;
    }
    if (styles != null && styles.isNotEmpty) {
      final sortedStyles = styles.toList()..sort();
      queryParameters['styles'] = sortedStyles.join(',');
    }
    if (sort != null && sort.isNotEmpty) {
      queryParameters['sort'] = sort;
    }
    return Uri(path: '/templates', queryParameters: queryParameters).toString();
  }

  @visibleForTesting
  static Future<Map<String, dynamic>> Function({
    int page,
    int limit,
    String? search,
    String? genre,
    String? kind,
    Iterable<String>? styles,
    String? sort,
    bool forceRefresh,
  })? listPublishedOverride;

  @visibleForTesting
  static bool isPathCached(String path) => _listCache.containsKey(path);

  @visibleForTesting
  static Map<String, dynamic>? getCached(String path) => _listCache[path];

  @visibleForTesting
  static void setCached(String path, Map<String, dynamic> data) =>
      _listCache[path] = data;

  static Future<Map<String, dynamic>> listPublished({
    int page = 1,
    int limit = 20,
    String? search,
    String? genre,
    String? kind,
    Iterable<String>? styles,
    String? sort,
    bool forceRefresh = false,
  }) async {
    if (listPublishedOverride != null) {
      return listPublishedOverride!(
        page: page,
        limit: limit,
        search: search,
        genre: genre,
        kind: kind,
        styles: styles,
        sort: sort,
        forceRefresh: forceRefresh,
      );
    }
    _syncSessionCache();
    final path = buildPublishedPath(
      page: page,
      limit: limit,
      search: search,
      genre: genre,
      kind: kind,
      styles: styles,
      sort: sort,
    );
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
