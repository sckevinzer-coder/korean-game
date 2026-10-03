export 'tts_service_stub.dart'
    if (dart.library.js_interop) 'tts_service_web.dart';

/// Platform-agnostic text-to-speech interface.
abstract class TtsService {
  /// Speaks the given [text] with optional [rate] (0.0-2.0), [pitch] (0.0-2.0), and [volume] (0.0-1.0).
  Future<void> speak(String text, {double rate = 1.0, double pitch = 1.0, double volume = 1.0});

  /// Stops any ongoing speech.
  Future<void> stop();
}

/// Does nothing; useful for tests and silent mode.
class NoopTtsService implements TtsService {
  @override
  Future<void> speak(String text, {double rate = 1.0, double pitch = 1.0, double volume = 1.0}) async {}

  @override
  Future<void> stop() async {}
}
