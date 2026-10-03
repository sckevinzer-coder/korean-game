import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../srs/srs_scheduler.dart';

class ProgressStore {
  ProgressStore({this.path, DatabaseFactory? factory})
      : _factory = factory ?? databaseFactory;

  final String? path;
  final DatabaseFactory _factory;
  Database? _db;

  Future<Database> _database() async {
    if (_db != null) return _db!;
    final dbPath = path ?? p.join(await getDatabasesPath(), 'progress.db');
    _db = await _factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) => db.execute('''
CREATE TABLE cards(
  wordId TEXT PRIMARY KEY,
  intervalMs INTEGER NOT NULL,
  ease REAL NOT NULL,
  dueDateMs INTEGER NOT NULL,
  level INTEGER NOT NULL
)
'''),
      ),
    );
    return _db!;
  }

  int _levelFor(String wordId) {
    final match = RegExp(r'^t(\d+)-').firstMatch(wordId);
    if (match == null) {
      throw ArgumentError('wordId must look like t<level>-<n>, got: $wordId');
    }
    return int.parse(match.group(1)!);
  }

  Future<void> upsert(SrsCard card) async {
    final db = await _database();
    await db.insert(
      'cards',
      {
        'wordId': card.wordId,
        'intervalMs': card.interval.inMilliseconds,
        'ease': card.ease,
        'dueDateMs': card.dueDate.millisecondsSinceEpoch,
        'level': _levelFor(card.wordId),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  SrsCard _fromRow(Map<String, Object?> row) => SrsCard(
        wordId: row['wordId'] as String,
        interval: Duration(milliseconds: row['intervalMs'] as int),
        ease: (row['ease'] as num).toDouble(),
        dueDate: DateTime.fromMillisecondsSinceEpoch(row['dueDateMs'] as int),
      );

  Future<List<SrsCard>> dueCards(DateTime now) async {
    final db = await _database();
    final rows = await db.query(
      'cards',
      where: 'dueDateMs <= ?',
      whereArgs: [now.millisecondsSinceEpoch],
    );
    return rows.map(_fromRow).toList();
  }

  Future<List<SrsCard>> allCardsForLevel(int level) async {
    final db = await _database();
    final rows = await db.query('cards', where: 'level = ?', whereArgs: [level]);
    return rows.map(_fromRow).toList();
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
