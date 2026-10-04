import 'package:flutter_tts/flutter_tts.dart';

import 'tts_service.dart';

/// Mobile/desktop implementation backed by flutter_tts.
class FlutterTtsService implements TtsService {
  FlutterTts? _tts;
  bool _languageSet = false;
  double _rate = 1.0;
  double _pitch = 1.0;
  double _volume = 1.0;
  TtsVoice? _selectedVoice;
  TtsProgressHandler? _progressHandler;

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
    if (_selectedVoice != null && _selectedVoice!.uri != null) {
      await tts.setVoice({'name': _selectedVoice!.name, 'locale': _selectedVoice!.lang});
    }
    if (_progressHandler != null) {
      tts.setProgressHandler(_onProgress);
    }
    await tts.speak(text);
  }

  @override
  Future<void> speakSsml(String ssml, {double rate = 1.0, double pitch = 1.0, double volume = 1.0}) async {
    _rate = rate.clamp(0.0, 2.0);
    _pitch = pitch.clamp(0.0, 2.0);
    _volume = volume.clamp(0.0, 1.0);

    final tts = await _ensureInitialized();
    await tts.setSpeechRate(_rate);
    await tts.setPitch(_pitch);
    await tts.setVolume(_volume);
    if (_selectedVoice != null && _selectedVoice!.uri != null) {
      await tts.setVoice({'name': _selectedVoice!.name, 'locale': _selectedVoice!.lang});
    }
    if (_progressHandler != null) {
      tts.setProgressHandler(_onProgress);
    }
    await tts.speak(ssml);
  }

  void _onProgress(String text, int start, int end, String word) {
    if (_progressHandler != null) {
      _progressHandler!(TtsProgress(start: start, end: end, text: word));
    }
  }

  @override
  Future<void> stop() async {
    await _tts?.stop();
  }

  @override
  Future<List<TtsVoice>> getVoices() async {
    final tts = await _ensureInitialized();
    // flutter_tts getVoices is a getter that returns List<dynamic> directly
    final voices = tts.getVoices;
    return (voices as List)
        .map((v) => TtsVoice(
              name: v['name']?.toString() ?? '',
              lang: v['locale']?.toString() ?? v['language']?.toString() ?? '',
              uri: v['name']?.toString(),
            ))
        .where((v) => v.name.isNotEmpty)
        .toList();
  }

  @override
  Future<void> setVoice(TtsVoice voice) async {
    _selectedVoice = voice;
  }

  @override
  void setProgressHandler(TtsProgressHandler? handler) {
    _progressHandler = handler;
  }
}

TtsService createTtsService() {
  return FlutterTtsService();
}
