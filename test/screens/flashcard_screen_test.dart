import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:korean_game/db/progress_store.dart';
import 'package:korean_game/models/word.dart';
import 'package:korean_game/screens/flashcard_screen.dart';

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

  final DateTime now = DateTime(2026, 10, 3, 12);

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    store = ProgressStore(path: inMemoryDatabasePath);
    // Warm up the FFI database outside the widget test zone.
    await store.allCardsForLevel(1);
  });

  tearDown(() async {
    await store.close();
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

    expect(find.text('韓国語'), findsOneWidget);
    expect(find.text('普通'), findsOneWidget);

    // Grade the first card; persists via ProgressStore and advances.
    await tester.tap(find.text('普通'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
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

    await tester.tap(find.text('簡単'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();

    expect(find.text('学習完了！'), findsOneWidget);

    final all = await tester.runAsync(() => store.allCardsForLevel(1)) ?? const [];
    expect(all.map((c) => c.wordId).toSet(), {'t1-001', 't1-002'});
  });

  testWidgets('empty word list shows empty message', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: FlashcardScreen(store: store, words: const [], now: () => now),
    ));
    await tester.pump();

    expect(find.text('学習する単語がありません'), findsOneWidget);
  });
}
