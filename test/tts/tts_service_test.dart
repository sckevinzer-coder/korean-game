import 'package:flutter_test/flutter_test.dart';
import 'package:korean_game/tts/tts_service.dart';

void main() {
  test('noop completes without doing anything', () async {
    await NoopTtsService().speak('안녕');
    await NoopTtsService().speak('안녕', rate: 1.5, pitch: 1.2, volume: 0.8);
  });

  test('factory returns a service', () {
    expect(createTtsService(), isA<TtsService>());
  });
}
