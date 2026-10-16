import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config/env.dart';
import '../../../core/storage/secure_storage.dart';
import '../models/media_usage.dart';

class MediaUnvoiceableException implements Exception {
  final String message;
  const MediaUnvoiceableException([this.message = 'Unvoiceable']);
  @override
  String toString() => 'MediaUnvoiceableException: $message';
}

class MediaRestingException implements Exception {
  final String kind; // 'voice' | 'picture' | 'video' | 'portrait'
  final String resetsAt;
  const MediaRestingException({required this.kind, this.resetsAt = ''});

  String get restingCopy => switch (kind) {
    'voice' => 'Their voices rest until tomorrow.',
    'picture' => 'The painter rests until tomorrow.',
    'video' => 'The visions rest until tomorrow.',
    _ => 'The requested media waits until tomorrow.',
  };

  @override
  String toString() => 'MediaRestingException($kind, resetsAt: $resetsAt)';
}

class MediaException implements Exception {
  final String message;
  final int statusCode;
  const MediaException(this.message, {this.statusCode = 500});
  @override
  String toString() => 'MediaException($statusCode): $message';
}

class VoiceResponse {
  final String status; // 'ready' | 'queued'
  final String? url;
  final int? durationMs;
  final String? mediaId;

  const VoiceResponse({
    required this.status,
    this.url,
    this.durationMs,
    this.mediaId,
  });

  bool get isReady => status == 'ready' && url != null && url!.isNotEmpty;
  bool get isQueued => status == 'queued';
}

class MediaRequestResponse {
  final String status; // 'ready' | 'queued'
  final String? url;
  final String? mediaId;

  const MediaRequestResponse({
    required this.status,
    this.url,
    this.mediaId,
  });

  bool get isReady => status == 'ready' && url != null && url!.isNotEmpty;
  bool get isQueued => status == 'queued';
}

class MediaRepository {
  static final MediaRepository instance = MediaRepository();

  final http.Client _client;
  final String? _baseUrl;
  final Future<String?> Function()? _tokenProvider;

  /// Cached usage result for the session (null if not checked or 404).
  static MediaUsage? _cachedUsage;
  static bool _hasUsageCheckedThisSession = false;

