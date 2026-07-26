import '../../../core/auth/auth_service.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/persona.dart';

class PersonaPage {
  final List<Persona> personas;
  final int total;
  final int page;

  const PersonaPage({
    required this.personas,
    required this.total,
    required this.page,
  });

  bool get hasMore =>
      personas.isNotEmpty && personas.length + (page - 1) * 20 < total;
}

class PersonaRepository {
  /// Last successfully fetched list. Personas change rarely, so we serve this
  /// instantly (e.g. when opening Scene Settings) and refresh in the background.
  /// Mutations below invalidate it so edits are never served stale.
  static List<Persona>? _cache;
  static int _cacheEpoch = AuthService.sessionEpoch.value;

  static void _syncSessionCache() {
    final epoch = AuthService.sessionEpoch.value;
    if (_cacheEpoch == epoch) return;
    _cacheEpoch = epoch;
    _cache = null;
  }

  static Future<List<Persona>> _fetch() async {
    _syncSessionCache();
    final response = await ApiClient.get('/personas?limit=50');
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
    _syncSessionCache();
    final cached = _cache;
    if (!forceRefresh && cached != null) {
      _fetch().ignore(); // refresh for next time; don't block this call
      return cached;
    }
    return _fetch();
  }

  /// Page the vault rather than loading an unbounded identity list. Search is
  /// performed on the server, so it finds personas that have not been loaded yet.
  static Future<PersonaPage> listPage({
    int page = 1,
    int limit = 20,
    String search = '',
  }) async {
    _syncSessionCache();
    final query = <String>['page=$page', 'limit=$limit'];
    if (search.trim().isNotEmpty) {
      query.add('search=${Uri.encodeQueryComponent(search.trim())}');
    }
    final response = await ApiClient.get('/personas?${query.join('&')}');
    final rows = ((response['personas'] as List?) ?? [])
        .map((e) => Persona.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return PersonaPage(
      personas: rows,
      total: (response['total'] as num?)?.toInt() ?? rows.length,
      page: (response['page'] as num?)?.toInt() ?? page,
    );
  }

  static Future<Persona> create({
    required String name,
    required String gender,
    int? age,
    String description = '',
    String otherInfo = '',
  }) async {
    final response = await ApiClient.post(
      '/personas',
      body: {
        'name': name,
        'gender': gender,
        if (age != null) 'age': age,
        if (description.trim().isNotEmpty) 'description': description.trim(),
        if (otherInfo.trim().isNotEmpty) 'other_info': otherInfo.trim(),
      },
    );
    _cacheEpoch = AuthService.sessionEpoch.value;
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
    final response = await ApiClient.patch(
      '/personas/$id',
      body: {
        if (name != null) 'name': name.trim(),
        if (gender != null) 'gender': gender,
        if (clearAge) 'age': null else if (age != null) 'age': age,
        // Trim to match create(); empty strings are kept (unlike create) so an
        // edit can clear a previously-set description/other_info field.
        if (description != null) 'description': description.trim(),
        if (otherInfo != null) 'other_info': otherInfo.trim(),
      },
    );
    _cacheEpoch = AuthService.sessionEpoch.value;
    _cache = null;
    return Persona.fromJson(Map<String, dynamic>.from(response['persona']));
  }

  static Future<void> delete(String id) async {
    await ApiClient.delete('/personas/$id');
    _cacheEpoch = AuthService.sessionEpoch.value;
    _cache = null;
  }
}
