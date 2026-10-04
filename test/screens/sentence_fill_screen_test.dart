import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:korean_game/i18n/app_locale.dart';
import 'package:korean_game/models/word.dart';
import 'package:korean_game/screens/sentence_fill_screen.dart';

Word word(String id, String korean) => Word(
      id: id,
      korean: korean,
      reading: 'r-$id',
      meaningJa: 'm-$id',
      exampleKo: '이것은 $korean 입니다',
      exampleJa: '예문',
      topikLevel: 1,
    );

void main() {
  final words = [
    word('1', '사랑'),
    word('2', '학교'),
    word('3', '친구'),
    word('4', '음식'),
  ];

  Future<void> pumpUntilReady(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      if (find
          .textContaining('スコア')
          .evaluate()
          .isNotEmpty ||
          find
              .text('遊べる問題がありません')
              .evaluate()
              .isNotEmpty ||
          find.textContaining('クリア！').evaluate().isNotEmpty) {
        return;
      }
    }
  }

  testWidgets('shows a blanked sentence and options', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SentenceFillScreen(
        words: words,
        locale: AppLocale.japanese,
        rounds: 3,
        rng: Random(1),
      ),
    ));
    await tester.pump();
    await pumpUntilReady(tester);

    expect(find.textContaining('＿＿'), findsOneWidget);
    expect(find.textContaining('問題 1 /'), findsOneWidget);
  });

  testWidgets('answering and advancing progresses the game', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SentenceFillScreen(
        words: words,
        locale: AppLocale.japanese,
        rounds: 2,
        rng: Random(1),
      ),
    ));
    await tester.pump();
    await pumpUntilReady(tester);

    // Tap an option (whatever it is), then Next.
    await tester.tap(find.byType(ElevatedButton).first);
    await tester.pump();
    await tester.tap(find.text('次へ'));
    await tester.pump();

    expect(find.textContaining('問題 2 /'), findsOneWidget);
  });

  testWidgets('empty word source shows empty message', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SentenceFillScreen(
        words: const [],
        locale: AppLocale.japanese,
        rounds: 3,
        loadWords: (_) async => [],
      ),
    ));
    await tester.pump();
    await pumpUntilReady(tester);

    expect(find.text('遊べる問題がありません'), findsOneWidget);
  });
}
