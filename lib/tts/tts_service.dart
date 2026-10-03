export 'tts_service_stub.dart'
    if (dart.library.js_interop) 'tts_service_web.dart';

/// Platform-agnostic text-to-speech interface.
abstract class TtsService {
  Future<void> speak(String text);
  Future<void> stop();
}

/// Does nothing; useful for tests and silent mode.
class NoopTtsService implements TtsService {
  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}
}
