/// First-party product analytics and error reports.
///
/// Contract: `everlore-docs/phases/analytics.md`. The app records screens, key
/// actions and errors into a durable queue and sends them to
/// `POST /app/telemetry` in batches. It never records what a player typed or
/// read, and when the player turns sharing off it sends nothing more and
/// deletes whatever was waiting.
///
/// Nothing here may ever throw into the app: every public method swallows its
/// own failures.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../storage/secure_storage.dart';
import 'breadcrumbs.dart';
import 'clocks.dart';
import 'environment.dart';
import 'error_journal.dart';
import 'error_limiter.dart';
import 'queue.dart';
import 'scrubber.dart';
import 'sender.dart';
import 'stack_frames.dart';
import 'telemetry_vocabulary.dart';

class Telemetry with WidgetsBindingObserver {
  Telemetry({
    TelemetryStore? store,
    TelemetryTransport? transport,
    DateTime Function()? now,
    Future<String?> Function()? tokenProvider,
    EnvironmentLoader? environment,
    String Function()? newId,
    Future<String?> Function()? journalPath,
    bool observeLifecycle = true,
    bool startTimers = true,
    bool installHandlers = true,
  }) : _store = store ?? SqfliteTelemetryStore(),
       _transport = transport ?? HttpTelemetryTransport(),
       _now = now ?? DateTime.now,
       _token = tokenProvider ?? SecureStore.getToken,
       _environment = environment ?? loadEnvironment,
       _newId = newId ?? (() => const Uuid().v4()),
       _journalPath = journalPath ?? _defaultJournalPath,
       _observeLifecycle = observeLifecycle,
       _startTimers = startTimers,
       _installHandlers = installHandlers;

  static Telemetry instance = Telemetry();

  /// Tests point the app-wide handle at a rig with a fake transport, so the
  /// call sites in cubits and screens can be asserted on without a network.
  @visibleForTesting
  static void replaceInstance(Telemetry telemetry) => instance = telemetry;

  static const String _enabledKey = 'enabled';
  static const String _installKey = 'install_id';
  static const String _seqKey = 'next_seq';
  static const String _firstOpenKey = 'first_open_sent';
  static const Duration _flushEvery = Duration(seconds: 30);
  static const int _flushAt = 50;

  final TelemetryStore _store;
  final TelemetryTransport _transport;
  final DateTime Function() _now;
  final Future<String?> Function() _token;
  final EnvironmentLoader _environment;
  final String Function() _newId;
  final Future<String?> Function() _journalPath;
  final bool _observeLifecycle;
  final bool _startTimers;
  final bool _installHandlers;

  late final TelemetryQueue _queue = TelemetryQueue(_store);
  final BreadcrumbRing _crumbs = BreadcrumbRing();
  final ErrorLimiter _limiter = ErrorLimiter();
  final FlushBackoff _backoff = FlushBackoff();
  final ScreenClock _screens = ScreenClock();
  late final SessionClock _sessions = SessionClock(newId: _newId);

  ErrorJournal? _journal;
  TelemetryEnvironment? _env;
  String _installId = '';
  int _seq = 0;
  int _queued = 0;
  int _journalInFlight = 0;
  bool _ready = false;
  bool _enabled = true;
  bool _foreground = true;
  bool _flushing = false;
  Completer<void> _flushDone = Completer<void>()..complete();
  bool _finalFlush = false;
  Timer? _timer;
  Future<void> _writes = Future<void>.value();

  /// Whether sharing is on. Default on; the profile switch flips it.
  bool get enabled => _enabled;

