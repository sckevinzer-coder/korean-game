import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:korean_game/stats/bookmark_store.dart';

void main() {
  late BookmarkStore store;
  late Directory tmpDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('korean_game_bookmarks');
    store = BookmarkStore(path: p.join(tmpDir.path, 'bookmarks.db'));
    await store.allIds();
  });

  tearDown(() async {
    await store.close();
    await tmpDir.delete(recursive: true);
  });

  test('add and contains round-trip', () async {
    expect(await store.contains('t1-001'), isFalse);
    await store.add('t1-001');
    await store.add('t1-002');
    expect(await store.contains('t1-001'), isTrue);
    final ids = await store.allIds();
    expect(ids, containsAll(['t1-001', 't1-002']));
  });

  test('duplicate add is ignored', () async {
    await store.add('t1-001');
    await store.add('t1-001');
    expect(await store.allIds(), ['t1-001']);
  });

  test('remove deletes the bookmark', () async {
    await store.add('t1-001');
    await store.remove('t1-001');
    expect(await store.contains('t1-001'), isFalse);
    expect(await store.allIds(), isEmpty);
  });

  test('clear removes everything', () async {
    await store.add('t1-001');
    await store.add('t1-002');
    await store.clear();
    expect(await store.allIds(), isEmpty);
  });
}
