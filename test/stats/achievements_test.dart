import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:korean_game/stats/achievements.dart';
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

  test('first quiz and accuracy unlock on a strong session', () async {
    await store.recordSession(DateTime(2026, 10, 3), 10, 9, level: 1);

    final fresh = await evaluateNewAchievements(
      stats: store,
      today: DateTime(2026, 10, 3),
    );

    expect(fresh, containsAll(['first_quiz', 'accuracy_80']));
    expect(await store.unlockedAchievements(),
        containsAll(['first_quiz', 'accuracy_80']));
  });

  test('weak session unlocks first quiz only', () async {
    await store.recordSession(DateTime(2026, 10, 3), 10, 5, level: 1);

    final fresh = await evaluateNewAchievements(
      stats: store,
      today: DateTime(2026, 10, 3),
    );

    expect(fresh, ['first_quiz']);
  });

  test('streak achievements unlock at 3 and 7 days', () async {
    for (var i = 1; i <= 7; i++) {
      await store.recordStudy(DateTime(2026, 10, i));
    }
    await store.recordSession(DateTime(2026, 10, 7), 10, 5, level: 1);

    final fresh = await evaluateNewAchievements(
      stats: store,
      today: DateTime(2026, 10, 7),
    );

    expect(fresh, containsAll(['streak_3', 'streak_7']));
  });

  test('100 correct answers unlocks total_100', () async {
    for (var i = 0; i < 10; i++) {
      await store.recordSession(DateTime(2026, 10, 3), 10, 10, level: 1);
    }

    final fresh = await evaluateNewAchievements(
      stats: store,
      today: DateTime(2026, 10, 3),
    );

    expect(fresh, contains('total_100'));
  });

  test('sessions in all six levels unlock all_levels', () async {
    for (var level = 1; level <= 6; level++) {
      await store.recordSession(DateTime(2026, 10, 3), 10, 5, level: level);
    }

    final fresh = await evaluateNewAchievements(
      stats: store,
      today: DateTime(2026, 10, 3),
    );

    expect(fresh, contains('all_levels'));
  });

  test('combo streak unlocks combo_10', () async {
    await store.recordSession(DateTime(2026, 10, 3), 12, 10, level: 1);

    final fresh = await evaluateNewAchievements(
      stats: store,
      today: DateTime(2026, 10, 3),
      sessionBestStreak: 10,
    );

    expect(fresh, contains('combo_10'));
  });

  test('short combo streak does not unlock combo_10', () async {
    await store.recordSession(DateTime(2026, 10, 3), 12, 10, level: 1);

    final fresh = await evaluateNewAchievements(
      stats: store,
      today: DateTime(2026, 10, 3),
      sessionBestStreak: 9,
    );

    expect(fresh, isNot(contains('combo_10')));
  });

  test('perfect sessions in all levels unlock perfect_levels', () async {
    var fresh = <String>[];
    for (var level = 1; level <= 6; level++) {
      await store.recordSession(DateTime(2026, 10, 3), 5, 5, level: level);
      fresh = await evaluateNewAchievements(
        stats: store,
        today: DateTime(2026, 10, 3),
      );
    }

    expect(fresh, contains('perfect_levels'));
    expect(await store.perfectLevels(), {1, 2, 3, 4, 5, 6});
  });

  test('imperfect session does not mark perfect level', () async {
    await store.recordSession(DateTime(2026, 10, 3), 5, 4, level: 1);

    await evaluateNewAchievements(
      stats: store,
      today: DateTime(2026, 10, 3),
    );

    expect(await store.perfectLevels(), isEmpty);
  });

  test('already unlocked achievements are not granted twice', () async {
    await store.recordSession(DateTime(2026, 10, 3), 10, 9, level: 1);
    await evaluateNewAchievements(stats: store, today: DateTime(2026, 10, 3));

    final fresh = await evaluateNewAchievements(
      stats: store,
      today: DateTime(2026, 10, 3),
    );

    expect(fresh, isEmpty);
  });
}
