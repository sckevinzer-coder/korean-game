import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:korean_game/db/progress_store.dart';
import 'package:korean_game/srs/srs_scheduler.dart';

SrsCard card({
  required String wordId,
  required DateTime dueDate,
  Duration interval = const Duration(days: 1),
  double ease = 2.5,
}) =>
    SrsCard(wordId: wordId, interval: interval, ease: ease, dueDate: dueDate);

void main() {
  late ProgressStore store;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    store = ProgressStore(path: inMemoryDatabasePath);
  });

  tearDown(() async {
    await store.close();
  });

  test('upsert then dueCards returns only cards with dueDate <= now', () async {
    final now = DateTime(2026, 10, 3, 12);
    await store.upsert(card(wordId: 't1-001', dueDate: now.subtract(const Duration(hours: 1))));
    await store.upsert(card(wordId: 't1-002', dueDate: now));
    await store.upsert(card(wordId: 't1-003', dueDate: now.add(const Duration(hours: 1))));

    final due = await store.dueCards(now);
    expect(due.map((c) => c.wordId).toSet(), {'t1-001', 't1-002'});
  });

  test('newly studied card due later today is excluded from dueCards(now)', () async {
    final now = DateTime(2026, 10, 3, 12);
    final studied = schedule(
      card(wordId: 't1-001', dueDate: now.subtract(const Duration(days: 3)), interval: const Duration(days: 3)),
      Grade.good,
      now,
    );
    await store.upsert(studied);

    final due = await store.dueCards(now);
    expect(due, isEmpty);
    expect(studied.dueDate.isAfter(now), isTrue);
  });

  test('upsert replaces existing card and allCardsForLevel filters by level', () async {
    final now = DateTime(2026, 10, 3, 12);
    await store.upsert(card(wordId: 't1-001', dueDate: now));
    await store.upsert(card(wordId: 't2-001', dueDate: now));
    await store.upsert(card(wordId: 't1-001', dueDate: now.add(const Duration(days: 5)), ease: 3.0));

    final level1 = await store.allCardsForLevel(1);
    expect(level1.length, 1);
    expect(level1.first.wordId, 't1-001');
    expect(level1.first.ease, 3.0);
    expect((await store.allCardsForLevel(2)).length, 1);
  });
}
