import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:korean_game/stats/bookmark_store.dart';
import 'package:korean_game/stats/data_transfer.dart';
import 'package:korean_game/stats/error_stats.dart';
import 'package:korean_game/stats/stats_store.dart';

void main() {
  late StatsStore stats;
  late ErrorStatsStore errors;
  late BookmarkStore bookmarks;
  late Directory tmpDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('transfer_test');
    stats = StatsStore(path: p.join(tmpDir.path, 'stats.db'));
    errors = ErrorStatsStore(path: p.join(tmpDir.path, 'errors.db'));
    bookmarks = BookmarkStore(path: p.join(tmpDir.path, 'bookmarks.db'));
  });

  tearDown(() async {
    await stats.close();
    await errors.close();
    await bookmarks.close();
    await tmpDir.delete(recursive: true);
  });

  Future<void> seed() async {
    await stats.recordStudy(DateTime(2026, 10, 1));
    await stats.recordSession(DateTime(2026, 10, 1), 10, 7, level: 2);
    await stats.unlockAchievement('first_quiz', DateTime(2026, 10, 1));
    await stats.setDailyGoal(20);
    await errors.recordAttempt(key: 'k:사랑', isCorrect: false);
    await bookmarks.add('t1-001');
  }

  test('round trip preserves all data', () async {
    await seed();
    final json = await exportJson(
      stats: stats,
      errors: errors,
      bookmarks: bookmarks,
    );

    final dir2 = await Directory.systemTemp.createTemp('transfer_test2');
    final fresh2Stats = StatsStore(path: p.join(dir2.path, 'stats.db'));
    final fresh2Errors = ErrorStatsStore(path: p.join(dir2.path, 'errors.db'));
    final fresh2Bookmarks =
        BookmarkStore(path: p.join(dir2.path, 'bookmarks.db'));
    try {
      final summary = await importJson(
        json,
        stats: fresh2Stats,
        errors: fresh2Errors,
        bookmarks: fresh2Bookmarks,
      );

      expect(summary.days, 1);
      expect(summary.sessions, 1);
      expect(summary.achievements, 1);
      expect(await fresh2Stats.allStudyDays(), ['2026-10-01']);
      final sessions = await fresh2Stats.allSessions();
      expect(sessions.length, 1);
      expect(sessions.first.correct, 7);
      expect(sessions.first.level, 2);
      expect(await fresh2Stats.unlockedAchievements(), {'first_quiz'});
      expect(await fresh2Stats.getDailyGoal(), 20);
      expect(await fresh2Errors.allEntries(), hasLength(1));
      expect(await fresh2Bookmarks.allIds(), ['t1-001']);
    } finally {
      await fresh2Stats.close();
      await fresh2Errors.close();
      await fresh2Bookmarks.close();
      await dir2.delete(recursive: true);
    }
  });

  test('exported payload is versioned JSON', () async {
    await seed();
    final decoded = jsonDecode(await exportJson(stats: stats))
        as Map<String, dynamic>;

    expect(decoded['version'], 1);
    expect(decoded['study_days'], isList);
  });

  test('invalid payload throws FormatException', () async {
    expect(
      () => importJson('not json',
          stats: stats, errors: errors, bookmarks: bookmarks),
      throwsFormatException,
    );
    expect(
      () => importJson('{"version": 999}',
          stats: stats, errors: errors, bookmarks: bookmarks),
      throwsFormatException,
    );
    expect(
      () => importJson('{"version": 1, "study_days": "oops"}',
          stats: stats, errors: errors, bookmarks: bookmarks),
      throwsFormatException,
    );
  });

  test('import merges without duplicating days', () async {
    await seed();
    final json = await exportJson(stats: stats);

    final summary = await importJson(json, stats: stats);

    expect(summary.days, 1);
    expect(await stats.allStudyDays(), ['2026-10-01']);
  });
}
