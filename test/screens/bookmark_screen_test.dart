import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:korean_game/models/word.dart';
import 'package:korean_game/screens/bookmark_screen.dart';
import 'package:korean_game/stats/bookmark_store.dart';

Word word(String id, String korean, String meaningJa) => Word(
      id: id,
      korean: korean,
      reading: 'reading-$id',
      meaningJa: meaningJa,
      exampleKo: '예문-$id',
      exampleJa: '例文-$id',
      topikLevel: 1,
    );

void main() {
  late BookmarkStore bookmarks;
  late Directory tmpDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('korean_game_bookmark_ui');
    bookmarks = BookmarkStore(path: p.join(tmpDir.path, 'bookmarks.db'));
    await bookmarks.allIds();
  });

  tearDown(() async {
    await bookmarks.close();
    await tmpDir.delete(recursive: true);
  });

  Future<List<Word>> loadWords(int level) async => [
        word('t1-001', '한국어', '韓国語'),
        word('t1-002', '사랑', '愛'),
        word('t1-003', '학교', '学校'),
        word('t1-004', '친구', '友達'),
        word('t1-005', '음식', '食べ物'),
      ];

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)));
    }
    await tester.pump();
  }

  testWidgets('empty bookmarks show guidance', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: BookmarkScreen(bookmarks: bookmarks, loadWords: loadWords),
    ));
    await settle(tester);

    expect(find.text('ブックマークはまだありません\n単語カードの☆から保存できます'),
        findsOneWidget);
  });

  testWidgets('saved words listed with review button', (tester) async {
    await tester.runAsync(() async {
      await bookmarks.add('t1-001');
      await bookmarks.add('t1-002');
    });

    await tester.pumpWidget(MaterialApp(
      home: BookmarkScreen(bookmarks: bookmarks, loadWords: loadWords),
    ));
    await settle(tester);

    expect(find.text('保存済み: 2語'), findsOneWidget);
    expect(find.text('한국어'), findsOneWidget);
    expect(find.text('ブックマーククイズ'), findsOneWidget);
  });

  testWidgets('delete removes the word from the list', (tester) async {
    await tester.runAsync(() => bookmarks.add('t1-001'));

    await tester.pumpWidget(MaterialApp(
      home: BookmarkScreen(bookmarks: bookmarks, loadWords: loadWords),
    ));
    await settle(tester);
    expect(find.text('한국어'), findsOneWidget);

    await tester.tap(find.byTooltip('削除'));
    await settle(tester);

    expect(find.text('한국어'), findsNothing);
  });
}
