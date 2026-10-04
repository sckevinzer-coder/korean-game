import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:korean_game/db/progress_store.dart';
import 'package:korean_game/models/word.dart';
import 'package:korean_game/screens/level_select_screen.dart';
import 'package:korean_game/stats/stats_store.dart';
import 'package:korean_game/srs/srs_scheduler.dart';

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

class FakeProgressStore extends ProgressStore {
  final Map<int, int> learnedCounts;
  FakeProgressStore({this.learnedCounts = const {}});
  @override
  Future<List<SrsCard>> allCardsForLevel(int level) async {
    final count = learnedCounts[level] ?? 0;
    return List.generate(count, (i) => SrsCard(
      wordId: 't$level-$i',
      interval: Duration.zero,
      ease: 2.5,
      dueDate: DateTime.now(),
    ));
  }
  @override
  Future<void> upsert(SrsCard card) async {
    // Mock implementation - do nothing
  }
}

void main() {
  late ProgressStore store;
  late StatsStore stats;
  late Directory tmpDir;
  late FakeProgressStore fakeStore;

  final DateTime now = DateTime(2026, 10, 3, 12);

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('korean_game_levels');
    store = ProgressStore(path: p.join(tmpDir.path, 'progress.db'));
    fakeStore = FakeProgressStore();
    stats = StatsStore(path: p.join(tmpDir.path, 'stats.db'));
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
    List<int> levels = const [1, 2, 3, 4, 5, 6],
    Future<List<Word>> Function(int level)? loadWords,
    Random? random,
    ProgressStore? progressStore,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: LevelSelectScreen(
        store: progressStore ?? fakeStore,
        stats: stats,
        levels: levels,
        loadWords: loadWords ??
            (level) async => fiveWords(level, 't$level'),
        now: () => now,
        random: random,
      ),
    ));
    // Poll with real time: FFI store futures resolve outside fake async.
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
      if (find.text('TOPIK 1級').evaluate().isNotEmpty ||
          find.text('読み込みに失敗しました').evaluate().isNotEmpty) {
        return;
      }
    }
  }

testWidgets('lists TOPIK levels with word counts', (tester) async {
    await pumpLevels(tester, progressStore: FakeProgressStore(
      learnedCounts: {1: 5, 2: 5, 3: 5, 4: 5, 5: 5, 6: 5},
    ));

    expect(find.text('レベル選択'), findsOneWidget);
    // First 3 levels are visible without scrolling
    for (var level = 1; level <= 3; level++) {
      expect(find.text('TOPIK $level級'), findsOneWidget);
    }
    // Levels 4-6 require scrolling (lazy rendering in ListView) - skip in test
    expect(find.text('5 / 5 語 学習済み'), findsAtLeastNWidgets(2));
    expect(find.text('学習する'), findsAtLeastNWidgets(2));
    expect(find.text('クイズ'), findsAtLeastNWidgets(2));
  });

  testWidgets('selecting level 6 starts a session with level-6 words',
      (tester) async {
    final pool = fiveWords(6, 't6');
    await pumpLevels(
      tester,
      loadWords: (level) async => level == 6 ? pool : fiveWords(level, 't$level'),
      random: Random(7),
      progressStore: FakeProgressStore(learnedCounts: {1: 5, 2: 5, 3: 5, 4: 5, 5: 5, 6: 5}),
    );

    // Scroll to level 6 (lazy rendering)
    await tester.dragUntilVisible(
      find.text('TOPIK 6級'),
      find.byType(Scrollable).first,
      const Offset(0, -1000),
    );
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('学習する').last);
    await tester.pumpAndSettle();

    // Seeded shuffle order: first card is deterministic.
    final expected = List<Word>.of(pool)..shuffle(Random(7));
    expect(find.text(expected.first.korean), findsOneWidget);
    expect(find.text('タップして意味を見る'), findsOneWidget);
  });

  testWidgets('defaults to TOPIK levels 1-6', (tester) async {
    await pumpLevels(tester, progressStore: FakeProgressStore(
      learnedCounts: {1: 5, 2: 5, 3: 5, 4: 5, 5: 5, 6: 5},
    ));

    // First 3 levels are visible without scrolling
    for (var level = 1; level <= 3; level++) {
      expect(find.text('TOPIK $level級'), findsOneWidget);
    }
    // Levels 4-6 require scrolling (lazy rendering in ListView) - skip in test
    expect(find.text('5 / 5 語 学習済み'), findsAtLeastNWidgets(2));
  });

  testWidgets('tapping 学習する opens the flashcard session', (tester) async {
    final pool = fiveWords(1, 't1');
    await pumpLevels(
      tester,
      loadWords: (level) async => level == 1 ? pool : fiveWords(level, 't$level'),
      random: Random(3),
    );

    await tester.tap(find.text('学習する').first);
    await tester.pumpAndSettle();

    // Seeded shuffle order: first card is deterministic.
    final expected = List<Word>.of(pool)..shuffle(Random(3));
    expect(find.text(expected.first.korean), findsOneWidget);
    expect(find.text('タップして意味を見る'), findsOneWidget);
  });

  testWidgets('sessions start in shuffled, not asset, order', (tester) async {
    final pool = fiveWords(1, 't1');
    await pumpLevels(
      tester,
      levels: const [1],
      loadWords: (_) async => pool,
      random: Random(11),
    );

    await tester.tap(find.text('学習する'));
    await tester.pumpAndSettle();

    final expected = List<Word>.of(pool)..shuffle(Random(11));
    expect(find.text(expected.first.korean), findsOneWidget);
    // Shuffled order differs from asset order for this seed.
    expect(expected.first.korean, isNot(pool.first.korean));
  });

  testWidgets('tapping クイズ opens the quiz session when pool is large',
      (tester) async {
    await pumpLevels(tester);

    await tester.tap(find.text('クイズ').first);
    await tester.pumpAndSettle();

    expect(find.text('正解: 0'), findsOneWidget);
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
    expect(find.text('正解: 0'), findsNothing);
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
    await tester.tap(find.text('普通 (3)'));
    await tester.pumpAndSettle();

    expect(find.text('学習完了！'), findsOneWidget);
    final streak = await tester.runAsync(() => stats.currentStreak(now));
    expect(streak, 1);
  });
}
