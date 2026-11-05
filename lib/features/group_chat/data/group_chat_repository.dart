import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../chronicle/data/chronicle_repository.dart';
import '../models/group_chat_models.dart';

/// The HTTP side of a group chat: thread list, bonds, actions, and opening a
/// thread that has a message waiting.
abstract class GroupChatRepository {
  /// The Chats tab: this player's group saves, newest activity first. A row
  /// that does not parse is dropped.
  Future<List<GroupChatRow>> chats();

  Future<List<GroupThreadSummary>> threads(String instanceId);

  /// Whether the server started writing the waiting message. The words
  /// arrive over the socket, never in this response.
  Future<bool> openThread(String instanceId, String characterId);

  Future<List<GroupBond>> bonds(String instanceId);

  /// Sets any of the four meters (whole numbers 0 to 100). Returns the
  /// server's meters for that character.
  Future<BondMeters> setBond(
    String instanceId,
    String characterId,
    Map<String, int> meters,
  );

  Future<GroupActionsPage> actions(
    String instanceId, {
    int? before,
    int limit = 30,
  });

  /// Removes the turn at [sequence] and everything after it, in the room and
  /// in every direct thread. The server refuses the opening (1).
  Future<void> rewind(String instanceId, int sequence);

  /// Asks a character for a picture of themselves on one saved line. The
  /// answer is a ready picture, one that was queued, or the daily allowance
  /// resting (a 429 that carries when it comes back) as a `resting` selfie.
  /// Anything else is thrown.
  Future<GroupSelfie> requestSelfie(
    String instanceId,
    String eventId,
    String characterId,
    String text,
  );
}

class HttpGroupChatRepository implements GroupChatRepository {
  /// The overrides are for tests; the app uses the defaults.
  const HttpGroupChatRepository({this.client, this.baseUrl, this.tokenProvider});

  final http.Client? client;
  final String? baseUrl;
  final Future<String?> Function()? tokenProvider;

  @override
  Future<List<GroupChatRow>> chats() async {
    final body = await ApiClient.get('/instances/group-chats');
    final rows = body is Map ? body['chats'] : null;
    return [
      if (rows is List)
        for (final row in rows) ?GroupChatRow.parse(row),
    ];
  }

  @override
  Future<List<GroupThreadSummary>> threads(String instanceId) async {
    final body = await ApiClient.get('/instances/$instanceId/threads');
    return [
      if (body is List)
        for (final row in body) ?GroupThreadSummary.parse(row),
    ];
  }

  @override
  Future<bool> openThread(String instanceId, String characterId) async {
    final body = await ApiClient.post(
      '/instances/$instanceId/group/threads/$characterId/open',
    );
    return body is Map && body['writing'] == true;
  }

  @override
  Future<List<GroupBond>> bonds(String instanceId) async {
    final body = await ApiClient.get('/instances/$instanceId/bonds');
    return [
      if (body is List)
        for (final row in body) ?GroupBond.parse(row),
    ];
  }

  @override
  Future<BondMeters> setBond(
    String instanceId,
    String characterId,
    Map<String, int> meters,
  ) async {
    final body = await ApiClient.put(
      '/instances/$instanceId/bonds/$characterId',
      body: meters,
    );
    return BondMeters.fromJson(body);
  }

  @override
  Future<GroupActionsPage> actions(
    String instanceId, {
    int? before,
    int limit = 30,
  }) async {
    final query = 'limit=$limit${before == null ? '' : '&before=$before'}';
    final body = await ApiClient.get('/instances/$instanceId/actions?$query');
    return GroupActionsPage.parse(body);
  }

  @override
  Future<void> rewind(String instanceId, int sequence) =>
      ChronicleRepository.rewind(instanceId, sequence);

  // Not through ApiClient: it drops a failed response's body, and the resting
  // answer is the one failure whose body the screen needs (when to come back).
  @override
  Future<GroupSelfie> requestSelfie(
    String instanceId,
    String eventId,
    String characterId,
    String text,
  ) async {
    final token = tokenProvider != null
        ? await tokenProvider!()
        : await SecureStore.getToken();
    final http.Client sender = client ?? http.Client();
    final http.Response response;
    try {
      response = await sender.post(
        Uri.parse(
          '${baseUrl ?? AppConfig.apiBaseUrl}/instances/$instanceId/events/$eventId/selfie',
        ),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'character_id': characterId, 'text': text}),
      );
    } finally {
      // Ours only when none was handed in.
      if (client == null) sender.close();
    }
    Object? body;
    try {
      body = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      body = null;
    }
    final answer = GroupSelfie.parse(body);
    if (response.statusCode == 429 &&
        answer != null &&
        answer.status == SelfieStatus.resting) {
      return answer;
    }
    final ok = response.statusCode == 200 || response.statusCode == 202;
    if (ok && answer != null) return answer;
    throw ApiException(
      statusCode: response.statusCode,
      message: body is Map ? '${body['error'] ?? 'Unknown error'}' : 'Unknown error',
    );
  }
}
