import 'tts_service.dart';

/// Web implementation: speechSynthesis output cannot be captured, so this
/// is a passthrough with the same API surface for conditional export.
class CachedTtsService implements TtsService {
  CachedTtsService(this._inner);

  final TtsService _inner;

  static String cacheFileName({
    required String text,
    required double rate,
    required double pitch,
    String? voiceName,
    String? voiceLocale,
  }) =>
      '$text.wav';

  @override
  Future<void> speak(String text,
      {double rate = 1.0, double pitch = 1.0, double volume = 1.0}) {
    return _inner.speak(text, rate: rate, pitch: pitch, volume: volume);
  }

  @override
  Future<void> speakSsml(String ssml,
      {double rate = 1.0,
      double pitch = 1.0,
      double volume = 1.0}) {
    return _inner.speakSsml(ssml, rate: rate, pitch: pitch, volume: volume);
  }

  @override
  Future<void> stop() => _inner.stop();

  @override
  Future<List<TtsVoice>> getVoices() => _inner.getVoices();

  @override
  Future<void> setVoice(TtsVoice voice) => _inner.setVoice(voice);

  @override
  void setProgressHandler(TtsProgressHandler? handler) {
    _inner.setProgressHandler(handler);
  }

  static Future<int> clearDefaultCache() async => 0;

  Future<int> cacheSize() async => 0;

  Future<void> clearCache() async {}
}
