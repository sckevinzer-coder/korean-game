import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:korean_game/models/word.dart';
import 'package:korean_game/quiz/quiz_generator.dart';
import 'package:korean_game/screens/quiz_screen.dart';

Word word(String id, String korean, String meaningJa) => Word(
      id: id,
      korean: korean,
      reading: 'reading-$id',
      meaningJa: meaningJa,
      exampleKo: '예문-$id',
      exampleJa: '例文-$id',
      topikLevel: 1,
    );

List<Word> pool() => [
      word('t1-001', '한국어', '韓国語'),
      word('t1-002', '사랑', '愛'),
      word('t1-003', '학교', '学校'),
      word('t1-004', '친구', '友達'),
      word('t1-005', '음식', '食べ物'),
    ];

void main() {
  group('makeQuestion', () {
    test('exactly 4 distinct options, one correct, distractors from pool',
        () {
      final words = pool();
      final target = words.first;
      final question =
          makeQuestion(target, words, QuizKind.wordToMeaning, Random(42));

      expect(question.options, hasLength(4));
      expect(question.options.toSet(), hasLength(4));
      expect(question.options[question.correctIndex], target.meaningJa);
      expect(
        question.options.where((o) => o == target.meaningJa),
        hasLength(1),
      );
      final poolMeanings = words.map((w) => w.meaningJa).toSet();
      for (final option in question.options) {
        expect(poolMeanings, contains(option));
      }
    });

    test('meaningToWord asks meaning, answers with Korean', () {
      final words = pool();
      final target = words[1];
      final question =
          makeQuestion(target, words, QuizKind.meaningToWord, Random(7));

      expect(question.kind, QuizKind.meaningToWord);
      expect(question.prompt, target.meaningJa);
      expect(question.options[question.correctIndex], target.korean);
      expect(question.options, hasLength(4));
      expect(question.options.toSet(), hasLength(4));
      final poolKoreans = words.map((w) => w.korean).toSet();
      for (final option in question.options) {
        expect(poolKoreans, contains(option));
      }
    });

    test('wordToMeaning asks Korean, answers with meaning', () {
      final words = pool();
      final target = words[2];
      final question =
          makeQuestion(target, words, QuizKind.wordToMeaning, Random(7));

      expect(question.kind, QuizKind.wordToMeaning);
      expect(question.prompt, target.korean);
      expect(question.options[question.correctIndex], target.meaningJa);
    });

    test('throws when pool is too small for 4 distinct options', () {
      final words = [word('t1-001', '한국어', '韓国語')];
      expect(
        () => makeQuestion(words.first, words, QuizKind.wordToMeaning, Random()),
        throwsArgumentError,
      );
    });
  });

  group('QuizScreen', () {
    testWidgets('answering updates score', (tester) async {
      const questions = [
        QuizQuestion(
          prompt: '愛',
          options: ['사랑', '학교', '친구', '음식'],
          correctIndex: 0,
          kind: QuizKind.meaningToWord,
        ),
        QuizQuestion(
          prompt: '학교',
          options: ['学校', '韓国語', '友達', '食べ物'],
          correctIndex: 0,
          kind: QuizKind.wordToMeaning,
        ),
      ];

      await tester.pumpWidget(MaterialApp(
        home: QuizScreen(words: pool(), questions: questions),
      ));
      await tester.pump();

      expect(find.text('スコア: 0'), findsOneWidget);
      expect(find.text('愛'), findsOneWidget);

      // Correct answer on question 1.
      await tester.tap(find.text('사랑'));
      await tester.pump();
      expect(find.text('正解！'), findsOneWidget);
      expect(find.text('スコア: 1'), findsOneWidget);

      await tester.tap(find.text('次へ'));
      await tester.pump();
      expect(find.text('愛'), findsNothing);
      expect(find.text('학교'), findsOneWidget);

      // Wrong answer on question 2: score stays.
      await tester.tap(find.text('韓国語'));
      await tester.pump();
      expect(find.text('不正解…'), findsOneWidget);
      expect(find.text('スコア: 1'), findsOneWidget);

      await tester.tap(find.text('結果を見る'));
      await tester.pump();
      expect(find.text('クイズ完了！'), findsOneWidget);
      expect(find.text('スコア: 1 / 2'), findsOneWidget);
    });

    testWidgets('empty word list shows empty message', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: QuizScreen(words: []),
      ));
      await tester.pump();

      expect(find.text('クイズにする単語がありません'), findsOneWidget);
    });
  });
}
