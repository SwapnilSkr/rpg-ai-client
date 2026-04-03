import 'package:sqflite/sqflite.dart';
import '../../shared/models/event.dart';

class LocalDb {
  static Database? _db;

  static Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/everlore_cache.db';
    return openDatabase(path, version: 1, onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE events (
          id TEXT PRIMARY KEY,
          instance_id TEXT NOT NULL,
          sequence INTEGER NOT NULL,
          type TEXT NOT NULL,
          player_input TEXT,
          ai_response TEXT,
          scene_tag TEXT,
          state_mutations TEXT,
          flag_mutations TEXT,
          created_at TEXT NOT NULL,
          is_optimistic INTEGER DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE instances (
          id TEXT PRIMARY KEY,
          template_id TEXT NOT NULL,
          title TEXT,
          world_state TEXT,
          active_flags TEXT,
          last_active_at TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE memories (
          id TEXT PRIMARY KEY,
          instance_id TEXT NOT NULL,
          text TEXT NOT NULL,
          type TEXT,
          importance INTEGER
        )
      ''');
      await db.execute(
        'CREATE INDEX idx_events_instance ON events(instance_id, sequence)',
      );
      await db.execute(
        'CREATE INDEX idx_memories_instance ON memories(instance_id)',
      );
    });
  }

  static Future<List<GameEvent>> getEvents(
    String instanceId, {
    int limit = 50,
  }) async {
    final db = await database;
    final rows = await db.query(
      'events',
      where: 'instance_id = ?',
      whereArgs: [instanceId],
      orderBy: 'sequence DESC',
      limit: limit,
    );
    return rows.reversed.map((r) => GameEvent.fromSqlite(r)).toList();
  }

  static Future<void> insertEvent(GameEvent event) async {
    final db = await database;
    await db.insert(
      'events',
      event.toSqlite(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> clearOptimisticEvents(String instanceId) async {
    final db = await database;
    await db.delete(
      'events',
      where: 'instance_id = ? AND is_optimistic = 1',
      whereArgs: [instanceId],
    );
  }

  static Future<void> clearInstanceCache(String instanceId) async {
    final db = await database;
    await db.delete('events', where: 'instance_id = ?', whereArgs: [instanceId]);
    await db.delete('memories', where: 'instance_id = ?', whereArgs: [instanceId]);
  }
}
