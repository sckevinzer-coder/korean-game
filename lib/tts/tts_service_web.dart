import 'dart:js_interop';

import 'tts_service.dart';

@JS('SpeechSynthesisUtterance')
extension type _Utterance._(JSObject _) implements JSObject {
  external factory _Utterance(JSString text);
  external set lang(JSString value);
  external set rate(JSNumber value);
  external set pitch(JSNumber value);
  external set volume(JSNumber value);
}

@JS()
extension type _Synthesis(JSObject _) implements JSObject {
  external void speak(_Utterance utterance);
  external void cancel();
}

@JS('window.speechSynthesis')
external _Synthesis get _speechSynthesis;

/// Web implementation backed by the SpeechSynthesis browser API.
class WebTtsService implements TtsService {
  @override
  Future<void> speak(String text, {double rate = 1.0, double pitch = 1.0, double volume = 1.0}) async {
    final utterance = _Utterance(text.toJS);
    utterance.lang = 'ko-KR'.toJS;
    utterance.rate = rate.clamp(0.0, 2.0).toJS;
    utterance.pitch = pitch.clamp(0.0, 2.0).toJS;
    utterance.volume = volume.clamp(0.0, 1.0).toJS;
    _speechSynthesis.cancel();
    _speechSynthesis.speak(utterance);
  }

  @override
  Future<void> stop() async {
    _speechSynthesis.cancel();
  }
}

TtsService createTtsService() => WebTtsService();
