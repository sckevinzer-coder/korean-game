import 'package:flutter_test/flutter_test.dart';

import '../../tool/validate_words.dart';

void main() {
  test('word bank validation passes', () {
    expect(validateAllLevels(), isEmpty);
  });
}
