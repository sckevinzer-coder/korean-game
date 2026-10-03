import 'package:flutter_tts/flutter_tts.dart';

import 'tts_service.dart';

/// Mobile/desktop implementation backed by flutter_tts.
class FlutterTtsService implements TtsService {
  FlutterTts? _tts;
  bool _languageSet = false;

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
  Future<void> speak(String text) async {
    await (await _ensureInitialized()).speak(text);
  }

  @override
  Future<void> stop() async {
    await _tts?.stop();
  }
}

TtsService createTtsService() {
  return FlutterTtsService();
}
