import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:korean_game/db/progress_store.dart';
import 'package:korean_game/models/word.dart';
import 'package:korean_game/screens/level_select_screen.dart';
import 'package:korean_game/stats/stats_store.dart';

Word word(String id, int level, String korean, String meaningJa) => Word(
      id: id,
      korean: korean,
      reading: 'reading-$id',
      meaningJa: meaningJa,
      exampleKo: '예문-$id',
      exampleJa: '例文-$id',
      topikLevel: level,
    );

List<Word> fiveWords(int level, String prefix) => List.generate(
      5,
      (i) => word('$prefix-00${i + 1}', level, '한국어-$prefix-$i', '意味-$prefix-$i'),
    );

void main() {
  late ProgressStore store;
  late StatsStore stats;
  late Directory tmpDir;

  final DateTime now = DateTime(2026, 10, 3, 12);

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Distinct files: sharing inMemoryDatabasePath reuses one SQLite db,
    // so the second schema's onCreate never runs (no such table).
    tmpDir = await Directory.systemTemp.createTemp('korean_game_levels');
    store = ProgressStore(path: p.join(tmpDir.path, 'progress.db'));
    stats = StatsStore(path: p.join(tmpDir.path, 'stats.db'));
    // Warm up FFI databases outside the widget-test zone.
    await store.allCardsForLevel(1);
    await stats.currentStreak(now);
  });

  tearDown(() async {
    await store.close();
    await stats.close();
    await tmpDir.delete(recursive: true);
  });

  Future<void> pumpLevels(
    WidgetTester tester, {
    List<int> levels = const [1, 2],
    Future<List<Word>> Function(int level)? loadWords,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: LevelSelectScreen(
        store: store,
        stats: stats,
        levels: levels,
        loadWords: loadWords ??
            (level) async => fiveWords(level, 't$level'),
        now: () => now,
      ),
    ));
    await tester.pump();
  }

  testWidgets('lists TOPIK levels with word counts', (tester) async {
    await pumpLevels(tester);

    expect(find.text('レベル選択'), findsOneWidget);
    expect(find.text('TOPIK 1級'), findsOneWidget);
    expect(find.text('TOPIK 2級'), findsOneWidget);
    expect(find.text('5語'), findsNWidgets(2));
    expect(find.text('学習する'), findsNWidgets(2));
    expect(find.text('クイズ'), findsNWidgets(2));
  });

  testWidgets('tapping 学習する opens the flashcard session', (tester) async {
    await pumpLevels(tester);

    await tester.tap(find.text('学習する').first);
    await tester.pumpAndSettle();

    // First word of the level-1 pool on the flashcard front.
    expect(find.text('한국어-t1-0'), findsOneWidget);
    expect(find.text('タップして意味を見る'), findsOneWidget);
  });

  testWidgets('tapping クイズ opens the quiz session when pool is large',
      (tester) async {
    await pumpLevels(tester);

    await tester.tap(find.text('クイズ').first);
    await tester.pumpAndSettle();

    expect(find.text('スコア: 0'), findsOneWidget);
    expect(find.text('1 / 5 問'), findsOneWidget);
  });

  testWidgets('tapping クイズ with 1-3 words shows a notice, no navigation',
      (tester) async {
    await pumpLevels(
      tester,
      levels: const [9],
      loadWords: (level) async => [
        word('t9-001', 9, '한국어-A', '意味-A'),
        word('t9-002', 9, '한국어-B', '意味-B'),
      ],
    );

    await tester.tap(find.text('クイズ'));
    await tester.pump();

    expect(find.text('クイズには4語以上必要です'), findsOneWidget);
    // Still on the level list: no quiz screen pushed.
    expect(find.text('スコア: 0'), findsNothing);
    expect(find.text('TOPIK 9級'), findsOneWidget);
  });

  testWidgets('load failure shows an error message', (tester) async {
    await pumpLevels(
      tester,
      loadWords: (level) async => throw Exception('asset missing'),
    );

    expect(find.text('読み込みに失敗しました'), findsOneWidget);
  });

  testWidgets('flashcard session from level select records study',
      (tester) async {
    await pumpLevels(
      tester,
      levels: const [1],
      loadWords: (level) async => [word('t1-001', 1, '한국어', '韓国語')],
    );

    await tester.tap(find.text('学習する'));
    await tester.pumpAndSettle();
    expect(find.text('한국어'), findsOneWidget);

    await tester.tap(find.text('한국어'));
    await tester.pump();
    await tester.tap(find.text('普通'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();

    expect(find.text('学習完了！'), findsOneWidget);
    final streak = await tester.runAsync(() => stats.currentStreak(now));
    expect(streak, 1);
  });
}
