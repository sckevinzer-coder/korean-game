import 'package:flutter_test/flutter_test.dart';

import 'package:korean_game/data/word_repository.dart';
import 'package:korean_game/models/word.dart';

void main() {
  test('parses a JSON entry into Word with all fields', () {
    final word = Word.fromJson({
      'id': 't1-001',
      'korean': '안녕하세요',
      'reading': 'annyeonghaseyo',
      'meaningJa': 'こんにちは',
      'exampleKo': '안녕하세요, 저는 민수입니다.',
      'exampleJa': 'こんにちは、私はミンスです。',
      'topikLevel': 1,
    });

    expect(word.id, 't1-001');
    expect(word.korean, '안녕하세요');
    expect(word.reading, 'annyeonghaseyo');
    expect(word.meaningJa, 'こんにちは');
    expect(word.exampleKo, '안녕하세요, 저는 민수입니다.');
    expect(word.exampleJa, 'こんにちは、私はミンスです。');
    expect(word.topikLevel, 1);
  });

  test('throws FormatException on missing field', () {
    expect(
      () => Word.fromJson({
        'id': 't1-001',
        'korean': '안녕하세요',
        'reading': 'annyeonghaseyo',
        'meaningJa': 'こんにちは',
        'exampleKo': '안녕하세요, 저는 민수입니다.',
        'exampleJa': 'こんにちは、私はミンスです。',
      }),
      throwsFormatException,
    );
  });

  test('loadWordsForLevel(1) returns only level-1 words', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final words = await loadWordsForLevel(1);
    expect(words, isNotEmpty);
    expect(words.every((w) => w.topikLevel == 1), isTrue);
  });

  test('loadWordsForLevel(2) returns only level-2 words', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final words = await loadWordsForLevel(2);
    expect(words, isNotEmpty);
    expect(words.every((w) => w.topikLevel == 2), isTrue);
  });
}
