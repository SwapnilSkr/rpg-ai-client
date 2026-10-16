import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../core/config/env.dart';
import '../../../core/storage/secure_storage.dart';
import '../../home/data/home_repository.dart';
import '../models/keepsake_item.dart';

abstract class KeepsakesRepository {
  Future<KeepsakesPage> getKeepsakes({
    KeepsakesFilter filter = KeepsakesFilter.all,
    String? before,
    int limit = 20,
  });

  Future<void> hideKeepsake(String mediaId);

  Future<bool> hasAnySaves();
}

class HttpKeepsakesRepository implements KeepsakesRepository {
  final http.Client _client;
  final String? _baseUrl;
  final Future<String?> Function()? _tokenProvider;

  HttpKeepsakesRepository({
    http.Client? client,
    String? baseUrl,
    Future<String?> Function()? tokenProvider,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl,
        _tokenProvider = tokenProvider;

  String get _resolvedBaseUrl => _baseUrl ?? AppConfig.apiBaseUrl;

  Future<Map<String, String>> _authHeaders() async {
    final token = _tokenProvider != null
        ? await _tokenProvider()
        : await SecureStore.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  @override
  Future<KeepsakesPage> getKeepsakes({
    KeepsakesFilter filter = KeepsakesFilter.all,
    String? before,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'kind': filter.apiKind,
      'limit': limit.clamp(1, 40).toString(),
    };
    if (before != null && before.isNotEmpty) {
      queryParams['before'] = before;
    }

    final uri = Uri.parse('$_resolvedBaseUrl/media/keepsakes').replace(
      queryParameters: queryParams,
    );
    final headers = await _authHeaders();
    final res = await _client.get(uri, headers: headers);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        return KeepsakesPage.fromJson(decoded);
      }
      return const KeepsakesPage(items: []);
    }

    throw Exception('Failed to load keepsakes: ${res.statusCode}');
  }

  @override
  Future<void> hideKeepsake(String mediaId) async {
    final uri = Uri.parse('$_resolvedBaseUrl/media/keepsakes/$mediaId/hide');
    final headers = await _authHeaders();
    final res = await _client.post(uri, headers: headers);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return;
    }
    throw Exception('Failed to hide keepsake: ${res.statusCode}');
  }

  @override
  Future<bool> hasAnySaves() async {
    try {
      final instances = await HomeRepository.getInstances();
      return instances.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
