import 'dart:js_interop';

import 'tts_service.dart';

@JS('SpeechSynthesisUtterance')
extension type _Utterance._(JSObject _) implements JSObject {
  external factory _Utterance(JSString text);
  external set lang(JSString value);
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
  Future<void> speak(String text) async {
    final utterance = _Utterance(text.toJS);
    utterance.lang = 'ko-KR'.toJS;
    _speechSynthesis.cancel();
    _speechSynthesis.speak(utterance);
  }

  @override
  Future<void> stop() async {
    _speechSynthesis.cancel();
  }
}

TtsService createTtsService() => WebTtsService();
