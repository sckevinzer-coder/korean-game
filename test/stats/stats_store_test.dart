import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:korean_game/stats/stats_store.dart';

void main() {
  late StatsStore store;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    store = StatsStore(path: inMemoryDatabasePath);
  });

  tearDown(() async {
    await store.close();
  });

  test('same day twice does not double-count', () async {
    final day = DateTime(2026, 10, 3, 9);
    await store.recordStudy(day);
    await store.recordStudy(DateTime(2026, 10, 3, 21, 30));

    expect(await store.currentStreak(day), 1);
  });

  test('consecutive days increment', () async {
    final d1 = DateTime(2026, 10, 1);
    final d2 = DateTime(2026, 10, 2);
    final d3 = DateTime(2026, 10, 3);
    await store.recordStudy(d1);
    expect(await store.currentStreak(d1), 1);
    await store.recordStudy(d2);
    expect(await store.currentStreak(d2), 2);
    await store.recordStudy(d3);
    expect(await store.currentStreak(d3), 3);
  });

  test('gap resets streak', () async {
    await store.recordStudy(DateTime(2026, 10, 1));
    await store.recordStudy(DateTime(2026, 10, 2));
    // Skip Oct 3, study on Oct 4.
    await store.recordStudy(DateTime(2026, 10, 4));

    expect(await store.currentStreak(DateTime(2026, 10, 4)), 1);
  });

  test('no study on today yields zero', () async {
    await store.recordStudy(DateTime(2026, 10, 1));
    await store.recordStudy(DateTime(2026, 10, 2));

    expect(await store.currentStreak(DateTime(2026, 10, 3)), 0);
  });

  test('empty store yields zero', () async {
    expect(await store.currentStreak(DateTime(2026, 10, 3)), 0);
  });

  test('displayStreak keeps yesterday streak when today missing', () async {
    await store.recordStudy(DateTime(2026, 10, 1));
    await store.recordStudy(DateTime(2026, 10, 2));

    expect(await store.displayStreak(DateTime(2026, 10, 3)), 2);
  });

  test('displayStreak prefers longer today streak', () async {
    await store.recordStudy(DateTime(2026, 10, 1));
    await store.recordStudy(DateTime(2026, 10, 2));
    await store.recordStudy(DateTime(2026, 10, 3));

    expect(await store.displayStreak(DateTime(2026, 10, 3)), 3);
  });

  test('displayStreak is zero with no history', () async {
    expect(await store.displayStreak(DateTime(2026, 10, 3)), 0);
  });

  test('last7Days marks studied days oldest first', () async {
    await store.recordStudy(DateTime(2026, 9, 27));
    await store.recordStudy(DateTime(2026, 9, 29));
    await store.recordStudy(DateTime(2026, 10, 3));

    expect(
      await store.last7Days(DateTime(2026, 10, 3)),
      [true, false, true, false, false, false, true],
    );
  });

  test('last7Days empty on fresh store', () async {
    expect(
      await store.last7Days(DateTime(2026, 10, 3)),
      [false, false, false, false, false, false, false],
    );
  });

  test('last30Days marks studied days oldest first', () async {
    await store.recordStudy(DateTime(2026, 9, 4));
    await store.recordStudy(DateTime(2026, 10, 3));

    final days = await store.last30Days(DateTime(2026, 10, 3));
    expect(days.length, 30);
    expect(days.first, isTrue); // Sep 4
    expect(days.last, isTrue); // Oct 3
    expect(days.where((d) => d).length, 2);
  });

  test('recordSession and recentSessions return chronological rates', () async {
    await store.recordSession(DateTime(2026, 10, 1), 10, 7);
    await store.recordSession(DateTime(2026, 10, 2), 10, 9);
    await store.recordSession(DateTime(2026, 10, 3), 10, 5);

    final sessions = await store.recentSessions(10);
    expect(sessions.map((s) => s.correct).toList(), [7, 9, 5]);
    expect(sessions.map((s) => s.rate).toList(), [0.7, 0.9, 0.5]);
  });

  test('recentSessions respects limit with newest kept', () async {
    for (var i = 1; i <= 5; i++) {
      await store.recordSession(DateTime(2026, 10, i), 10, i);
    }

    final sessions = await store.recentSessions(3);
    expect(sessions.map((s) => s.correct).toList(), [3, 4, 5]);
  });

  test('achievements unlock once and list unlocked ids', () async {
    expect(await store.unlockedAchievements(), isEmpty);

    await store.unlockAchievement('first_quiz', DateTime(2026, 10, 3));
    await store.unlockAchievement('first_quiz', DateTime(2026, 10, 4));

    expect(await store.unlockedAchievements(), {'first_quiz'});
  });

  test('weekly freeze grants one use per week', () async {
    final monday = DateTime(2026, 9, 28); // Monday
    expect(await store.freezesLeft(monday), 1);

    expect(await store.useFreeze(monday), isTrue);
    expect(await store.freezesLeft(monday), 0);
    expect(await store.useFreeze(monday), isFalse);

    // New week grants a fresh freeze.
    expect(await store.freezesLeft(DateTime(2026, 10, 5)), 1);
  });

  test('protectedStreak without gap consumes nothing', () async {
    await store.recordStudy(DateTime(2026, 10, 1));
    await store.recordStudy(DateTime(2026, 10, 2));
    await store.recordStudy(DateTime(2026, 10, 3));

    final result = await store.protectedStreak(DateTime(2026, 10, 3));
    expect(result.streak, 3);
    expect(result.freezeUsed, isFalse);
    expect(await store.freezesLeft(DateTime(2026, 10, 3)), 1);
  });

  test('protectedStreak bridges a single missed day using freeze', () async {
    await store.recordStudy(DateTime(2026, 10, 1));
    await store.recordStudy(DateTime(2026, 10, 2));
    // Missed Oct 3, studied today Oct 4.
    await store.recordStudy(DateTime(2026, 10, 4));

    final result = await store.protectedStreak(DateTime(2026, 10, 4));
    expect(result.streak, 3);
    expect(result.freezeUsed, isTrue);
    expect(await store.freezesLeft(DateTime(2026, 10, 4)), 0);
  });

  test('protectedStreak cannot bridge a two-day gap', () async {
    await store.recordStudy(DateTime(2026, 10, 1));
    await store.recordStudy(DateTime(2026, 10, 4));

    final result = await store.protectedStreak(DateTime(2026, 10, 4));
    expect(result.streak, 1);
    expect(result.freezeUsed, isFalse);
    expect(await store.freezesLeft(DateTime(2026, 10, 4)), 1);
  });

  test('protectedStreak does not burn freeze when today unstudied', () async {
    await store.recordStudy(DateTime(2026, 10, 1));
    await store.recordStudy(DateTime(2026, 10, 2));

    final result = await store.protectedStreak(DateTime(2026, 10, 3));
    expect(result.freezeUsed, isFalse);
    expect(await store.freezesLeft(DateTime(2026, 10, 3)), 1);
  });

  test('daily goal defaults to 10 and persists', () async {
    expect(await store.getDailyGoal(), 10);

    await store.setDailyGoal(30);
    expect(await store.getDailyGoal(), 30);
  });

  test('todaySolvedCount sums session totals for the day', () async {
    await store.recordSession(DateTime(2026, 10, 2), 10, 7, level: 1);
    await store.recordSession(DateTime(2026, 10, 3), 10, 5, level: 1);
    await store.recordSession(DateTime(2026, 10, 3), 6, 6, level: 2);

    expect(await store.todaySolvedCount(DateTime(2026, 10, 3)), 16);
    expect(await store.todaySolvedCount(DateTime(2026, 10, 2)), 10);
    expect(await store.todaySolvedCount(DateTime(2026, 10, 4)), 0);
  });

  test('v1 database upgrades to v2 preserving study days', () async {
    final dir = await Directory.systemTemp.createTemp('stats_v1_');
    try {
      final dbPath = p.join(dir.path, 'stats.db');
      final v1 = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) =>
              db.execute('CREATE TABLE study_days(day TEXT PRIMARY KEY)'),
        ),
      );
      await v1.insert('study_days', {'day': '2026-10-01'});
      await v1.close();

      final upgraded = StatsStore(path: dbPath);
      expect(await upgraded.currentStreak(DateTime(2026, 10, 1)), 1);
      await upgraded.recordSession(DateTime(2026, 10, 1), 10, 8);
      expect((await upgraded.recentSessions(10)).length, 1);
      await upgraded.unlockAchievement('first_quiz', DateTime(2026, 10, 1));
      expect(await upgraded.unlockedAchievements(), {'first_quiz'});
      expect(await upgraded.freezesLeft(DateTime(2026, 10, 1)), 1);
      await upgraded.close();
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
