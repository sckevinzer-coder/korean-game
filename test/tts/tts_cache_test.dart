import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:korean_game/tts/tts_cache.dart';
import 'package:korean_game/tts/tts_service.dart';

class FakeInnerTts implements TtsService {
  final List<String> spoken = [];
  int stops = 0;
  TtsVoice? voice;
  TtsProgressHandler? handler;
  final List<TtsProgress> progress = [];

  @override
  Future<void> speak(String text,
      {double rate = 1.0, double pitch = 1.0, double volume = 1.0}) async {
    spoken.add(text);
  }

  @override
  Future<void> speakSsml(String ssml,
      {double rate = 1.0, double pitch = 1.0, double volume = 1.0}) async {
    spoken.add(ssml);
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<List<TtsVoice>> getVoices() async => const [
        TtsVoice(name: 'ko', lang: 'ko-KR'),
      ];

  @override
  Future<void> setVoice(TtsVoice voice) async {
    this.voice = voice;
  }

  @override
  void setProgressHandler(TtsProgressHandler? handler) {
    this.handler = handler;
  }

  void emitProgress(TtsProgress p) {
    progress.add(p);
    handler?.call(p);
  }
}

void main() {
  late Directory tmpDir;
  late FakeInnerTts inner;
  late List<String> synthesized;
  late List<String> played;
  late int stopped;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('tts_cache_test');
    inner = FakeInnerTts();
    synthesized = [];
    played = [];
    stopped = 0;
  });

  tearDown(() async {
    await tmpDir.delete(recursive: true);
  });

  CachedTtsService buildService({int maxEntries = 200}) {
    return CachedTtsService(
      inner,
      cacheDirectory: tmpDir,
      maxEntries: maxEntries,
      synthesizeFn: ({
        required String text,
        required String filePath,
        required double rate,
        required double pitch,
        required String? voiceName,
        required String? voiceLocale,
      }) async {
        synthesized.add(text);
        await File(filePath).writeAsString('audio:$text');
      },
      playFileFn: (path, volume) async {
        played.add(path);
      },
      stopPlaybackFn: () async {
        stopped++;
      },
    );
  }

  group('cacheFileName', () {
    test('stable across calls and distinct per params', () {
      final a = CachedTtsService.cacheFileName(
          text: '사랑', rate: 1.0, pitch: 1.0);
      final b = CachedTtsService.cacheFileName(
          text: '사랑', rate: 1.0, pitch: 1.0);
      final c = CachedTtsService.cacheFileName(
          text: '사랑', rate: 0.8, pitch: 1.0);
      final d = CachedTtsService.cacheFileName(
          text: '학교', rate: 1.0, pitch: 1.0);

      expect(a, b);
      expect(a, isNot(c));
      expect(a, isNot(d));
      expect(a.endsWith('.wav'), isTrue);
    });
  });

  group('speak', () {
    test('miss synthesizes then plays, hit plays without synth', () async {
      final service = buildService();

      await service.speak('사랑');
      expect(synthesized, ['사랑']);
      expect(played, hasLength(1));

      await service.speak('사랑');
      expect(synthesized, ['사랑']);
      expect(played, hasLength(2));
      expect(inner.spoken, isEmpty);
    });

    test('synth failure falls back to live speech', () async {
      final failing = CachedTtsService(
        inner,
        cacheDirectory: tmpDir,
        synthesizeFn: ({
          required String text,
          required String filePath,
          required double rate,
          required double pitch,
          required String? voiceName,
          required String? voiceLocale,
        }) async {
          throw StateError('no synth');
        },
        playFileFn: (path, volume) async {
          played.add(path);
        },
        stopPlaybackFn: () async {},
      );

      await failing.speak('사랑');
      expect(inner.spoken, ['사랑']);
      expect(played, isEmpty);
    });

    test('hit reports full-span progress', () async {
      final service = buildService();
      TtsProgress? seen;
      service.setProgressHandler((p) => seen = p);

      await service.speak('사랑');
      await service.speak('사랑');

      expect(seen, isNotNull);
      expect(seen!.start, 0);
      expect(seen!.end, '사랑'.length);
    });

    test('evicts oldest entries beyond cap', () async {
      final service = buildService(maxEntries: 2);

      await service.speak('가');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await service.speak('나');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await service.speak('다');

      final files = tmpDir
          .listSync()
          .whereType<File>()
          .map((f) => f.path)
          .toList();
      expect(files, hasLength(2));
      expect(await service.cacheSize(), 2);
    });

    test('ssml bypasses cache', () async {
      final service = buildService();

      await service.speakSsml('<speak>사랑</speak>');

      expect(synthesized, isEmpty);
      expect(inner.spoken, ['<speak>사랑</speak>']);
    });

    test('stop stops both playback and inner', () async {
      final service = buildService();

      await service.stop();

      expect(stopped, 1);
      expect(inner.stops, 1);
    });

    test('voices and voice selection delegate', () async {
      final service = buildService();

      expect(await service.getVoices(), hasLength(1));
      await service.setVoice(const TtsVoice(name: 'ko', lang: 'ko-KR'));
      expect(inner.voice?.name, 'ko');
    });

    test('clearCache empties the directory', () async {
      final service = buildService();

      await service.speak('사랑');
      expect(await service.cacheSize(), 1);
      await service.clearCache();
      expect(await service.cacheSize(), 0);
    });
  });
}
