import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tts_service.dart';

/// Synthesizes [text] into [filePath] (wav).
typedef SynthesizeFileFn = Future<void> Function({
  required String text,
  required String filePath,
  required double rate,
  required double pitch,
  required String? voiceName,
  required String? voiceLocale,
});

/// Plays a cached audio file.
typedef PlayFileFn = Future<void> Function(String filePath, double volume);

/// Stops file playback.
typedef StopPlaybackFn = Future<void> Function();

/// 64-bit FNV-1a hash, stable across runs (unlike [Object.hashCode]).
int _fnv1a64(String s) {
  var hash = 0xcbf29ce484222325;
  for (final byte in utf8.encode(s)) {
    hash ^= byte;
    hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  return hash;
}

/// File-backed TTS cache for repeated words (mobile/desktop).
///
/// Cache key covers text, rate, pitch, and voice. Hits play the cached
/// file and report a single full-span progress event; misses synthesize
/// once, then play. Synthesis failures fall back to live speech.
/// SSML bypasses the cache. Web uses the passthrough implementation.
class CachedTtsService implements TtsService {
  CachedTtsService(
    this._inner, {
    Directory? cacheDirectory,
    Future<Directory> Function()? cacheDirProvider,
    SynthesizeFileFn? synthesizeFn,
    PlayFileFn? playFileFn,
    StopPlaybackFn? stopPlaybackFn,
    AudioPlayer? player,
    this.maxEntries = 200,
  })  : _cacheDir = cacheDirectory,
        _cacheDirProvider = cacheDirProvider ?? _defaultDir,
        _synthesize = synthesizeFn ?? _defaultSynthesize,
        _providedPlayer = player,
        _playFile = playFileFn,
        _stopPlayback = stopPlaybackFn;

  final AudioPlayer? _providedPlayer;
  AudioPlayer? _lazyPlayer;

  AudioPlayer _player() => _providedPlayer ?? (_lazyPlayer ??= AudioPlayer());

  PlayFileFn get _effectivePlayFile =>
      _playFile ?? (path, volume) async {
        await _player().setVolume(volume.clamp(0.0, 1.0));
        await _player().play(DeviceFileSource(path));
      };

  StopPlaybackFn get _effectiveStopPlayback =>
      _stopPlayback ?? _player().stop;

  final TtsService _inner;
  final Directory? _cacheDir;
  final Future<Directory> Function() _cacheDirProvider;
  final SynthesizeFileFn _synthesize;
  final PlayFileFn? _playFile;
  final StopPlaybackFn? _stopPlayback;
  final int maxEntries;
  TtsVoice? _voice;
  TtsProgressHandler? _progressHandler;
  Directory? _resolvedDir;

  static Future<Directory> _defaultDir() async {
    final dir = Directory(
        p.join((await getApplicationSupportDirectory()).path, 'tts_cache'));
    await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> _dir() async {
    final cached = _resolvedDir ?? _cacheDir;
    if (cached != null) {
      _resolvedDir = cached;
      await cached.create(recursive: true);
      return cached;
    }
    final dir = await _cacheDirProvider();
    _resolvedDir = dir;
    return dir;
  }

  /// Stable file name for the given synthesis parameters.
  static String cacheFileName({
    required String text,
    required double rate,
    required double pitch,
    String? voiceName,
    String? voiceLocale,
  }) {
    final key = '$rate|$pitch|$voiceName|$voiceLocale|$text';
    final encoded =
        base64Url.encode(utf8.encode(key)).replaceAll('=', '');
    final head = encoded.length > 80 ? encoded.substring(0, 80) : encoded;
    final hash = _fnv1a64(key).toRadixString(16).padLeft(16, '0');
    return '$head-$hash.wav';
  }

  static Future<void> _defaultSynthesize({
    required String text,
    required String filePath,
    required double rate,
    required double pitch,
    required String? voiceName,
    required String? voiceLocale,
  }) async {
    final tts = FlutterTts();
    await tts.setLanguage('ko-KR');
    await tts.setSpeechRate(rate.clamp(0.0, 2.0));
    await tts.setPitch(pitch.clamp(0.0, 2.0));
    if (voiceName != null && voiceLocale != null) {
      await tts.setVoice({'name': voiceName, 'locale': voiceLocale});
    }
    await tts.synthesizeToFile(text, filePath, true);
  }

  Future<void> _evictIfNeeded(Directory dir) async {
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.wav'))
        .toList();
    if (files.length <= maxEntries) return;
    files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
    final overflow = files.length - maxEntries;
    for (var i = 0; i < overflow; i++) {
      try {
        files[i].deleteSync();
      } catch (_) {}
    }
  }

  @override
  Future<void> speak(String text,
      {double rate = 1.0, double pitch = 1.0, double volume = 1.0}) async {
    final Directory dir;
    try {
      dir = await _dir();
    } catch (_) {
      await _inner.speak(text, rate: rate, pitch: pitch, volume: volume);
      return;
    }
    final path = p.join(
      dir.path,
      cacheFileName(
        text: text,
        rate: rate,
        pitch: pitch,
        voiceName: _voice?.name,
        voiceLocale: _voice?.lang,
      ),
    );
    final file = File(path);
    if (await file.exists()) {
      try {
        await file.setLastModified(DateTime.now());
        _progressHandler?.call(
            TtsProgress(start: 0, end: text.length, text: text));
        await _effectivePlayFile(path, volume);
        return;
      } catch (_) {
        // Fall through to synthesis.
      }
    }
    try {
      await _synthesize(
        text: text,
        filePath: path,
        rate: rate,
        pitch: pitch,
        voiceName: _voice?.name,
        voiceLocale: _voice?.lang,
      );
      if (await file.exists()) {
        await _evictIfNeeded(dir);
        _progressHandler?.call(
            TtsProgress(start: 0, end: text.length, text: text));
        await _effectivePlayFile(path, volume);
        return;
      }
    } catch (_) {}
    await _inner.speak(text, rate: rate, pitch: pitch, volume: volume);
  }

  @override
  Future<void> speakSsml(String ssml,
      {double rate = 1.0,
      double pitch = 1.0,
      double volume = 1.0}) async {
    await _inner.speakSsml(ssml, rate: rate, pitch: pitch, volume: volume);
  }

  @override
  Future<void> stop() async {
    try {
      await _effectiveStopPlayback();
    } catch (_) {}
    await _inner.stop();
  }

  @override
  Future<List<TtsVoice>> getVoices() => _inner.getVoices();

  @override
  Future<void> setVoice(TtsVoice voice) async {
    _voice = voice;
    await _inner.setVoice(voice);
  }

  @override
  void setProgressHandler(TtsProgressHandler? handler) {
    _progressHandler = handler;
    _inner.setProgressHandler(handler);
  }

  /// Deletes the default cache directory contents. Returns files removed.
  static Future<int> clearDefaultCache() async {
    try {
      final dir = await _defaultDir();
      var removed = 0;
      for (final entity in dir.listSync()) {
        if (entity is File && entity.path.endsWith('.wav')) {
          try {
            await entity.delete();
            removed++;
          } catch (_) {}
        }
      }
      return removed;
    } catch (_) {
      return 0;
    }
  }

  /// Number of cached files.
  Future<int> cacheSize() async {
    final dir = await _dir();
    if (!await dir.exists()) return 0;
    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.wav'))
        .length;
  }

  /// Deletes all cached files.
  Future<void> clearCache() async {
    final dir = await _dir();
    if (!await dir.exists()) return;
    for (final entity in dir.listSync()) {
      if (entity is File && entity.path.endsWith('.wav')) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
  }
}
