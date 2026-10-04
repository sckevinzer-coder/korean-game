import 'package:flutter_test/flutter_test.dart';

import 'package:korean_game/models/word.dart';
import 'package:korean_game/quiz/adaptive_selector.dart';

Word word(String id, String korean) => Word(
      id: id,
      korean: korean,
      reading: 'reading-$id',
      meaningJa: '意味-$id',
      exampleKo: '예문-$id',
      exampleJa: '例文-$id',
      topikLevel: 1,
    );

void main() {
  group('prioritizeWeakWords', () {
    test('orders by error rate, stable on ties', () {
      final words = [word('t1-001', 'a'), word('t1-002', 'b'), word('t1-003', 'c')];
      final ordered = prioritizeWeakWords(
        words: words,
        errorRate: {'t1-002': 0.8, 't1-003': 0.2},
      );
      expect(ordered.map((w) => w.id), ['t1-002', 't1-003', 't1-001']);
    });

    test('limit trims the list', () {
      final words = [word('t1-001', 'a'), word('t1-002', 'b')];
      final ordered = prioritizeWeakWords(
        words: words,
        errorRate: {'t1-002': 1.0},
        limit: 1,
      );
      expect(ordered.map((w) => w.id), ['t1-002']);
    });
  });

  group('ratesForWords', () {
    test('maps kind:answer keys to word ids', () {
      final words = [word('t1-001', '사랑해요'), word('t1-002', '학교')];
      final rates = ratesForWords(
        words: words,
        weakRates: const [(key: 'writing:사랑해요', rate: 1.0)],
      );
      expect(rates, {'t1-001': 1.0});
    });
  });

  group('errorRateFor', () {
    test('zero attempts yields zero', () {
      expect(errorRateFor(attempts: 0, errors: 0), 0.0);
    });

    test('computes clamped rate', () {
      expect(errorRateFor(attempts: 4, errors: 1), 0.25);
    });
  });
}
