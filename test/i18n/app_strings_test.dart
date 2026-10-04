import 'package:flutter_test/flutter_test.dart';

import 'package:korean_game/i18n/app_locale.dart';
import 'package:korean_game/i18n/app_strings.dart';

void main() {
  group('AppLocale.parse', () {
    test('parses known codes', () {
      expect(AppLocale.parse('ja'), AppLocale.japanese);
      expect(AppLocale.parse('ko'), AppLocale.korean);
      expect(AppLocale.parse('en'), AppLocale.english);
    });

    test('unknown and null fall back to japanese', () {
      expect(AppLocale.parse('fr'), AppLocale.japanese);
      expect(AppLocale.parse(null), AppLocale.japanese);
    });
  });

  group('tr', () {
    test('japanese returns japanese text', () {
      expect(tr(AppLocale.japanese, 'app.home'), 'ホーム');
    });

    test('korean/english return their translations', () {
      expect(tr(AppLocale.korean, 'app.home'), '홈');
      expect(tr(AppLocale.english, 'app.home'), 'Home');
    });

    test('unknown key returns the key', () {
      expect(tr(AppLocale.japanese, 'no.such.key'), 'no.such.key');
    });

    test('params substitute into translated text', () {
      expect(
        trParams(AppLocale.korean, 'home.streak', {'n': 3}),
        '연속 학습: 3일',
      );
      expect(
        trParams(AppLocale.english, 'home.streak', {'n': 3}),
        '3-day streak',
      );
    });
  });

  group('trParams', () {
    test('substitutes placeholders', () {
      expect(
        trParams(AppLocale.japanese, 'app.home', {'n': 5}),
        'ホーム',
      );
    });
  });
}