  static Future<String?> _defaultJournalPath() async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}/telemetry_errors.jsonl';
  }

  /// Opens the queue, reads the stored preference, and only then installs the
  /// error handlers, so an opted-out player's first error is already ignored.
  Future<void> init() async {
    if (_ready) return;
    try {
      _env = await _environment();
      _enabled = await _store.getMeta(_enabledKey) != '0';

      var install = await _store.getMeta(_installKey);
      if (install == null) {
        install = _newId();
        await _store.setMeta(_installKey, install);
      }
      _installId = install;
      _seq = int.tryParse(await _store.getMeta(_seqKey) ?? '') ?? 0;

      final path = await _journalPath();
      if (path != null) _journal = ErrorJournal(path);
      await _importJournal();
      _queued = await _store.count();
      _ready = true;

      if (_installHandlers) _installErrorHandlers();
      if (_observeLifecycle) WidgetsBinding.instance.addObserver(this);

      if (_enabled) {
        if (await _store.getMeta(_firstOpenKey) != '1') {
          track('first_open');
          await _store.setMeta(_firstOpenKey, '1');
        }
        track('session_start', {'launch': 'cold'});
        _startTimer();
        unawaited(flush());
      }
    } catch (error) {
      if (kDebugMode) debugPrint('[telemetry] init failed: $error');
    }
  }

  // ── events ─────────────────────────────────────────────────────────────

  /// Records one event from the closed vocabulary. An invalid call asserts in
  /// debug and is dropped in release.
  void track(String name, [Map<String, Object?> props = const {}]) {
    final problem = validateEvent(name, props);
    assert(problem == null, 'Telemetry: $problem');
    if (problem != null) return;
    _emit(name, props);
  }

  void _emit(String name, Map<String, Object?> props, {bool force = false}) {
    if (!_ready || (!_enabled && !force)) return;
    try {
      final at = _now().toUtc();
      final seq = _seq++;
      final body = jsonEncode({
        'id': _newId(),
        'seq': seq,
        'at': at.toIso8601String(),
        'name': name,
        if (props.isNotEmpty) 'props': props,
      });
      if (name != 'screen_view') _crumb('action', name);
      _write(_item('event', body, at), nextSeq: _seq);
    } catch (_) {}
  }

  /// `sheet_opened`. One line at each place a sheet is shown.
  void sheet(String name) => track('sheet_opened', {'sheet': name});

  /// The player moved to [name] (a route name). Emits the previous screen's
  /// `screen_view`.
  void screen(String name) {
    if (!_ready) return;
    try {
      final label = isScreenName(name) ? name : 'unnamed';
      final left = _screens.enter(label, _now());
      if (!_enabled) return;
      if (left != null) track('screen_view', left.toProps());
      _crumb('screen', label);
    } catch (_) {}
  }

  // ── errors ─────────────────────────────────────────────────────────────

  void recordFlutterError(FlutterErrorDetails details) => _recordError(
    details.exception,
    details.stack,
    source: 'flutter',
    uncaught: true,
  );

  /// Always true: the caller returns it from `PlatformDispatcher.onError`, so
  /// a release build keeps running on what Flutter itself would have survived.
  bool recordPlatformError(Object error, StackTrace stack) {
    _recordError(error, stack, source: 'platform', uncaught: true);
    return true;
  }

  /// An error the app caught and showed the player as a message. [httpRoute]
  /// is a template (see [routeTemplate]); [httpStatus] the response status.
  /// [message] replaces the error's own text when that text is not ours to
  /// send (a server reply written for the player).
  void recordHandled(
    Object error, {
    StackTrace? stack,
    int? httpStatus,
    String? httpRoute,
    String? message,
  }) {
    if (httpStatus != null) {
      _crumb('http', 'http_$httpStatus');
    }
    _recordError(
      error,
      stack,
      source: 'handled',
      uncaught: false,
      httpStatus: httpStatus,
      httpRoute: httpRoute,
      message: message,
    );
  }

  void _recordError(
    Object error,
    StackTrace? stack, {
    required String source,
    required bool uncaught,
    int? httpStatus,
    String? httpRoute,
    String? message,
  }) {
    if (!_ready || !_enabled) return;
    try {
      // A handled error is captured inside the helper that turns it into
      // player text; those frames say nothing, the caller's do.
      final frames = parseFrames(stack)
          .skipWhile(
            (f) =>
                f.file.contains('/core/telemetry/') ||
                f.file.endsWith('/core/errors/user_message.dart'),
          )
          .toList();
      final type = errorTypeLabel(error);
      final top = frames.isEmpty ? '' : '${frames.first.file}:${frames.first.symbol}';
      final now = _now();
      if (!_limiter.allow('$source|$type|$top|$httpStatus', now)) return;

      final at = now.toUtc();
      final screen = _screens.current;
      final body = jsonEncode({
        'id': _newId(),
        'at': at.toIso8601String(),
        'source': source,
        'fatal': false,
        'type': type,
        // A handled error's own text can quote what the player typed (a
        // FormatException prints the offending input), and the scrubber only
        // knows quoted and numeric shapes. Its type says what went wrong.
        'message': scrubMessage(
          message ?? (source == 'handled' ? type : error.toString()),
        ),
        'frames': [for (final f in frames) f.toJson()],
        if (screen != null) 'screen': screen,
        if (httpStatus != null)
          'http': {
            'status': httpStatus,
            if (httpRoute != null) 'route': httpRoute,
          },
        'breadcrumbs': [for (final c in _crumbs.snapshot()) c.toJson()],
      });
      final item = _item('error', body, at);

      if (uncaught && _journal != null) {
        // Synchronous, before the async queue write: a crash that takes the
        // process down next still leaves the report on disk.
        _journalInFlight++;
        _journal!.append(_toJournalLine(item));
        _write(
          item,
          onWritten: () {
            if (--_journalInFlight == 0) _journal?.clear();
          },
        );
        unawaited(flush());
      } else {
        _write(item);
      }
    } catch (_) {}
  }

  // ── queue ──────────────────────────────────────────────────────────────

  QueueItem _item(String kind, String body, DateTime at) {
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    return QueueItem(
      kind: kind,
      itemId: decoded['id'] as String,
      sessionId: _sessions.id,
      appVersion: _env!.appVersion,
      appBuild: _env!.appBuild,
      atMs: at.millisecondsSinceEpoch,
      body: body,
    );
  }

  /// Serialised so rows land in the order they were recorded.
  void _write(QueueItem item, {int? nextSeq, VoidCallback? onWritten}) {
    _queued++;
    _writes = _writes.then((_) async {
      try {
        await _queue.add(item, nextSeq: nextSeq);
        onWritten?.call();
      } catch (_) {}
    });
    if (_queued >= _flushAt) unawaited(flush());
  }

  Map<String, Object?> _toJournalLine(QueueItem i) => {
    'kind': i.kind,
    'item_id': i.itemId,
    'session_id': i.sessionId,
    'app_version': i.appVersion,
    'app_build': i.appBuild,
    'at_ms': i.atMs,
    'body': i.body,
  };

  /// Errors written before the last process died are queued now. Ids make a
  /// line that did reach the queue a harmless duplicate.
  Future<void> _importJournal() async {
    final journal = _journal;
    if (journal == null) return;
    for (final line in journal.read()) {
      try {
        await _queue.add(
          QueueItem(
            kind: line['kind'] as String,
            itemId: line['item_id'] as String,
            sessionId: line['session_id'] as String,
            appVersion: line['app_version'] as String,
            appBuild: line['app_build'] as int,
            atMs: line['at_ms'] as int,
            body: line['body'] as String,
          ),
        );
      } catch (_) {}
    }
    journal.clear();
  }

  void _crumb(String kind, String name) =>
      _crumbs.add(Breadcrumb(at: _now(), kind: kind, name: name));

  // ── sending ────────────────────────────────────────────────────────────

  void _startTimer() {
    if (!_startTimers) return;
    _timer?.cancel();
    _timer = Timer.periodic(_flushEvery, (_) => unawaited(flush()));
  }

  /// Sends what is queued, in as many requests as the limits need. Failures
  /// keep the items and back off; never throws.
  Future<void> flush({bool ignoreBackoff = false}) async {
    if (!_ready || (!_enabled && !_finalFlush)) return;
    // A flush already running is waited for, not skipped: the caller (the
    // opt-out's last send, a test) wants the queue sent when this returns.
    while (_flushing) {
      await _flushDone.future;
      if (!_enabled && !_finalFlush) return;
    }
    _flushing = true;
    _flushDone = Completer<void>();
    try {
      // What was just recorded is still on its way into the queue.
      await _writes;
      for (var round = 0; round < 20; round++) {
        if (!ignoreBackoff && _backoff.blocked(_now())) break;
        final queued = await _store.peek(250);
        if (queued.isEmpty) {
          _queued = 0;
          break;
        }
        var token = await _token();
        final env = _env!;
        final envelope = Envelope(
          installId: _installId,
          appVersion: env.appVersion,
          appBuild: env.appBuild,
          device: env.device,
        );
        var sent = buildBatch(
          queued,
          envelope: envelope,
          authed: token != null,
          now: _now(),
        );
        if (sent.items.isEmpty) {
          // Only unsendable rows (too old, too large): clear them and look again.
          await _store.deleteRows(sent.rows);
          if (sent.discard.isEmpty) break;
          continue;
        }

        var result = await _transport.post(sent.body, token: token);
        if (result.status == 401 && token != null) {
          // The token is optional on this endpoint; an expired one must not
          // keep the queue from draining. Resend as an anonymous batch, which
          // has the tighter event cap, so it is a different set of rows.
          token = null;
          final anonymous = buildBatch(
            queued,
            envelope: envelope,
            authed: false,
            now: _now(),
          );
          if (anonymous.items.isNotEmpty) {
            sent = anonymous;
            result = await _transport.post(sent.body);
          }
        }

        final status = result.status;
        if (status == 202 || status == 400 || status == 413) {
          // 400/413 will never succeed on a retry: drop the batch.
          await _store.deleteRows(sent.rows);
          _backoff.succeeded();
          continue;
        }
        if (status == 429) {
          _backoff.retryAfter(
            result.retryAfter ?? const Duration(minutes: 1),
            _now(),
          );
        } else {
          _backoff.failed(_now());
        }
        break;
      }
      _queued = await _store.count();
    } catch (_) {
      _backoff.failed(_now());
    } finally {
      _flushing = false;
      _flushDone.complete();
    }
  }

  // ── opt-out ────────────────────────────────────────────────────────────

  /// Turns sharing on or off. Off sends one last `analytics_opted_out`, then
  /// deletes the queue and records nothing more, errors included.
  Future<void> setEnabled(bool value) async {
    if (!_ready || value == _enabled) return;
    try {
      if (value) {
        _enabled = true;
        await _store.setMeta(_enabledKey, '1');
        if (_foreground) _startTimer();
        return;
      }
      await _store.setMeta(_enabledKey, '0');
      _emit('analytics_opted_out', const {}, force: true);
      _enabled = false;
      _timer?.cancel();
      await _writes;
      _finalFlush = true;
      try {
        await flush(ignoreBackoff: true);
      } finally {
        _finalFlush = false;
      }
      await _writes;
      await _store.clear();
      _journal?.clear();
      _journalInFlight = 0;
      _queued = 0;
      _crumbs.clear();
    } catch (_) {}
  }

  // ── lifecycle ──────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _onPaused();
    } else if (state == AppLifecycleState.resumed) {
      _onResumed();
    }
  }

  void _onPaused() {
    if (!_ready || !_foreground) return;
    try {
      _foreground = false;
      final now = _now();
      final partial = _screens.pause(now);
      if (_enabled) {
        if (partial != null) track('screen_view', partial.toProps());
        _crumb('lifecycle', 'paused');
      }
      _sessions.paused(now);
      _timer?.cancel();
      if (_enabled) unawaited(flush());
    } catch (_) {}
  }

  void _onResumed() {
    if (!_ready || _foreground) return;
    try {
      _foreground = true;
      final now = _now();
      final fresh = _sessions.resumed(now);
      _screens.resume(now);
      if (fresh) _limiter.newSession();
      if (!_enabled) return;
      if (fresh) track('session_start', {'launch': 'resume'});
      _crumb('lifecycle', 'resumed');
      _startTimer();
      unawaited(flush());
    } catch (_) {}
  }

  // ── handlers ───────────────────────────────────────────────────────────

  void _installErrorHandlers() {
    FlutterError.onError = (details) {
      // Same console output as before telemetry existed.
      FlutterError.presentError(details);
      recordFlutterError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      if (kDebugMode) debugPrint('[uncaught] $error\n$stack');
      return recordPlatformError(error, stack);
    };
  }

  @visibleForTesting
  Future<void> settle() => _writes;
}

/// `StateError`, `_TypeError`, `List<int>`: the runtime type, reduced to the
/// characters the contract allows.
String errorTypeLabel(Object error) {
  final raw = error.runtimeType.toString().replaceAll(
    RegExp(r'[^\w.<>$]'),
    '_',
  );
  return raw.length > 80 ? raw.substring(0, 80) : raw;
}
