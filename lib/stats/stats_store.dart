import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class StatsStore {
  StatsStore({this.path, DatabaseFactory? factory})
      : _factory = factory ?? databaseFactory;

  final String? path;
  final DatabaseFactory _factory;
  Database? _db;

  Future<Database> _database() async {
    if (_db != null) return _db!;
    final dbPath = path ?? p.join(await getDatabasesPath(), 'stats.db');
    _db = await _factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) => db.execute('''
CREATE TABLE study_days(
  day TEXT PRIMARY KEY
)
'''),
      ),
    );
    return _db!;
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

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
