import 'dart:math';

import '../models/word.dart';

enum QuizKind { meaningToWord, wordToMeaning, listeningWord, listeningMeaning, blank, writing }

class QuizQuestion {
  const QuizQuestion({
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.kind,
    this.audioText,
  });

  final String prompt;
  final List<String> options;
  final int correctIndex;
  final QuizKind kind;
  final String? audioText;

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
  final String? audioText;
  switch (kind) {
    case QuizKind.meaningToWord:
      prompt = target.meaningJa;
      correct = target.korean;
      answerOf = (w) => w.korean;
      audioText = null;
    case QuizKind.wordToMeaning:
      prompt = target.korean;
      correct = target.meaningJa;
      answerOf = (w) => w.meaningJa;
      audioText = null;
    case QuizKind.listeningWord:
      prompt = '듣기: 적절한 단어를 선택하세요';
      correct = target.korean;
      answerOf = (w) => w.korean;
      audioText = target.korean;
    case QuizKind.listeningMeaning:
      prompt = '듣기: 적절한 의미를 선택하세요';
      correct = target.meaningJa;
      answerOf = (w) => w.meaningJa;
      audioText = target.korean;
    case QuizKind.blank:
      throw ArgumentError('Use makeBlankQuestion for blank kind');
    case QuizKind.writing:
      throw ArgumentError('Writing kind handled separately in QuizScreen');
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
    audioText: audioText,
  );
}

QuizQuestion? makeBlankQuestion(
  Word target,
  List<Word> pool,
  Random rng,
) {
  String searchWord = target.korean;
  String example = target.exampleKo;
  int index = example.indexOf(searchWord);

  if (index == -1 && target.korean.endsWith('다')) {
    searchWord = target.korean.substring(0, target.korean.length - 1);
    index = example.indexOf(searchWord);
  }

  if (index == -1) {
    return null;
  }

  final prompt = example.replaceFirst(searchWord, '＿＿');
  final correct = target.korean;
  String answerOf(Word w) => w.korean;

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
    kind: QuizKind.blank,
    audioText: null,
  );
}
