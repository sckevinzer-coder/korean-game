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
    this.wordId,
  });

  final String prompt;
  final List<String> options;
  final int correctIndex;
  final QuizKind kind;
  final String? audioText;
  final String? wordId;

  String get correctAnswer => options[correctIndex];
}

/// Picks 3 distractor answers, preferring error-prone words first.
///
/// [weakRates] maps Word.id to an error rate in 0.0..1.0. When provided,
/// candidates with higher rates are taken first; ties keep shuffled order.
/// Null preserves the legacy purely-random behavior.
List<String> pickDistractors({
  required Word target,
  required List<Word> pool,
  required String Function(Word) answerOf,
  required String correct,
  required Random rng,
  Map<String, double>? weakRates,
}) {
  final shuffled = pool.where((w) => w.id != target.id).toList()
    ..shuffle(rng);
  final seen = <String>{};
  final candidates = <({String answer, double rate})>[];
  for (final w in shuffled) {
    final answer = answerOf(w);
    if (answer == correct || !seen.add(answer)) continue;
    candidates.add((answer: answer, rate: weakRates?[w.id] ?? 0.0));
  }
  if (candidates.length < 3) {
    throw ArgumentError(
      'Not enough distinct distractors in pool '
      '(need 3, found ${candidates.length})',
    );
  }
  if (weakRates != null) {
    candidates.sort((a, b) => b.rate.compareTo(a.rate));
  }
  return [for (final c in candidates.take(3)) c.answer];
}

QuizQuestion makeQuestion(
  Word target,
  List<Word> pool,
  QuizKind kind,
  Random rng, {
  Map<String, double>? weakRates,
}) {
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

  final distractors = pickDistractors(
    target: target,
    pool: pool,
    answerOf: answerOf,
    correct: correct,
    rng: rng,
    weakRates: weakRates,
  );

  final options = <String>[correct, ...distractors]..shuffle(rng);
  return QuizQuestion(
    prompt: prompt,
    options: options,
    correctIndex: options.indexOf(correct),
    kind: kind,
    audioText: audioText,
    wordId: target.id,
  );
}

QuizQuestion? makeBlankQuestion(
  Word target,
  List<Word> pool,
  Random rng, {
  Map<String, double>? weakRates,
}) {
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

  final distractors = pickDistractors(
    target: target,
    pool: pool,
    answerOf: answerOf,
    correct: correct,
    rng: rng,
    weakRates: weakRates,
  );

  final options = <String>[correct, ...distractors]..shuffle(rng);
  return QuizQuestion(
    prompt: prompt,
    options: options,
    correctIndex: options.indexOf(correct),
    kind: QuizKind.blank,
    audioText: null,
    wordId: target.id,
  );
}
