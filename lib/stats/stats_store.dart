import 'package:sqflite/sqflite.dart';

import '../db/database_init.dart';

class StatsStore {
  StatsStore({this.path, DatabaseFactory? factory})
      : _factory = factory ?? databaseFactoryForPlatform;

  final String? path;
  final DatabaseFactory _factory;
  Database? _db;

  Future<Database> _database() async {
    if (_db != null) return _db!;
    final dbPath = path ?? await defaultDbPath('stats.db');
    _db = await _factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''
CREATE TABLE study_days(
  day TEXT PRIMARY KEY
)
''');
          await _createV2Tables(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await _createV2Tables(db);
          }
        },
      ),
    );
    return _db!;
  }

  static Future<void> _createV2Tables(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS sessions(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  day TEXT NOT NULL,
  total INTEGER NOT NULL,
  correct INTEGER NOT NULL,
  level INTEGER NOT NULL DEFAULT 0
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS achievements(
  id TEXT PRIMARY KEY,
  unlocked_at TEXT NOT NULL
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS freezes(
  week TEXT PRIMARY KEY
)
''');
  }

  static String _dayKey(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$dd';
  }

  Future<void> recordStudy(DateTime day) async {
    final db = await _database();
    await db.insert(
      'study_days',
      {'day': _dayKey(day)},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<int> currentStreak(DateTime today) async {
    final db = await _database();
    var cursor = DateTime(today.year, today.month, today.day);
    var streak = 0;
    while (true) {
      final rows = await db.query(
        'study_days',
        where: 'day = ?',
        whereArgs: [_dayKey(cursor)],
      );
      if (rows.isEmpty) break;
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Home display value: max(streak(today), streak(yesterday)).
  ///
  /// Single query round trip so the home future stays fast.
  Future<int> displayStreak(DateTime today) async {
    final db = await _database();
    final rows = await db.query('study_days');
    final days = <String>{for (final row in rows) row['day'] as String};
    int countFrom(DateTime start) {
      var cursor = DateTime(start.year, start.month, start.day);
      var streak = 0;
      while (days.contains(_dayKey(cursor))) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      }
      return streak;
    }

    final a = countFrom(today);
    final b = countFrom(today.subtract(const Duration(days: 1)));
    return a >= b ? a : b;
  }

  /// Study-day flags for the last 7 days, oldest first, ending today.
  Future<List<bool>> last7Days(DateTime today) async {
    final db = await _database();
    final rows = await db.query('study_days');
    final days = <String>{for (final row in rows) row['day'] as String};
    final base = DateTime(today.year, today.month, today.day);
    return [
      for (var i = 6; i >= 0; i--)
        days.contains(_dayKey(base.subtract(Duration(days: i)))),
    ];
  }

  /// Study-day flags for the last 30 days, oldest first, ending today.
  Future<List<bool>> last30Days(DateTime today) async {
    final db = await _database();
    final rows = await db.query('study_days');
    final days = <String>{for (final row in rows) row['day'] as String};
    final base = DateTime(today.year, today.month, today.day);
    return [
      for (var i = 29; i >= 0; i--)
        days.contains(_dayKey(base.subtract(Duration(days: i)))),
    ];
  }

  /// Records one finished quiz session.
  Future<void> recordSession(
    DateTime day,
    int total,
    int correct, {
    int level = 0,
  }) async {
    final db = await _database();
    await db.insert('sessions', {
      'day': _dayKey(day),
      'total': total,
      'correct': correct,
      'level': level,
    });
  }

  /// Lifetime totals across all recorded sessions.
  Future<({int total, int correct})> lifetimeTotals() async {
    final db = await _database();
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(total), 0) AS t, COALESCE(SUM(correct), 0) AS c'
      ' FROM sessions',
    );
    return (
      total: (rows.first['t'] as int?) ?? 0,
      correct: (rows.first['c'] as int?) ?? 0,
    );
  }

  /// Quiz levels (1-6) with at least one recorded session.
  Future<Set<int>> completedLevels() async {
    final db = await _database();
    final rows = await db.rawQuery(
      'SELECT DISTINCT level AS lv FROM sessions WHERE level BETWEEN 1 AND 6',
    );
    return {for (final row in rows) (row['lv'] as int?) ?? 0};
  }

  /// Most recent sessions, oldest first, capped at [limit].
  Future<List<SessionRecord>> recentSessions(int limit) async {
    final db = await _database();
    final rows = await db.query(
      'sessions',
      orderBy: 'id DESC',
      limit: limit,
    );
    return [
      for (final row in rows.reversed)
        SessionRecord(
          day: row['day'] as String,
          total: row['total'] as int,
          correct: row['correct'] as int,
        ),
    ];
  }

  /// Unlocks an achievement once; repeat calls are ignored.
  Future<void> unlockAchievement(String id, DateTime when) async {
    final db = await _database();
    await db.insert(
      'achievements',
      {'id': id, 'unlocked_at': when.toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Ids of all unlocked achievements.
  Future<Set<String>> unlockedAchievements() async {
    final db = await _database();
    final rows = await db.query('achievements');
    return {for (final row in rows) row['id'] as String};
  }

  static String _weekKey(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final monday = d.subtract(Duration(days: d.weekday - 1));
    return _dayKey(monday);
  }

  /// Freezes left this week (Monday-based). One per week.
  Future<int> freezesLeft(DateTime today) async {
    final db = await _database();
    final rows = await db.query(
      'freezes',
      where: 'week = ?',
      whereArgs: [_weekKey(today)],
    );
    return rows.isEmpty ? 1 : 0;
  }

  /// Consumes this week's freeze. Returns false when already used.
  Future<bool> useFreeze(DateTime today) async {
    final db = await _database();
    final count = await db.insert(
      'freezes',
      {'week': _weekKey(today)},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return count != 0;
  }

  /// Streak that tolerates one single missed day by consuming the weekly
  /// freeze. Never consumes the freeze when today itself is unstudied.
  Future<ProtectedStreak> protectedStreak(DateTime today) async {
    final db = await _database();
    final rows = await db.query('study_days');
    final days = <String>{for (final row in rows) row['day'] as String};
    bool studied(DateTime d) => days.contains(_dayKey(d));

    final base = DateTime(today.year, today.month, today.day);
    if (!studied(base)) {
      return const ProtectedStreak(streak: 0, freezeUsed: false);
    }
    var cursor = base;
    var streak = 0;
    var freezeUsed = false;
    while (true) {
      if (studied(cursor)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
        continue;
      }
      final older = cursor.subtract(const Duration(days: 1));
      if (!freezeUsed && studied(older) && await useFreeze(today)) {
        freezeUsed = true;
        streak++;
        cursor = older.subtract(const Duration(days: 1));
        continue;
      }
      break;
    }
    return ProtectedStreak(streak: streak, freezeUsed: freezeUsed);
  }

  /// Daily question goal. Defaults to 10.
  static const int defaultDailyGoal = 10;

  Future<void> _ensureSettingsTable() async {
    final db = await _database();
    await db.execute('''
CREATE TABLE IF NOT EXISTS settings(
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
)
''');
  }

  Future<int> getDailyGoal() async {
    await _ensureSettingsTable();
    final db = await _database();
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['daily_goal'],
    );
    if (rows.isEmpty) return defaultDailyGoal;
    return int.tryParse(rows.first['value'] as String? ?? '') ??
        defaultDailyGoal;
  }

  Future<void> setDailyGoal(int goal) async {
    await _ensureSettingsTable();
    final db = await _database();
    await db.insert(
      'settings',
      {'key': 'daily_goal', 'value': goal.toString()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Questions answered today (sum of session totals for the day).
  Future<int> todaySolvedCount(DateTime today) async {
    final db = await _database();
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(total), 0) AS t FROM sessions WHERE day = ?',
      [_dayKey(today)],
    );
    return (rows.first['t'] as int?) ?? 0;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

/// Streak result with freeze consumption flag.
class ProtectedStreak {
  const ProtectedStreak({required this.streak, required this.freezeUsed});

  final int streak;
  final bool freezeUsed;
}

/// One recorded quiz session.
class SessionRecord {
  const SessionRecord({
    required this.day,
    required this.total,
    required this.correct,
  });

  final String day;
  final int total;
  final int correct;

  double get rate => total == 0 ? 0.0 : correct / total;
}
