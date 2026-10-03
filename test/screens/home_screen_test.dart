import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:korean_game/db/progress_store.dart';
import 'package:korean_game/models/word.dart';
import 'package:korean_game/screens/home_screen.dart';
import 'package:korean_game/srs/srs_scheduler.dart';

Word word(String id) => Word(
      id: id,
      korean: '한국어',
      reading: 'hangugeo',
      meaningJa: '韓国語',
      exampleKo: '예문',
      exampleJa: '例文',
      topikLevel: 1,
    );

void main() {
  late ProgressStore store;

  final DateTime now = DateTime(2026, 10, 3, 12);

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    store = ProgressStore(path: inMemoryDatabasePath);
    await store.upsert(SrsCard(
        wordId: 't1-001',
        interval: const Duration(days: 1),
        ease: 2.5,
        dueDate: now.subtract(const Duration(hours: 3))));
    await store.upsert(SrsCard(
        wordId: 't1-002',
        interval: const Duration(days: 1),
        ease: 2.5,
        dueDate: now.subtract(const Duration(hours: 1))));
    await store.upsert(SrsCard(
        wordId: 't1-003',
        interval: const Duration(days: 1),
        ease: 2.5,
        dueDate: now.add(const Duration(days: 1))));
  });

  tearDown(() async {
    await store.close();
  });

  testWidgets('shows count of due cards and streak', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(
        store: store,
        streak: 5,
        now: () => now,
        loadWords: (level) async =>
            List.generate(10, (i) => word('t1-${i + 1}')),
      ),
    ));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();

    expect(find.text('今日の復習: 2 / 10 枚'), findsOneWidget);
    expect(find.text('連続学習: 5日'), findsOneWidget);
  });
}
