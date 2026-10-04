import 'package:sqflite/sqflite.dart';

import '../db/database_init.dart';

/// Saved words for review, stored separately from SRS progress.
class BookmarkStore {
  BookmarkStore({this.path, DatabaseFactory? factory})
      : _factory = factory ?? databaseFactoryForPlatform;

  final String? path;
  final DatabaseFactory _factory;
  Database? _db;

  Future<Database> _database() async {
    if (_db != null) return _db!;
    final dbPath = path ?? await defaultDbPath('bookmarks.db');
    _db = await _factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) => db.execute('''
CREATE TABLE bookmarks(
  wordId TEXT PRIMARY KEY,
  savedMs INTEGER NOT NULL
)
'''),
      ),
    );
    return _db!;
  }

  Future<void> add(String wordId) async {
    final db = await _database();
    await db.insert(
      'bookmarks',
      {
        'wordId': wordId,
        'savedMs': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> remove(String wordId) async {
    final db = await _database();
    await db.delete('bookmarks', where: 'wordId = ?', whereArgs: [wordId]);
  }

  Future<bool> contains(String wordId) async {
    final db = await _database();
    final rows = await db.query(
      'bookmarks',
      where: 'wordId = ?',
      whereArgs: [wordId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Newest first.
  Future<List<String>> allIds() async {
    final db = await _database();
    final rows = await db.query('bookmarks', orderBy: 'savedMs DESC');
    return [for (final r in rows) r['wordId'] as String];
  }

  Future<void> clear() async {
    final db = await _database();
    await db.delete('bookmarks');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
