import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:korean_game/models/word.dart';
import 'package:korean_game/quiz/quiz_generator.dart';
import 'package:korean_game/screens/quiz_screen.dart';
import 'package:korean_game/stats/stats_store.dart';

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
  late StatsStore stats;
  late Directory tmpDir;

  final DateTime now = DateTime(2026, 10, 3, 12);

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('korean_game_quiz');
    stats = StatsStore(path: p.join(tmpDir.path, 'stats.db'));
    await stats.currentStreak(now);
  });

  tearDown(() async {
    await stats.close();
    await tmpDir.delete(recursive: true);
  });

  testWidgets('completing a quiz records study day', (tester) async {
    const questions = [
      QuizQuestion(
        prompt: '愛',
        options: ['사랑', '학교', '친구', '음식'],
        correctIndex: 0,
        kind: QuizKind.meaningToWord,
      ),
    ];
    final words = [
      word('t1-001', '사랑', '愛'),
      word('t1-002', '학교', '学校'),
      word('t1-003', '친구', '友達'),
      word('t1-004', '음식', '食べ物'),
    ];

    await tester.pumpWidget(MaterialApp(
      home: QuizScreen(
        words: words,
        questions: questions,
        stats: stats,
        now: () => now,
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('사랑'));
    await tester.pump();
    expect(find.text('正解！'), findsOneWidget);

    await tester.tap(find.text('結果を見る'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();

    expect(find.text('クイズ完了！'), findsOneWidget);
    final streak = await tester.runAsync(() => stats.currentStreak(now));
    expect(streak, 1);
  });

  testWidgets('empty quiz does not record study day', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: QuizScreen(
        words: const [],
        stats: stats,
        now: () => now,
      ),
    ));
    await tester.pump();

    expect(find.text('クイズにする単語がありません'), findsOneWidget);
    final streak = await tester.runAsync(() => stats.currentStreak(now));
    expect(streak, 0);
  });
}
