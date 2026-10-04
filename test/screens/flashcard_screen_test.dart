import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:korean_game/db/progress_store.dart';
import 'package:korean_game/models/word.dart';
import 'package:korean_game/screens/flashcard_screen.dart';
import 'package:korean_game/stats/bookmark_store.dart';
import 'package:korean_game/stats/stats_store.dart';

Word word(String id, String korean, String meaningJa) => Word(
      id: id,
      korean: korean,
      reading: 'reading-$id',
      meaningJa: meaningJa,
      exampleKo: '예문-$id',
      exampleJa: '例文-$id',
      topikLevel: 1,
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
    tmpDir = await Directory.systemTemp.createTemp('korean_game_flash');
    store = ProgressStore(path: p.join(tmpDir.path, 'progress.db'));
    stats = StatsStore(path: p.join(tmpDir.path, 'stats.db'));
    // Warm up the FFI databases outside the widget test zone.
    await store.allCardsForLevel(1);
    await stats.currentStreak(now);
  });

  tearDown(() async {
    await store.close();
    await stats.close();
    await tmpDir.delete(recursive: true);
  });

  testWidgets('tap card flips to reveal meaning; grading persists and advances',
      (tester) async {
    final words = [
      word('t1-001', '한국어', '韓国語'),
      word('t1-002', '사랑', '愛'),
    ];

    await tester.pumpWidget(MaterialApp(
      home: FlashcardScreen(
        store: store,
        words: words,
        now: () => now,
        level: 1,
      ),
    ));
    await tester.pump();

    // Front shows Korean, meaning hidden.
    expect(find.text('한국어'), findsOneWidget);
    expect(find.text('韓国語'), findsNothing);
    expect(find.text('普通'), findsNothing);

    // Tap card flips to reveal meaning and grade buttons.
    await tester.tap(find.text('한국어'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('韓国語'), findsOneWidget);
    expect(find.text('普通 (3)'), findsOneWidget);

    // Grade the first card; persists via ProgressStore and advances.
    await tester.tap(find.text('普通 (3)'));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pump();

    expect(find.text('사랑'), findsOneWidget);
    expect(find.text('愛'), findsNothing);

    final saved =
        await tester.runAsync(() => store.allCardsForLevel(1)) ?? const [];
    expect(saved.map((c) => c.wordId), contains('t1-001'));
    expect(saved.firstWhere((c) => c.wordId == 't1-001').dueDate.isAfter(now),
        isTrue);

    // Second card: flip and grade to finish the session.
    await tester.tap(find.text('사랑'));
    await tester.pump();
    expect(find.text('愛'), findsOneWidget);

    await tester.tap(find.text('簡単 (4)'));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pump();

    expect(find.text('学習完了！'), findsOneWidget);

    final all = await tester.runAsync(() => store.allCardsForLevel(1)) ?? const [];
    expect(all.map((c) => c.wordId).toSet(), {'t1-001', 't1-002'});
  });

  testWidgets('empty word list shows empty message', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: FlashcardScreen(store: store, words: const [], now: () => now, level: 1),
    ));
    await tester.pump();

    expect(find.text('学習する単語がありません'), findsOneWidget);
  });

  testWidgets('completing a session records study day', (tester) async {
    final words = [
      word('t1-001', '한국어', '韓国語'),
    ];

    await tester.pumpWidget(MaterialApp(
      home: FlashcardScreen(
        store: store,
        words: words,
        stats: stats,
        now: () => now,
        level: 1,
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('한국어'));
    await tester.pump();
    await tester.tap(find.text('普通 (3)'));
    await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 500)));
    await tester.pump();

    expect(find.text('学習完了！'), findsOneWidget);
    final streak = await tester.runAsync(() => stats.currentStreak(now));
    expect(streak, 1);
  });

  testWidgets('bookmark toggle saves and removes the word', (tester) async {
    final bookmarks =
        BookmarkStore(path: p.join(tmpDir.path, 'bookmarks.db'));
    final words = [word('t1-001', '한국어', '韓国語')];
    addTearDown(bookmarks.close);

    await tester.pumpWidget(MaterialApp(
      home: FlashcardScreen(
        store: store,
        words: words,
        bookmarks: bookmarks,
        now: () => now,
        level: 1,
      ),
    ));
    Future<void> settle() async {
      for (var i = 0; i < 3; i++) {
        await tester.pump();
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 300)));
      }
      await tester.pump();
    }

    await settle();

    expect(find.byTooltip('ブックマーク'), findsOneWidget);
    await tester.tap(find.byTooltip('ブックマーク'));
    await settle();
    expect(await tester.runAsync(() => bookmarks.contains('t1-001')), isTrue);

    await tester.tap(find.byTooltip('ブックマーク'));
    await settle();
    expect(await tester.runAsync(() => bookmarks.contains('t1-001')), isFalse);
  });
}
