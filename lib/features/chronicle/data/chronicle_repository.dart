import '../../../core/network/api_client.dart';
import '../../../shared/models/event.dart';
import '../../../shared/models/memory.dart';
import '../../../shared/models/character_profile.dart';
import 'calendar_data.dart';
import 'location_journal.dart';
import 'relationship_ledger.dart';
import 'threads_data.dart';
import 'recap_data.dart';
import 'side_chat_data.dart';

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
    String? query,
    String? type,
    int? minImportance,
    bool unresolvedOnly = false,
  }) async {
    final params = <String, String>{'include_archived': '$includeArchived'};
    if (query != null && query.trim().isNotEmpty) params['q'] = query.trim();
    if (type != null && type.isNotEmpty) params['type'] = type;
    if (minImportance != null) params['min_importance'] = '$minImportance';
    if (unresolvedOnly) params['unresolved'] = 'true';
    final qs = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    final response = await ApiClient.get('/chronicle/memories/$instanceId?$qs');
    return (response as List).map((e) => Memory.fromJson(e)).toList();
  }

  static Future<void> editMemory(
    String memoryId, {
    required String text,
    String? type,
    int? importance,
  }) async {
    await ApiClient.put(
      '/chronicle/memory/$memoryId',
      body: {
        'text': text,
        if (type != null) 'type': type,
        if (importance != null) 'importance': importance,
      },
    );
  }

  static Future<void> deleteMemory(String memoryId) async {
    await ApiClient.delete('/chronicle/memory/$memoryId');
  }

  /// Edits a turn and returns the server-regenerated chips + scene presence when
  /// the narrative changed (both null when only the player input was edited).
  static Future<({List<Choice> choices, List<String> presentCharacters})?>
  editEvent(String eventId, {String? aiResponse, String? playerInput}) async {
    final response = await ApiClient.put(
      '/chronicle/event/$eventId',
      body: {
        if (aiResponse != null) 'ai_response': aiResponse,
        if (playerInput != null) 'player_input': playerInput,
      },
    );
    if (response['choices'] == null && response['present_characters'] == null) {
      return null;
    }
    return (
      choices: Choice.listFromAny(response['choices']),
      presentCharacters: GameEvent.presentFromAny(response['present_characters']),
    );
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

  /// Almanac payload: calendars, timeline branches, the current story-time
  /// cursor, and all time-anchored events. Backed by GET /chronicle/calendar.
  static Future<CalendarData> getCalendar(String instanceId) async {
    final response = await ApiClient.get('/chronicle/calendar/$instanceId');
    return CalendarData.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// "Story so far" re-entry recap: prose spine + open threads + bonds + place.
  static Future<RecapData> getRecap(String instanceId) async {
    final response = await ApiClient.get('/chronicle/recap/$instanceId');
    return RecapData.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// Open and recently-resolved story threads (promises/conflicts/questions).
  static Future<ThreadsData> getThreads(String instanceId) async {
    final response = await ApiClient.get('/chronicle/threads/$instanceId');
    return ThreadsData.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// Per-character standing toward the player: meters, disposition, and the
  /// narrative moments that shifted each bond.
  static Future<RelationshipLedger> getRelationships(String instanceId) async {
    final response = await ApiClient.get(
      '/chronicle/relationships/$instanceId',
    );
    return RelationshipLedger.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  /// "What this character remembers about you" — the memories a character is
  /// part of, via entity subject/object links.
  static Future<CharacterMemories> getCharacterMemories(
    String instanceId,
    String characterId,
  ) async {
    final response = await ApiClient.get(
      '/chronicle/relationships/$instanceId/$characterId/memories',
    );
    return CharacterMemories.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  /// Private one-on-one side-character thread.
  static Future<SideChatThread> getSideChatThread(
    String instanceId,
    String characterId, {
    int page = 1,
    int limit = 30,
  }) async {
    final response = await ApiClient.get(
      '/chronicle/side-chats/$instanceId/$characterId?page=$page&limit=$limit',
    );
    return SideChatThread.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// All places with anchored events/memories + the current-location cursor.
  static Future<LocationsData> getLocations(String instanceId) async {
    final response = await ApiClient.get('/chronicle/locations/$instanceId');
    return LocationsData.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// "What happened here before?" — one place's events and memories.
  static Future<LocationJournal> getLocationJournal(
    String instanceId,
    String locationEntityId,
  ) async {
    final response = await ApiClient.get(
      '/chronicle/locations/$instanceId/$locationEntityId',
    );
    return LocationJournal.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// Switch the active reality/branch for an instance. Subsequent turns and
  /// retrieval scope to this timeline's ancestry server-side.
  static Future<void> setActiveTimeline(
    String instanceId,
    String timelineId,
  ) async {
    await ApiClient.put(
      '/chronicle/calendar/$instanceId/timeline/active',
      body: {'timeline_id': timelineId},
    );
  }

  /// Rewind a playthrough to [sequence]: removes that turn and everything after,
  /// rolling back state, memories, and summaries on the server.
  static Future<void> rewind(String instanceId, int sequence) async {
    await ApiClient.post(
      '/chronicle/rewind/$instanceId',
      body: {'sequence': sequence},
    );
  }

  /// Edit a character/protagonist card. Removed facts trigger memory
  /// supersession server-side so stale memories can't resurface.
  static Future<CharacterProfile> editCharacter(
    String characterId,
    Map<String, dynamic> updates,
  ) async {
    final response = await ApiClient.put(
      '/chronicle/character/$characterId',
      body: updates,
    );
    return CharacterProfile.fromJson(
      Map<String, dynamic>.from(response['character'] as Map),
    );
  }

  /// GM onboarding: set the player's own character as this instance's locked
  /// protagonist (first play).
  static Future<void> setProtagonist(
    String instanceId, {
    required String name,
    String? identity,
  }) async {
    await ApiClient.post(
      '/instances/$instanceId/protagonist',
      body: {
        'name': name,
        if (identity != null && identity.isNotEmpty) 'identity': identity,
      },
    );
  }

  /// Update in-chat session settings (POV, chat mode, reply length) for an instance.
  static Future<void> updateSettings(
    String instanceId, {
    String? narrationPov,
    String? mode,
    String? messageLength,
    String? focusCharacterId,
    String? personaId,
    bool clearFocusCharacter = false,
    bool clearPersona = false,
  }) async {
    await ApiClient.patch(
      '/instances/$instanceId/settings',
      body: {
        if (narrationPov != null) 'narration_pov': narrationPov,
        if (mode != null) 'mode': mode,
        if (messageLength != null) 'message_length': messageLength,
        if (focusCharacterId != null) 'focus_character_id': focusCharacterId,
        if (clearFocusCharacter) 'focus_character_id': null,
        if (personaId != null) 'persona_id': personaId,
        if (clearPersona) 'persona_id': null,
      },
    );
  }
}
