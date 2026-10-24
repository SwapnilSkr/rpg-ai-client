import 'package:everlore/core/telemetry/queue.dart';

/// In-memory stand-in for the sqflite store; same contract, no platform.
class MemoryTelemetryStore implements TelemetryStore {
  final List<QueueItem> items = [];
  final Map<String, String> meta = {};
  int _row = 0;

  @override
  Future<bool> insert(QueueItem item, {int? nextSeq}) async {
    if (items.any((i) => i.itemId == item.itemId)) return false;
    items.add(
      QueueItem(
        row: ++_row,
        kind: item.kind,
        itemId: item.itemId,
        sessionId: item.sessionId,
        appVersion: item.appVersion,
        appBuild: item.appBuild,
        atMs: item.atMs,
        body: item.body,
      ),
    );
    if (nextSeq != null) meta['next_seq'] = '$nextSeq';
    return true;
  }

  @override
  Future<List<QueueItem>> peek(int limit) async => items.take(limit).toList();

  @override
  Future<void> deleteRows(List<int> rows) async =>
      items.removeWhere((i) => rows.contains(i.row));

  @override
  Future<int> count() async => items.length;

  @override
  Future<void> dropOldest(int n) async =>
      items.removeRange(0, n > items.length ? items.length : n);

  @override
  Future<void> clear() async => items.clear();

  @override
  Future<String?> getMeta(String key) async => meta[key];

  @override
  Future<void> setMeta(String key, String value) async => meta[key] = value;
}
