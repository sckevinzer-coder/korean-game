import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:korean_game/stats/error_stats.dart';

void main() {
  late ErrorStatsStore store;
  late Directory tmpDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('korean_game_errors');
    store = ErrorStatsStore(path: p.join(tmpDir.path, 'error_stats.db'));
    await store.topWeak();
  });

  tearDown(() async {
    await store.close();
    await tmpDir.delete(recursive: true);
  });

  test('records attempts and ranks weak items by error rate', () async {
    await store.recordAttempt(key: 'writing:사랑해요', isCorrect: false, lastError: '사랑해요');
    await store.recordAttempt(key: 'writing:사랑해요', isCorrect: false, lastError: '사랑해요');
    await store.recordAttempt(key: 'meaningToWord:학교', isCorrect: true);
    await store.recordAttempt(key: 'meaningToWord:학교', isCorrect: false, lastError: '学校');

    final weak = await store.topWeak(limit: 5);
    expect(weak.map((w) => w.key), contains('writing:사랑해요'));
    expect(weak.first.key, 'writing:사랑해요');
    expect(weak.first.errorRate, 1.0);
  });

  test('clear removes all stats', () async {
    await store.recordAttempt(key: 'writing:사랑해요', isCorrect: false, lastError: 'x');
    await store.clear();
    expect(await store.topWeak(), isEmpty);
  });
}
