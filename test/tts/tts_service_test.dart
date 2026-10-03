import 'package:flutter_test/flutter_test.dart';
import 'package:korean_game/tts/tts_service.dart';

void main() {
  test('noop completes without doing anything', () async {
    await NoopTtsService().speak('안녕');
  });
  test('factory returns a service', () {
    expect(createTtsService(), isA<TtsService>());
  });
}
