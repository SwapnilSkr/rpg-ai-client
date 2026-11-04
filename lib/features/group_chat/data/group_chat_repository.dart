import '../../../core/network/api_client.dart';
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
}

class HttpGroupChatRepository implements GroupChatRepository {
  const HttpGroupChatRepository();

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
}
