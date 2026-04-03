import '../../../core/network/api_client.dart';
import '../../../shared/models/event.dart';
import '../../../shared/models/memory.dart';

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
}
