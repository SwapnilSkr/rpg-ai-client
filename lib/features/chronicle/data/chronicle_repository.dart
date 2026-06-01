import '../../../core/network/api_client.dart';
import '../../../shared/models/event.dart';
import '../../../shared/models/memory.dart';
import '../../../shared/models/character_profile.dart';

class ChronicleRepository {
  static Future<Map<String, dynamic>> getEvents(
    String instanceId, {
    int page = 1,
    int limit = 50,
    String? type,
  }) async {
    String path = '/chronicle/events/$instanceId?page=$page&limit=$limit';
    if (type != null) path += '&type=$type';
    final response = await ApiClient.get(path);
    final events = (response['events'] as List)
        .map((e) => GameEvent.fromJson(e))
        .toList();
    return {
      'events': events,
      'total': response['total'],
      'page': response['page'],
    };
  }

  static Future<List<Memory>> getMemories(
    String instanceId, {
    bool includeArchived = false,
  }) async {
    final response = await ApiClient.get(
      '/chronicle/memories/$instanceId?include_archived=$includeArchived',
    );
    return (response as List).map((e) => Memory.fromJson(e)).toList();
  }

  static Future<void> editMemory(
    String memoryId, {
    required String text,
    String? type,
    int? importance,
  }) async {
    await ApiClient.put('/chronicle/memory/$memoryId', body: {
      'text': text,
      if (type != null) 'type': type,
      if (importance != null) 'importance': importance,
    });
  }

  static Future<void> deleteMemory(String memoryId) async {
    await ApiClient.delete('/chronicle/memory/$memoryId');
  }

  static Future<void> editEvent(
    String eventId, {
    String? aiResponse,
    String? playerInput,
  }) async {
    await ApiClient.put('/chronicle/event/$eventId', body: {
      if (aiResponse != null) 'ai_response': aiResponse,
      if (playerInput != null) 'player_input': playerInput,
    });
  }

  static Future<GameEvent> replayEvent(String eventId) async {
    final response = await ApiClient.post('/chronicle/replay/$eventId');
    return GameEvent.fromJson(Map<String, dynamic>.from(response['event']));
  }

  static Future<GameEvent> selectReplayVariant(
    String eventId,
    int variantIndex,
  ) async {
    final response = await ApiClient.post(
      '/chronicle/replay/select/$eventId',
      body: {'variant_index': variantIndex},
    );
    return GameEvent.fromJson(Map<String, dynamic>.from(response['event']));
  }

  /// Rewind a playthrough to [sequence]: removes that turn and everything after,
  /// rolling back state, memories, and summaries on the server.
  static Future<void> rewind(String instanceId, int sequence) async {
    await ApiClient.post('/chronicle/rewind/$instanceId', body: {
      'sequence': sequence,
    });
  }

  /// Edit a character/protagonist card. Removed facts trigger memory
  /// supersession server-side so stale memories can't resurface.
  static Future<CharacterProfile> editCharacter(
    String characterId,
    Map<String, dynamic> updates,
  ) async {
    final response =
        await ApiClient.put('/chronicle/character/$characterId', body: updates);
    return CharacterProfile.fromJson(
        Map<String, dynamic>.from(response['character'] as Map));
  }

  /// GM onboarding: set the player's own character as this instance's locked
  /// protagonist (first play).
  static Future<void> setProtagonist(
    String instanceId, {
    required String name,
    String? identity,
  }) async {
    await ApiClient.post('/instances/$instanceId/protagonist', body: {
      'name': name,
      if (identity != null && identity.isNotEmpty) 'identity': identity,
    });
  }

  /// Update in-chat session settings (narration POV, tone) for an instance.
  static Future<void> updateSettings(
    String instanceId, {
    String? narrationPov,
    String? mode,
    String? messageLength,
    String? focusCharacterId,
    bool clearFocusCharacter = false,
  }) async {
    await ApiClient.patch('/instances/$instanceId/settings', body: {
      if (narrationPov != null) 'narration_pov': narrationPov,
      if (mode != null) 'mode': mode,
      if (messageLength != null) 'message_length': messageLength,
      if (focusCharacterId != null) 'focus_character_id': focusCharacterId,
      if (clearFocusCharacter) 'focus_character_id': null,
    });
  }
}
