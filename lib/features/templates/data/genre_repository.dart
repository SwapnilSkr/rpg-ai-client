import '../../../core/auth/auth_service.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/explore_genre.dart';

class GenreRepository {
  static List<ExploreGenre>? _cachedGenres;
  static int _cacheEpoch = AuthService.sessionEpoch.value;

  static void invalidate() {
    _cacheEpoch = AuthService.sessionEpoch.value;
    _cachedGenres = null;
  }

  static void _syncSessionCache() {
    final epoch = AuthService.sessionEpoch.value;
    if (_cacheEpoch == epoch) return;
    _cacheEpoch = epoch;
    _cachedGenres = null;
  }

  static Future<List<ExploreGenre>> list({bool forceRefresh = false}) async {
    _syncSessionCache();
    if (!forceRefresh && _cachedGenres != null) {
      return _cachedGenres!;
    }
    try {
      final response = await ApiClient.get('/templates/genres');
      final list = (response is Map ? response['genres'] : null);
      if (list is List) {
        final genres = list
            .whereType<Map>()
            .map((e) => ExploreGenre.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _cachedGenres = genres;
        return genres;
      }
      _cachedGenres = [];
      return [];
    } catch (_) {
      // On error it returns an empty list, so Explore shows only For You and keeps working.
      return _cachedGenres ?? [];
    }
  }
}