  MediaRepository({
    http.Client? client,
    String? baseUrl,
    Future<String?> Function()? tokenProvider,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl,
        _tokenProvider = tokenProvider;

  String get baseUrl => _baseUrl ?? AppConfig.apiBaseUrl;

  static bool get isMediaEnabledSession =>
      _hasUsageCheckedThisSession && _cachedUsage != null;

  static MediaUsage? get currentUsage => _cachedUsage;

  static void resetSession() {
    _cachedUsage = null;
    _hasUsageCheckedThisSession = false;
  }

  Future<Map<String, String>> _headers() async {
    final token = _tokenProvider != null
        ? await _tokenProvider()
        : await SecureStore.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Check media usage quota from the server.
  /// Returns [MediaUsage] on 200, or null on 404 (feature off on wire).
  Future<MediaUsage?> getUsage() async {
    final uri = Uri.parse('$baseUrl/media/usage');
    final response = await _client.get(uri, headers: await _headers());

    _hasUsageCheckedThisSession = true;
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      _cachedUsage = MediaUsage.fromJson(json);
      return _cachedUsage;
    } else if (response.statusCode == 404) {
      _cachedUsage = null;
      return null;
    } else {
      _cachedUsage = null;
      return null;
    }
  }

  /// Request speech synthesis for a spoken line.
  /// POST /instances/:instanceId/events/:eventId/lines/:lineId/voice
  Future<VoiceResponse> requestVoice({
    required String instanceId,
    required String eventId,
    required String lineId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/instances/$instanceId/events/$eventId/lines/$lineId/voice',
    );
    final response = await _client.post(uri, headers: await _headers());

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return VoiceResponse(
        status: 'ready',
        url: json['url']?.toString(),
        durationMs: (json['duration_ms'] as num?)?.toInt(),
      );
    } else if (response.statusCode == 202) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return VoiceResponse(
        status: 'queued',
        mediaId: json['media_id']?.toString(),
      );
    } else if (response.statusCode == 422) {
      throw const MediaUnvoiceableException();
    } else if (response.statusCode == 429) {
      final json = _tryParseJson(response.body);
      throw MediaRestingException(
        kind: 'voice',
        resetsAt: json?['resets_at']?.toString() ?? '',
      );
    } else {
      throw MediaException(
        'Failed to voice line: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Request scene picture generation for an event.
  /// POST /instances/:instanceId/events/:eventId/picture
  Future<MediaRequestResponse> requestPicture({
    required String instanceId,
    required String eventId,
  }) async {
    final uri = Uri.parse('$baseUrl/instances/$instanceId/events/$eventId/picture');
    final response = await _client.post(uri, headers: await _headers());

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return MediaRequestResponse(
        status: 'ready',
        url: json['url']?.toString(),
        mediaId: json['media_id']?.toString(),
      );
    } else if (response.statusCode == 202) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return MediaRequestResponse(
        status: 'queued',
        mediaId: json['media_id']?.toString(),
      );
    } else if (response.statusCode == 429) {
      final json = _tryParseJson(response.body);
      throw MediaRestingException(
        kind: 'picture',
        resetsAt: json?['resets_at']?.toString() ?? '',
      );
    } else {
      throw MediaException(
        'Failed to request picture: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Request character talking video for a line.
  /// POST /instances/:instanceId/events/:eventId/lines/:lineId/video
  Future<MediaRequestResponse> requestVideo({
    required String instanceId,
    required String eventId,
    required String lineId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/instances/$instanceId/events/$eventId/lines/$lineId/video',
    );
    final response = await _client.post(uri, headers: await _headers());

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return MediaRequestResponse(
        status: 'ready',
        url: json['url']?.toString(),
        mediaId: json['media_id']?.toString(),
      );
    } else if (response.statusCode == 202) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return MediaRequestResponse(
        status: 'queued',
        mediaId: json['media_id']?.toString(),
      );
    } else if (response.statusCode == 429) {
      final json = _tryParseJson(response.body);
      throw MediaRestingException(
        kind: 'video',
        resetsAt: json?['resets_at']?.toString() ?? '',
      );
    } else {
      throw MediaException(
        'Failed to request video: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Request dialogue-free cut video for an event ("Film this").
  /// POST /instances/:instanceId/events/:eventId/video
  Future<MediaRequestResponse> requestTurnVideo({
    required String instanceId,
    required String eventId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/instances/$instanceId/events/$eventId/video',
    );
    final response = await _client.post(uri, headers: await _headers());

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return MediaRequestResponse(
        status: 'ready',
        url: json['url']?.toString(),
        mediaId: json['media_id']?.toString(),
      );
    } else if (response.statusCode == 202) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return MediaRequestResponse(
        status: 'queued',
        mediaId: json['media_id']?.toString(),
      );
    } else if (response.statusCode == 429) {
      final json = _tryParseJson(response.body);
      throw MediaRestingException(
        kind: 'video',
        resetsAt: json?['resets_at']?.toString() ?? '',
      );
    } else {
      throw MediaException(
        'Failed to request turn video: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Repaint a character's portrait.
  /// POST /instances/:instanceId/characters/:characterId/portrait
  Future<MediaRequestResponse> repaintCharacterPortrait({
    required String instanceId,
    required String characterId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/instances/$instanceId/characters/$characterId/portrait',
    );
    final response = await _client.post(uri, headers: await _headers());

    if (response.statusCode == 200 || response.statusCode == 202) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return MediaRequestResponse(
        status: response.statusCode == 200 ? 'ready' : 'queued',
        url: json['url']?.toString(),
        mediaId: json['media_id']?.toString(),
      );
    } else if (response.statusCode == 429) {
      final json = _tryParseJson(response.body);
      throw MediaRestingException(
        kind: 'picture',
        resetsAt: json?['resets_at']?.toString() ?? '',
      );
    } else {
      throw MediaException(
        'Failed to repaint portrait: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Paint a persona's portrait ("Give yourself a face").
  /// POST /personas/:personaId/portrait
  Future<MediaRequestResponse> paintPersonaPortrait({
    required String personaId,
  }) async {
    final uri = Uri.parse('$baseUrl/personas/$personaId/portrait');
    final response = await _client.post(uri, headers: await _headers());

    if (response.statusCode == 200 || response.statusCode == 202) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return MediaRequestResponse(
        status: response.statusCode == 200 ? 'ready' : 'queued',
        url: json['url']?.toString(),
        mediaId: json['media_id']?.toString(),
      );
    } else if (response.statusCode == 429) {
      final json = _tryParseJson(response.body);
      throw MediaRestingException(
        kind: 'portrait',
        resetsAt: json?['resets_at']?.toString() ?? '',
      );
    } else {
      throw MediaException(
        'Failed to paint persona portrait: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  Map<String, dynamic>? _tryParseJson(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }
}
