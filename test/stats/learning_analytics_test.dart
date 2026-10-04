import 'package:flutter_test/flutter_test.dart';

import 'package:korean_game/i18n/app_locale.dart';
import 'package:korean_game/quiz/quiz_generator.dart';
import 'package:korean_game/stats/learning_analytics.dart';

QuizQuestion q(QuizKind kind, String prompt) => QuizQuestion(
      prompt: prompt,
      options: const ['a', 'b', 'c', 'd'],
      correctIndex: 0,
      kind: kind,
    );

void main() {
  test('computes per-kind accuracy and weak kinds', () {
    final questions = [
      q(QuizKind.meaningToWord, 'p1'),
      q(QuizKind.meaningToWord, 'p2'),
      q(QuizKind.listeningWord, 'p3'),
    ];
    final analysis = analyzeSession(
      questions: questions,
      correct: const [true, false, false],
    );
    expect(analysis.total, 3);
    expect(analysis.correct, 1);
    expect(analysis.weakKinds, contains(QuizKind.listeningWord));
    expect(analysis.suggestions, isNotEmpty);
  });

  test('empty session yields zero rate', () {
    const analysis = SessionAnalysis(
      total: 0,
      correct: 0,
      byKind: [],
      weakKinds: [],
      suggestions: [],
    );
    expect(analysis.rate, 0.0);
  });

  test('last7WeekdayLabels matches calendar (Oct 4 2026 is Sunday)', () {
    expect(
      last7WeekdayLabels(DateTime(2026, 10, 4)),
      ['月', '火', '水', '木', '金', '土', '日'],
    );
  });

  test('last7WeekdayLabels localizes weekday names', () {
    expect(
      last7WeekdayLabels(DateTime(2026, 10, 4), AppLocale.korean),
      ['월', '화', '수', '목', '금', '토', '일'],
    );
    expect(
      last7WeekdayLabels(DateTime(2026, 10, 4), AppLocale.english),
      ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
    );
  });
}
