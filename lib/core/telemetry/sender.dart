/// Batching, back-off and the HTTP call. The first two are pure.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/env.dart';
import 'queue.dart';

const int maxEventsPerBatch = 100;
const int maxErrorsPerBatch = 10;
const int maxUnauthEventsPerBatch = 20;

/// The server refuses more than 64 KB; leave room for the envelope's own
/// accounting being a few bytes off.
const int maxBodyBytes = 64000;

/// Items older than this are not worth sending: the server drops anything
/// older than 7 days anyway.
const Duration maxItemAge = Duration(days: 6);

class Envelope {
  const Envelope({
    required this.installId,
    required this.appVersion,
    required this.appBuild,
    required this.device,
  });

  final String installId;
  final String appVersion;
  final int appBuild;
  final Map<String, Object> device;
}

class Batch {
  Batch({
    required this.items,
    required this.discard,
    required this.body,
  });

  /// Rows in this request; deleted once the server accepts it (or can never).
  final List<QueueItem> items;

  /// Rows that can never be sent (too old, or alone over the size limit).
  final List<QueueItem> discard;
  final String body;

  List<int> get rows => [
    for (final i in [...items, ...discard]) i.row!,
  ];
}

/// Picks the next request out of [queued] (oldest first).
///
/// One request carries one session and one app version, so a queue spanning a
/// restart or an update goes out as several. [authed] false applies the
/// tighter unauthenticated event cap.
Batch buildBatch(
  List<QueueItem> queued, {
  required Envelope envelope,
  required bool authed,
  required DateTime now,
}) {
  final discard = <QueueItem>[];
  final picked = <QueueItem>[];
  final maxEvents = authed ? maxEventsPerBatch : maxUnauthEventsPerBatch;
  final cutoff = now.subtract(maxItemAge).millisecondsSinceEpoch;

  String? sessionId;
  String? version;
  int? build;
  var events = 0;
  var errors = 0;

  // Fixed part of the body, measured once with empty arrays.
  int bodySize(String sessionId, String version, int build) => utf8
      .encode(
        jsonEncode(
          _envelopeJson(envelope, sessionId, version, build, now)
            ..['events'] = const []
            ..['errors'] = const [],
        ),
      )
      .length;

  var size = 0;
  for (final item in queued) {
    if (item.atMs < cutoff) {
      discard.add(item);
      continue;
    }
    if (sessionId != null &&
        (item.sessionId != sessionId ||
            item.appVersion != version ||
            item.appBuild != build)) {
      continue;
    }
    if (item.isError ? errors >= maxErrorsPerBatch : events >= maxEvents) {
      continue;
    }
    final itemBytes = utf8.encode(item.body).length + 1;
    final base = sessionId == null
        ? bodySize(item.sessionId, item.appVersion, item.appBuild)
        : size;
    if (base + itemBytes > maxBodyBytes) {
      // Alone it would not fit either: it can never be sent.
      if (picked.isEmpty) {
        discard.add(item);
      }
      continue;
    }
    sessionId ??= item.sessionId;
    version ??= item.appVersion;
    build ??= item.appBuild;
    size = base + itemBytes;
    picked.add(item);
    if (item.isError) {
      errors++;
    } else {
      events++;
    }
  }

  if (picked.isEmpty) {
    return Batch(items: const [], discard: discard, body: '');
  }

  final json = _envelopeJson(envelope, sessionId!, version!, build!, now)
    ..['events'] = [
      for (final i in picked)
        if (!i.isError) jsonDecode(i.body),
    ]
    ..['errors'] = [
      for (final i in picked)
        if (i.isError) jsonDecode(i.body),
    ];
  return Batch(items: picked, discard: discard, body: jsonEncode(json));
}

Map<String, Object?> _envelopeJson(
  Envelope e,
  String sessionId,
  String version,
  int build,
  DateTime now,
) => {
  'install_id': e.installId,
  'session_id': sessionId,
  'app': {'version': version, 'build': build},
  'device': e.device,
  'sent_at': now.toUtc().toIso8601String(),
};

/// 30 s, doubling to 10 min. A 429's `Retry-After` overrides the schedule.
class FlushBackoff {
  static const Duration base = Duration(seconds: 30);
  static const Duration ceiling = Duration(minutes: 10);

  int _failures = 0;
  DateTime? _until;

  Duration failed(DateTime now) {
    _failures++;
    var delay = base * (1 << (_failures - 1).clamp(0, 10));
    if (delay > ceiling) delay = ceiling;
    _until = now.add(delay);
    return delay;
  }

  void retryAfter(Duration wait, DateTime now) {
    _until = now.add(wait);
  }

  void succeeded() {
    _failures = 0;
    _until = null;
  }

  bool blocked(DateTime now) => _until != null && now.isBefore(_until!);
}

class TransportResult {
  const TransportResult({this.status, this.retryAfter});

  /// Null when the request never completed (offline, timeout, bad address).
  final int? status;
  final Duration? retryAfter;
}

abstract class TelemetryTransport {
  Future<TransportResult> post(String body, {String? token});
}

class HttpTelemetryTransport implements TelemetryTransport {
  HttpTelemetryTransport({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<TransportResult> post(String body, {String? token}) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/app/telemetry'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 20));
      final seconds = int.tryParse(response.headers['retry-after'] ?? '');
      return TransportResult(
        status: response.statusCode,
        retryAfter: seconds == null ? null : Duration(seconds: seconds),
      );
    } catch (_) {
      return const TransportResult();
    }
  }
}
