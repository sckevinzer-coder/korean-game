export 'tts_service_stub.dart'
    if (dart.library.js_interop) 'tts_service_web.dart';

/// Represents an available TTS voice.
class TtsVoice {
  const TtsVoice({required this.name, required this.lang, this.uri});

  final String name;
  final String lang;
  final String? uri;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TtsVoice &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          lang == other.lang &&
          uri == other.uri;

  @override
  int get hashCode => Object.hash(name, lang, uri);

  @override
  String toString() => 'TtsVoice(name: $name, lang: $lang, uri: $uri)';
}

/// Platform-agnostic text-to-speech interface.
abstract class TtsService {
  /// Speaks the given [text] with optional [rate] (0.0-2.0), [pitch] (0.0-2.0), and [volume] (0.0-1.0).
  Future<void> speak(String text, {double rate = 1.0, double pitch = 1.0, double volume = 1.0});

  /// Speaks the given [ssml] (Speech Synthesis Markup Language) string.
  /// Falls back to [speak] if the platform doesn't support SSML.
  Future<void> speakSsml(String ssml, {double rate = 1.0, double pitch = 1.0, double volume = 1.0});

  /// Stops any ongoing speech.
  Future<void> stop();

  /// Returns a list of available TTS voices.
  Future<List<TtsVoice>> getVoices();

  /// Sets the voice to use for subsequent [speak] calls.
  /// [voice] must be one of the voices returned by [getVoices].
  Future<void> setVoice(TtsVoice voice);
}

/// Does nothing; useful for tests and silent mode.
class NoopTtsService implements TtsService {
  @override
  Future<void> speak(String text, {double rate = 1.0, double pitch = 1.0, double volume = 1.0}) async {}

  @override
  Future<void> speakSsml(String ssml, {double rate = 1.0, double pitch = 1.0, double volume = 1.0}) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<List<TtsVoice>> getVoices() async => const [];

  @override
  Future<void> setVoice(TtsVoice voice) async {}
}
