import 'package:flutter_test/flutter_test.dart';
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
}
