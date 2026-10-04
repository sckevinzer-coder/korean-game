import 'package:flutter_test/flutter_test.dart';

import 'package:korean_game/quiz/writing_grader.dart';

void main() {
  group('gradeWriting', () {
    test('exact match returns true', () {
      expect(gradeWriting('먹다', '먹다'), isTrue);
    });

    test('surrounding whitespace ignored', () {
      expect(gradeWriting(' 먹다 ', '먹다'), isTrue);
    });

    test('inner whitespace ignored', () {
      expect(gradeWriting('먹 다', '먹다'), isTrue);
    });

    test('period ignored', () {
      expect(gradeWriting('먹다.', '먹다'), isTrue);
      expect(gradeWriting('먹다。', '먹다'), isTrue);
    });

    test('particle-insensitive by default', () {
      expect(gradeWriting('먹다를', '먹다'), isTrue);
      expect(gradeWriting('먹다을', '먹다'), isTrue);
      expect(gradeWriting('먹다에', '먹다'), isTrue);
    });

    test('particle-sensitive when ignoreParticles is false', () {
      expect(gradeWriting('먹다를', '먹다', ignoreParticles: false), isFalse);
      expect(gradeWriting('먹다을', '먹다', ignoreParticles: false), isFalse);
    });

    test('wrong word returns false', () {
      expect(gradeWriting('마시다', '먹다'), isFalse);
    });

    test('empty input returns false', () {
      expect(gradeWriting('', '먹다'), isFalse);
      expect(gradeWriting('   ', '먹다'), isFalse);
    });
  });

  group('WritingGrader.analyze', () {
    test('correct input yields full score and feedback', () {
      final r = WritingGrader.analyze('먹다', '먹다');
      expect(r.isCorrect, isTrue);
      expect(r.similarityScore, 1.0);
      expect(r.errorType, WritingErrorType.correct);
    });

    test('missing characters detected with similarity below 1', () {
      final r = WritingGrader.analyze('먹', '먹다');
      expect(r.isCorrect, isFalse);
      expect(r.errorType, WritingErrorType.missingCharacter);
      expect(r.similarityScore, lessThan(1.0));
      expect(WritingGrader.getPartialGrade(r), lessThan(1.0));
    });
  });

  group('Level 5 partial credit', () {
    test('near-miss earns bonus below full credit', () {
      final r = WritingGrader.analyze('사랑하요', '사랑해요');
      expect(r.isCorrect, isFalse);
      expect(WritingGrader.isNearMiss(r), isTrue);
      final bonus = WritingGrader.bonusFor(r);
      expect(bonus, greaterThan(0.0));
      expect(bonus, lessThan(0.5));
    });

    test('far miss earns no bonus', () {
      final r = WritingGrader.analyze('학교', '사랑해요');
      expect(r.isCorrect, isFalse);
      expect(WritingGrader.isNearMiss(r), isFalse);
      expect(WritingGrader.bonusFor(r), 0.0);
    });

    test('similarity label shows percent', () {
      expect(WritingGrader.similarityLabel(0.85), '類似度 85%');
    });
  });
}