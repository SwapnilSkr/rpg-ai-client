import '../../../core/network/api_client.dart';
import '../../../shared/models/persona.dart';

class PersonaRepository {
  /// Last successfully fetched list. Personas change rarely, so we serve this
  /// instantly (e.g. when opening Scene Settings) and refresh in the background.
  /// Mutations below invalidate it so edits are never served stale.
  static List<Persona>? _cache;

  static Future<List<Persona>> _fetch() async {
    final response = await ApiClient.get('/personas');
    final rows = ((response['personas'] as List?) ?? [])
        .map((e) => Persona.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    _cache = rows;
    return rows;
  }

  /// Returns the cached list immediately when available (kicking off a silent
  /// background refresh), otherwise fetches. Pass [forceRefresh] to always wait
  /// for the network.
  static Future<List<Persona>> list({bool forceRefresh = false}) async {
    final cached = _cache;
    if (!forceRefresh && cached != null) {
      _fetch().ignore(); // refresh for next time; don't block this call
      return cached;
    }
    return _fetch();
  }

  static Future<Persona> create({
    required String name,
    required String gender,
    int? age,
    String description = '',
    String otherInfo = '',
  }) async {
    final response = await ApiClient.post('/personas', body: {
      'name': name,
      'gender': gender,
      if (age != null) 'age': age,
      if (description.trim().isNotEmpty) 'description': description.trim(),
      if (otherInfo.trim().isNotEmpty) 'other_info': otherInfo.trim(),
    });
    _cache = null;
    return Persona.fromJson(Map<String, dynamic>.from(response['persona']));
  }

  static Future<Persona> update(
    String id, {
    String? name,
    String? gender,
    int? age,
    bool clearAge = false,
    String? description,
    String? otherInfo,
  }) async {
    final response = await ApiClient.patch('/personas/$id', body: {
      if (name != null) 'name': name.trim(),
      if (gender != null) 'gender': gender,
      if (clearAge) 'age': null else if (age != null) 'age': age,
      // Trim to match create(); empty strings are kept (unlike create) so an
      // edit can clear a previously-set description/other_info field.
      if (description != null) 'description': description.trim(),
      if (otherInfo != null) 'other_info': otherInfo.trim(),
    });
    _cache = null;
    return Persona.fromJson(Map<String, dynamic>.from(response['persona']));
  }

  static Future<void> delete(String id) async {
    await ApiClient.delete('/personas/$id');
    _cache = null;
  }
}
