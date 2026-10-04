import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:korean_game/i18n/app_locale.dart';
import 'package:korean_game/models/word.dart';
import 'package:korean_game/screens/mini_game_screen.dart';

Word word(String id, String korean, String meaning) => Word(
      id: id,
      korean: korean,
      reading: 'r-$id',
      meaningJa: meaning,
      exampleKo: '$korean 예문',
      exampleJa: '例文',
      topikLevel: 1,
    );

void main() {
  Future<void> pumpUntilRendered(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      if (find.textContaining('スコア').evaluate().isNotEmpty) return;
    }
  }

  final words = [
    word('1', '사랑', '愛'),
    word('2', '학교', '学校'),
    word('3', '친구', '友達'),
    word('4', '음식', '食べ物'),
  ];

  testWidgets('matching a pair scores 100 and clears it', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MiniGameScreen(
        words: words,
        locale: AppLocale.japanese,
        pairs: 4,
      ),
    ));
    await tester.pump();
    await pumpUntilRendered(tester);

    expect(find.text('スコア: 0'), findsOneWidget);

    await tester.tap(find.text('사랑'));
    await tester.pump();
    await tester.tap(find.text('愛'));
    await tester.pump();

    expect(find.text('スコア: 100'), findsOneWidget);
    expect(find.text('ミス: 0'), findsOneWidget);
  });

  testWidgets('wrong pair counts a mistake and adds no score', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MiniGameScreen(
        words: words.take(2).toList(),
        locale: AppLocale.japanese,
        pairs: 2,
      ),
    ));
    await tester.pump();
    await pumpUntilRendered(tester);

    await tester.tap(find.text('사랑'));
    await tester.pump();
    await tester.tap(find.text('学校'));
    await tester.pump();

    expect(find.text('ミス: 1'), findsOneWidget);
    expect(find.text('スコア: 0'), findsOneWidget);
  });

  testWidgets('clearing all pairs shows clear message', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MiniGameScreen(
        words: words.take(2).toList(),
        locale: AppLocale.japanese,
        pairs: 2,
      ),
    ));
    await tester.pump();
    await pumpUntilRendered(tester);

    String? meaningOf(String korean) {
      for (final w in words) {
        if (w.korean == korean) return w.meaningJa;
      }
      return null;
    }

    // Only two pairs are used; whichever Korean words appear, match them.
    for (final korean in ['사랑', '학교', '친구', '음식']) {
      if (find.text(korean).evaluate().isEmpty) continue;
      await tester.tap(find.text(korean));
      await tester.pump();
      final meaning = meaningOf(korean)!;
      if (find.text(meaning).evaluate().isEmpty) continue;
      await tester.tap(find.text(meaning));
      await tester.pump();
    }

    expect(find.textContaining('クリア！'), findsOneWidget);
  });

  testWidgets('empty source shows empty message', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MiniGameScreen(
        words: const [],
        locale: AppLocale.japanese,
        loadWords: (_) async => [],
        level: 1,
        pairs: 4,
      ),
    ));
    await tester.pump();
    await pumpUntilRendered(tester);

    expect(find.text('遊べる単語がありません'), findsOneWidget);
  });
}
