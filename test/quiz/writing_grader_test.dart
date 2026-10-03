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
}