import 'dart:math';

import '../models/word.dart';

enum QuizKind { meaningToWord, wordToMeaning }

class QuizQuestion {
  const QuizQuestion({
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.kind,
  });

  final String prompt;
  final List<String> options;
  final int correctIndex;
  final QuizKind kind;

  String get correctAnswer => options[correctIndex];
}

QuizQuestion makeQuestion(
  Word target,
  List<Word> pool,
  QuizKind kind,
  Random rng,
) {
  final String prompt;
  final String correct;
  final String Function(Word) answerOf;
  switch (kind) {
    case QuizKind.meaningToWord:
      prompt = target.meaningJa;
      correct = target.korean;
      answerOf = (w) => w.korean;
    case QuizKind.wordToMeaning:
      prompt = target.korean;
      correct = target.meaningJa;
      answerOf = (w) => w.meaningJa;
  }

  final distractors = pool
      .where((w) => w.id != target.id)
      .map(answerOf)
      .where((a) => a != correct)
      .toSet()
      .toList()
    ..shuffle(rng);
  if (distractors.length < 3) {
    throw ArgumentError(
      'Not enough distinct distractors in pool '
      '(need 3, found ${distractors.length})',
    );
  }

  final options = <String>[correct, ...distractors.take(3)]..shuffle(rng);
  return QuizQuestion(
    prompt: prompt,
    options: options,
    correctIndex: options.indexOf(correct),
    kind: kind,
  );
}
