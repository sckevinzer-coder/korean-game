import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:korean_game/models/word.dart';
import 'package:korean_game/screens/review_screen.dart';
import 'package:korean_game/stats/error_stats.dart';

class FakeErrorStats extends ErrorStatsStore {
  FakeErrorStats(this.items);
  final List<WeakItem> items;
  @override
  Future<List<WeakItem>> topWeak({int limit = 5}) async =>
      items.take(limit).toList();
}

Word word(String id, String korean, String meaningJa) => Word(
      id: id,
      korean: korean,
      reading: 'reading-$id',
      meaningJa: meaningJa,
      exampleKo: '$korean 예문입니다',
      exampleJa: '例文',
      topikLevel: 1,
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('review notebook shows words with examples and miss counts',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ReviewScreen(
        errors: FakeErrorStats(const [
          WeakItem(
              key: 'meaningToWord:사랑', attempts: 5, errors: 3, lastError: ''),
          WeakItem(
              key: 'wordToMeaning:学校', attempts: 4, errors: 2, lastError: ''),
        ]),
        levels: const [1],
        loadWords: (level) async => [
          word('t1-001', '사랑', '愛'),
          word('t1-002', '학교', '学校'),
        ],
      ),
    ));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('間違いノート'), findsOneWidget);
    expect(find.text('사랑'), findsOneWidget);
    expect(find.text('사랑 예문입니다'), findsOneWidget);
    expect(find.textContaining('ミス 3/5'), findsOneWidget);
    expect(find.textContaining('ミス 2/4'), findsOneWidget);
  });

  testWidgets('empty error history shows guidance', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ReviewScreen(
        errors: FakeErrorStats(const []),
        levels: const [1],
        loadWords: (level) async => [],
      ),
    ));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('間違い記録はまだありません'), findsOneWidget);
  });
}
