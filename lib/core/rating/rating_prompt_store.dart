import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'rating_prompt_policy.dart';

/// Secure storage persistence for the rating prompt state.
///
/// Follows the same pattern as `WorldReviewNoticeStore`: injectable storage,
/// every read/write trapped in try/catch, with corrupt or missing values
/// gracefully falling back to [RatingPromptState.zero].
class RatingPromptStore {
  static const String _stateKey = 'rating_prompt_state';

  final FlutterSecureStorage _storage;

  const RatingPromptStore([this._storage = const FlutterSecureStorage()]);

  /// Reads the persisted rating state. Returns [RatingPromptState.zero] on any
  /// missing or corrupted value or read failure.
  Future<RatingPromptState> read() async {
    try {
      final raw = await _storage.read(key: _stateKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return RatingPromptState.fromJson(decoded);
        } else if (decoded is Map) {
          return RatingPromptState.fromJson(Map<String, dynamic>.from(decoded));
        }
      }

      return RatingPromptState.zero;
    } catch (_) {
      // Any storage exception or JSON format error yields the safe zero state.
      return RatingPromptState.zero;
    }
  }

  /// Persists the rating state as a JSON string under the state key.
  Future<void> write(RatingPromptState state) async {
    try {
      await _storage.write(key: _stateKey, value: jsonEncode(state.toJson()));
    } catch (_) {
      // Storage write failures are non-fatal; the flow degrades safely.
    }
  }
}
