import 'package:flutter_tts/flutter_tts.dart';

import 'tts_service.dart';

/// Mobile/desktop implementation backed by flutter_tts.
class FlutterTtsService implements TtsService {
  FlutterTts? _tts;
  bool _languageSet = false;
  double _rate = 1.0;
  double _pitch = 1.0;
  double _volume = 1.0;

  Future<FlutterTts> _ensureInitialized() async {
    var tts = _tts;
    if (tts == null) {
      tts = FlutterTts();
      _tts = tts;
    }
    if (!_languageSet) {
      await tts.setLanguage('ko-KR');
      _languageSet = true;
    }
    return tts;
  }

  @override
  Future<void> speak(String text, {double rate = 1.0, double pitch = 1.0, double volume = 1.0}) async {
    _rate = rate.clamp(0.0, 2.0);
    _pitch = pitch.clamp(0.0, 2.0);
    _volume = volume.clamp(0.0, 1.0);

    final tts = await _ensureInitialized();
    await tts.setSpeechRate(_rate);
    await tts.setPitch(_pitch);
    await tts.setVolume(_volume);
    await tts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _tts?.stop();
  }
}

TtsService createTtsService() {
  return FlutterTtsService();
}
