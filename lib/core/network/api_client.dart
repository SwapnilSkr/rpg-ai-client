import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/env.dart';
import '../storage/secure_storage.dart';

class ApiClient {
  static final _client = http.Client();

  static Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await SecureStore.getToken();
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<dynamic> get(String path) async {
    final response = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: await _headers(),
    );
    return _handleResponse(response);
  }

  static Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: await _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  /// Uploads a selected image without forcing a lossy client-side re-encode.
  /// The API validates and losslessly normalizes the bytes before returning its
  /// CDN URL, so every caller renders it through the normal image cache.
  static Future<dynamic> postImage(
    String path, {
    required Uint8List bytes,
    required String filename,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
    );
    request.headers.addAll(await _headers(json: false));
    request.files.add(
      http.MultipartFile.fromBytes('image', bytes, filename: filename),
    );
    final response = await http.Response.fromStream(await request.send());
    return _handleResponse(response);
  }

  static Future<dynamic> put(String path, {Map<String, dynamic>? body}) async {
    final response = await _client.put(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: await _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  static Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _client.patch(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: await _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  static Future<dynamic> delete(String path) async {
    final response = await _client.delete(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: await _headers(),
    );
    return _handleResponse(response);
  }

  static dynamic _handleResponse(http.Response response) {
    final ok = response.statusCode >= 200 && response.statusCode < 300;

    dynamic body;
    try {
      body = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      // Not every response on this socket is ours. A proxy timing out, a
      // gateway error page, or a truncated body all arrive as text that is not
      // JSON, and decoding it used to throw a FormatException carrying that
      // text — which callers then rendered to the player.
      if (ok) rethrow;
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Unknown error',
      );
    }

    if (ok) return body;

    // A non-2xx body is not guaranteed to be a JSON object either.
    final error = body is Map ? body['error'] : null;
    throw ApiException(
      statusCode: response.statusCode,
      message: error?.toString() ?? 'Unknown error',
    );
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
