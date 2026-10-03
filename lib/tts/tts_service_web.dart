import 'dart:js_interop';

import 'tts_service.dart';

@JS('SpeechSynthesisUtterance')
extension type _Utterance._(JSObject _) implements JSObject {
  external factory _Utterance(JSString text);
  external set lang(JSString value);
  external set rate(JSNumber value);
  external set pitch(JSNumber value);
  external set volume(JSNumber value);
  external set voice(JSObject value);
}

@JS()
extension type _Voice(JSObject _) implements JSObject {
  external JSString get name;
  external JSString get lang;
  external JSBoolean get isDefault;
  external JSString? get localService;
}

@JS()
extension type _Synthesis(JSObject _) implements JSObject {
  external void speak(_Utterance utterance);
  external void cancel();
  external JSArray<JSObject> getVoices();
}

@JS('window.speechSynthesis')
external _Synthesis get _speechSynthesis;

/// Converts a JSArray to a Dart List.
List<T> _jsArrayToList<T>(JSArray<JSObject> array) {
  final list = <T>[];
  for (var i = 0; i < array.length; i++) {
    list.add(array[i] as T);
  }
  return list;
}

/// Web implementation backed by the SpeechSynthesis browser API.
class WebTtsService implements TtsService {
  TtsVoice? _selectedVoice;

  @override
  Future<void> speak(String text, {double rate = 1.0, double pitch = 1.0, double volume = 1.0}) async {
    final utterance = _Utterance(text.toJS);
    utterance.lang = 'ko-KR'.toJS;
    utterance.rate = rate.clamp(0.0, 2.0).toJS;
    utterance.pitch = pitch.clamp(0.0, 2.0).toJS;
    utterance.volume = volume.clamp(0.0, 1.0).toJS;
    if (_selectedVoice != null && _selectedVoice!.uri != null) {
      // Find the voice object by name/uri and set it
      final voices = _jsArrayToList<JSObject>(_speechSynthesis.getVoices());
      for (final v in voices) {
        final voice = _Voice(v);
        if (voice.name.toDart == _selectedVoice!.uri) {
          utterance.voice = v;
          break;
        }
      }
    }
    _speechSynthesis.cancel();
    _speechSynthesis.speak(utterance);
  }

  @override
  Future<void> speakSsml(String ssml, {double rate = 1.0, double pitch = 1.0, double volume = 1.0}) async {
    // Web Speech API has limited SSML support; strip tags and speak plain text as fallback
    final plainText = _stripSsml(ssml);
    await speak(plainText, rate: rate, pitch: pitch, volume: volume);
  }

  @override
  Future<void> stop() async {
    _speechSynthesis.cancel();
  }

  @override
  Future<List<TtsVoice>> getVoices() async {
    // Ensure voices are loaded (they may load asynchronously)
    var voices = _jsArrayToList<JSObject>(_speechSynthesis.getVoices());
    if (voices.isEmpty) {
      // Wait a bit for voices to load
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    final voices2 = _jsArrayToList<JSObject>(_speechSynthesis.getVoices());
    return voices2
        .map((v) => _Voice(v))
        .map((v) => TtsVoice(
              name: v.name.toDart,
              lang: v.lang.toDart,
              uri: v.name.toDart,
            ))
        .where((v) => v.name.isNotEmpty)
        .toList();
  }

  @override
  Future<void> setVoice(TtsVoice voice) async {
    _selectedVoice = voice;
  }

  /// Strips SSML tags and returns plain text.
  static String _stripSsml(String ssml) {
    return ssml
        .replaceAll(RegExp(r'<[^>]+>'), '') // Remove XML tags
        .replaceAll(RegExp(r'<'), '<')
        .replaceAll(RegExp(r'>'), '>')
        .replaceAll(RegExp(r'&'), '&')
        .replaceAll(RegExp(r'"'), '"')
        .replaceAll(RegExp(r'&apos;'), "'")
        .trim();
  }
}

TtsService createTtsService() => WebTtsService();
