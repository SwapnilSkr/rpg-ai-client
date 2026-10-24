/// The durable queue: what has been recorded and not yet accepted by the
/// server. Survives being offline and the process being killed.
library;

import 'package:sqflite/sqflite.dart';

const int queueCap = 2000;

class QueueItem {
  const QueueItem({
    this.row,
    required this.kind,
    required this.itemId,
    required this.sessionId,
    required this.appVersion,
    required this.appBuild,
    required this.atMs,
    required this.body,
  });

  /// Queue order; assigned by the store.
  final int? row;

  /// `event` or `error`.
  final String kind;
  final String itemId;
  final String sessionId;
  final String appVersion;
  final int appBuild;
  final int atMs;

  /// The item as the contract's JSON, already encoded.
  final String body;

  bool get isError => kind == 'error';
}

abstract class TelemetryStore {
  /// False when [item] was already queued (same id): a replayed journal line.
  Future<bool> insert(QueueItem item, {int? nextSeq});
  Future<List<QueueItem>> peek(int limit);
  Future<void> deleteRows(List<int> rows);
  Future<int> count();
  Future<void> dropOldest(int n);
  Future<void> clear();
  Future<String?> getMeta(String key);
  Future<void> setMeta(String key, String value);
}

class TelemetryQueue {
  TelemetryQueue(this.store, {this.cap = queueCap});

  final TelemetryStore store;
  final int cap;

  /// Adds [item]; past [cap] the oldest items are dropped, so a long offline
  /// stretch can never grow the file without bound.
  Future<void> add(QueueItem item, {int? nextSeq}) async {
    final inserted = await store.insert(item, nextSeq: nextSeq);
    if (!inserted) return;
    final size = await store.count();
    if (size > cap) await store.dropOldest(size - cap);
  }
}

/// sqflite-backed store, in its own file so the story cache is never touched.
class SqfliteTelemetryStore implements TelemetryStore {
  Database? _db;

  Future<Database> get _database async => _db ??= await _open();

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      '$dir/telemetry.db',
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE queue (
            row INTEGER PRIMARY KEY AUTOINCREMENT,
            kind TEXT NOT NULL,
            item_id TEXT NOT NULL UNIQUE,
            session_id TEXT NOT NULL,
            app_version TEXT NOT NULL,
            app_build INTEGER NOT NULL,
            at_ms INTEGER NOT NULL,
            body TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
      },
    );
  }

  @override
  Future<bool> insert(QueueItem item, {int? nextSeq}) async {
    final db = await _database;
    return db.transaction((txn) async {
      final id = await txn.insert('queue', {
        'kind': item.kind,
        'item_id': item.itemId,
        'session_id': item.sessionId,
        'app_version': item.appVersion,
        'app_build': item.appBuild,
        'at_ms': item.atMs,
        'body': item.body,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      if (nextSeq != null) {
        await txn.insert('meta', {
          'key': 'next_seq',
          'value': '$nextSeq',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      return id > 0;
    });
  }

  @override
  Future<List<QueueItem>> peek(int limit) async {
    final db = await _database;
    final rows = await db.query('queue', orderBy: 'row ASC', limit: limit);
    return [
      for (final r in rows)
        QueueItem(
          row: r['row'] as int,
          kind: r['kind'] as String,
          itemId: r['item_id'] as String,
          sessionId: r['session_id'] as String,
          appVersion: r['app_version'] as String,
          appBuild: r['app_build'] as int,
          atMs: r['at_ms'] as int,
          body: r['body'] as String,
        ),
    ];
  }

  @override
  Future<void> deleteRows(List<int> rows) async {
    if (rows.isEmpty) return;
    final db = await _database;
    // SQLite caps bound variables; stay well under it.
    for (var i = 0; i < rows.length; i += 400) {
      final chunk = rows.sublist(i, i + 400 > rows.length ? rows.length : i + 400);
      await db.delete(
        'queue',
        where: 'row IN (${List.filled(chunk.length, '?').join(',')})',
        whereArgs: chunk,
      );
    }
  }

  @override
  Future<int> count() async {
    final db = await _database;
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM queue'),
        ) ??
        0;
  }

  @override
  Future<void> dropOldest(int n) async {
    if (n <= 0) return;
    final db = await _database;
    await db.rawDelete(
      'DELETE FROM queue WHERE row IN '
      '(SELECT row FROM queue ORDER BY row ASC LIMIT ?)',
      [n],
    );
  }

  @override
  Future<void> clear() async {
    final db = await _database;
    await db.delete('queue');
  }

  @override
  Future<String?> getMeta(String key) async {
    final db = await _database;
    final rows = await db.query('meta', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  @override
  Future<void> setMeta(String key, String value) async {
    final db = await _database;
    await db.insert('meta', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
