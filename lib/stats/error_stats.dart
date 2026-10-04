import 'package:sqflite/sqflite.dart';

import '../db/database_init.dart';

class WeakItem {
  final String key;
  final int attempts;
  final int errors;
  final String lastError;

  const WeakItem({
    required this.key,
    required this.attempts,
    required this.errors,
    required this.lastError,
  });

  double get errorRate => attempts == 0 ? 0.0 : errors / attempts;
}

/// Tracks per-question mistakes separately from SRS cards.
///
/// Key format is kind plus answer, e.g. writing:사랑해요.
/// Stored in its own database file so existing progress/stats DBs are untouched.
class ErrorStatsStore {
  ErrorStatsStore({this.path, DatabaseFactory? factory})
      : _factory = factory ?? databaseFactoryForPlatform;

  final String? path;
  final DatabaseFactory _factory;
  Database? _db;

  Future<Database> _database() async {
    if (_db != null) return _db!;
    final dbPath = path ?? await defaultDbPath('error_stats.db');
    _db = await _factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) => db.execute('''
CREATE TABLE error_stats(
  key TEXT PRIMARY KEY,
  attempts INTEGER NOT NULL,
  errors INTEGER NOT NULL,
  lastError TEXT NOT NULL,
  updatedMs INTEGER NOT NULL
)
'''),
      ),
    );
    return _db!;
  }

  Future<void> recordAttempt({
    required String key,
    required bool isCorrect,
    String lastError = '',
  }) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'error_stats',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (rows.isEmpty) {
      await db.insert('error_stats', {
        'key': key,
        'attempts': 1,
        'errors': isCorrect ? 0 : 1,
        'lastError': isCorrect ? '' : lastError,
        'updatedMs': now,
      });
      return;
    }
    final row = rows.first;
    final attempts = (row['attempts'] as int) + 1;
    final errors = (row['errors'] as int) + (isCorrect ? 0 : 1);
    await db.update(
      'error_stats',
      {
        'attempts': attempts,
        'errors': errors,
        'lastError': isCorrect ? row['lastError'] as String : lastError,
        'updatedMs': now,
      },
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  Future<List<WeakItem>> topWeak({int limit = 5}) async {
    final db = await _database();
    final rows = await db.query('error_stats');
    final items = rows
        .map((r) => WeakItem(
              key: r['key'] as String,
              attempts: r['attempts'] as int,
              errors: r['errors'] as int,
              lastError: r['lastError'] as String,
            ))
        .where((w) => w.errors > 0)
        .toList()
      ..sort((a, b) {
        final rate = b.errorRate.compareTo(a.errorRate);
        if (rate != 0) return rate;
        return b.errors.compareTo(a.errors);
      });
    return items.take(limit).toList();
  }

  Future<void> clear() async {
    final db = await _database();
    await db.delete('error_stats');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
