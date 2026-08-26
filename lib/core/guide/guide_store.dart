import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../network/api_client.dart';
import 'guide_progress.dart';

/// Persistence for guide progress.
///
/// The account is the source of truth — it survives reinstalls, follows the
/// player across devices, and is the only place a completion funnel can be
/// measured. Device storage is a write-through cache so the first frame never
/// waits on the network and the guide keeps working offline.
///
/// Reads resolve local-first, then fold in whatever `/auth/me` returned at
/// splash (see `syncFromRemote`). Writes land locally at once and are pushed
/// to the server at arc boundaries — never per beat, which would spend forty
/// round trips teaching one player the app.
///
/// Keychain-backed like [InterestsStore], so an uninstall/reinstall on iOS
/// does not re-tour a returning player.
class GuideStore {
  static const _storage = FlutterSecureStorage();
  static const _progressKey = 'guide_progress';
  static const _optOutKey = 'guide_opt_out';
  static const _pendingKey = 'guide_pending_sync';

  static GuideProgress? _cache;
  static Timer? _debounce;

  /// Current record, local-first. Cached in memory after the first read so
  /// beat transitions never touch the platform channel.
  static Future<GuideProgress> load() async {
    if (_cache != null) return _cache!;
    try {
      final raw = await _storage.read(key: _progressKey);
      final optOut = (await _storage.read(key: _optOutKey)) == 'true';
      if (raw == null || raw.isEmpty) {
        return _cache = GuideProgress(optOut: optOut);
      }
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return _cache = GuideProgress.fromJson(decoded, optOut: optOut);
      }
    } catch (_) {
      // A corrupt blob or an unavailable keychain must not lock a player out of
      // the app. An empty record costs at worst one repeated arc, and the
      // account's copy still reconciles on the next sign-in.
    }
    return _cache = GuideProgress.empty;
  }

  /// In-memory record, or null before the first [load]. Lets the controller
  /// answer synchronously during a build without an await.
  static GuideProgress? get cached => _cache;

  /// Fold the account's record (from `/auth/me`) into the device cache.
  ///
  /// Called at splash and after sign-in. Union semantics, so a second device
  /// inherits everything already seen instead of re-touring.
  static Future<GuideProgress> syncFromRemote(
    Map<String, dynamic>? remoteFlows, {
    bool remoteOptOut = false,
  }) async {
    final local = await load();
    final remote = GuideProgress.fromJson(remoteFlows, optOut: remoteOptOut);
    final merged = local.mergeWith(remote);
    await _writeLocal(merged);
    // Only push back when the device knew something the account did not,
    // so a plain sign-in does not generate a write.
    if (_isAhead(merged, remote)) unawaited(_push(merged));
    return merged;
  }

  /// Record a change: local immediately, server at the next arc boundary.
  static Future<GuideProgress> save(
    GuideProgress progress, {
    bool flush = false,
  }) async {
    await _writeLocal(progress);
    if (flush) {
      _debounce?.cancel();
      unawaited(_push(progress));
    } else {
      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 20), () {
        final current = _cache;
        if (current != null) unawaited(_push(current));
      });
    }
    return progress;
  }

  /// Push anything the debounce still owes — called on app pause and on the
  /// way out of a flow, so progress cannot die with the process.
  static Future<void> flush() async {
    _debounce?.cancel();
    final current = _cache;
    if (current != null) await _push(current);
  }

  /// Wipe the record, on the device and on the account, so every arc runs
  /// again. Reached only from rehearsal mode (`GUIDE_REHEARSAL` in `.env`).
  static Future<GuideProgress> reset() async {
    const fresh = GuideProgress.empty;
    await _writeLocal(fresh);
    // Best-effort: a wipe the server never hears about still takes effect
    // here, and reconciles the next time the account is written.
    unawaited(_push(fresh));
    return fresh;
  }

  /// Drop device state on logout. The account keeps its record, so signing
  /// back in restores it rather than re-touring.
  static Future<void> clear() async {
    _debounce?.cancel();
    _cache = null;
    try {
      await _storage.delete(key: _progressKey);
      await _storage.delete(key: _optOutKey);
      await _storage.delete(key: _pendingKey);
    } catch (_) {}
  }

  static Future<void> _writeLocal(GuideProgress progress) async {
    // The in-memory copy is what the running session reads, so it is set first
    // and unconditionally: a keychain that refuses to write must not also
    // break the arc the player is in the middle of.
    _cache = progress;
    try {
      await _storage.write(
        key: _progressKey,
        value: jsonEncode(progress.toJson()),
      );
      await _storage.write(key: _optOutKey, value: progress.optOut.toString());
    } catch (error) {
      if (kDebugMode) debugPrint('[guide] local write failed: $error');
    }
  }

  /// Fire-and-forget sync. A failure is recorded as pending and retried on the
  /// next successful write, so a flaky network never blocks or repeats a beat.
  static Future<void> _push(GuideProgress progress) async {
    try {
      await ApiClient.put(
        '/auth/preferences',
        body: {
          'guide_progress': progress.toJson(),
          'guide_opt_out': progress.optOut,
        },
      );
      await _storage.delete(key: _pendingKey);
    } catch (error) {
      try {
        await _storage.write(key: _pendingKey, value: 'true');
      } catch (_) {}
      if (kDebugMode) debugPrint('[guide] progress sync deferred: $error');
    }
  }

  /// True when [local] carries an arc the account has not recorded, or has
  /// moved one further along.
  static bool _isAhead(GuideProgress local, GuideProgress remote) {
    if (local.optOut != remote.optOut) return true;
    if (local.flows.length != remote.flows.length) return true;
    for (final entry in local.flows.entries) {
      final other = remote.flows[entry.key];
      if (other == null) return true;
      if (other.status != entry.value.status ||
          other.step != entry.value.step) {
        return true;
      }
    }
    return false;
  }
}
