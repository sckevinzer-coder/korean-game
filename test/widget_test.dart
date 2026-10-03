import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:korean_game/db/progress_store.dart';
import 'package:korean_game/main.dart';
import 'package:korean_game/models/word.dart';
import 'package:korean_game/screens/home_screen.dart';
import 'package:korean_game/stats/stats_store.dart';

List<Word> fiveWords() => List.generate(
      5,
      (i) => Word(
        id: 't1-00${i + 1}',
        korean: '한국어-$i',
        reading: 'reading-$i',
        meaningJa: '意味-$i',
        exampleKo: '예문-$i',
        exampleJa: '例文-$i',
        topikLevel: 1,
      ),
    );

void main() {
  late ProgressStore store;
  late StatsStore stats;
  late Directory tmpDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Distinct files: sharing inMemoryDatabasePath reuses one SQLite db,
    // so the second schema's onCreate never runs (no such table).
    tmpDir = await Directory.systemTemp.createTemp('korean_game_app');
    store = ProgressStore(path: p.join(tmpDir.path, 'progress.db'));
    stats = StatsStore(path: p.join(tmpDir.path, 'stats.db'));
    await store.dueCards(DateTime(2026, 10, 3));
    await stats.currentStreak(DateTime(2026, 10, 3));
  });

  tearDown(() async {
    await store.close();
    await stats.close();
    await tmpDir.delete(recursive: true);
  });

  Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
    // Poll with real time: FFI store futures resolve outside fake async.
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
      if (finder.evaluate().isNotEmpty) return;
    }
  }

  // NOTE: this file pumps the real asset loader (via MyApp) exactly once.
  // A second rootBundle load in the same file stalls in the fake-async
  // zone, so the cycle test below injects its word list instead.
  testWidgets('app boots to home screen', (tester) async {
    await tester.pumpWidget(MyApp(store: store, stats: stats));
    await pumpUntil(tester, find.text('今日の復習: 500 / 500 枚'));

    expect(find.text('今日の復習: 500 / 500 枚'), findsOneWidget);
    expect(find.text('連続学習: 0日'), findsOneWidget);
    expect(find.text('レベルを選ぶ'), findsOneWidget);
  });

  testWidgets('daily cycle: home to level select to completed session',
      (tester) async {
    final now = DateTime(2026, 10, 3, 12);
    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(
        store: store,
        stats: stats,
        loadWords: (level) async => fiveWords(),
        now: () => now,
      ),
    ));
    await pumpUntil(tester, find.text('レベルを選ぶ'));

    // Home shows the day's starting state.
    expect(find.text('今日の復習: 5 / 5 枚'), findsOneWidget);
    expect(find.text('連続学習: 0日'), findsOneWidget);

    // Level entry point.
    await tester.tap(find.text('レベルを選ぶ'));
    await tester.pumpAndSettle();
    expect(find.text('レベル選択'), findsOneWidget);

    // Start the flashcard session from the level list.
    await tester.tap(find.text('学習する').first);
    await tester.pumpAndSettle();
    expect(find.text('タップして意味を見る'), findsOneWidget);

    // Study all five cards.
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('한국어-$i'));
      await tester.pump();
      await tester.tap(find.text('普通'));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
    }

    // Session completion screen and recorded study day.
    expect(find.text('学習完了！'), findsOneWidget);
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)));
    final streak = await tester.runAsync(() => stats.currentStreak(now));
    expect(streak, 1);
  });
}
