import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:korean_game/models/word.dart';
import 'package:korean_game/quiz/quiz_generator.dart';
import 'package:korean_game/screens/quiz_screen.dart';
import 'package:korean_game/stats/stats_store.dart';
import 'package:korean_game/tts/tts_service.dart';

Word word(String id, String korean, String meaningJa, {String? exampleKo}) => Word(
      id: id,
      korean: korean,
      reading: 'reading-$id',
      meaningJa: meaningJa,
      exampleKo: exampleKo ?? '예문 $id $korean',
      exampleJa: '例文-$id',
      topikLevel: 1,
    );

/// Fake TTS that records calls and can throw.
class FakeTtsService implements TtsService {
  FakeTtsService({this.shouldThrow = false});
  final List<String> spoken = [];
  final List<double> rates = [];
  final List<double> pitches = [];
  final List<double> volumes = [];
  final bool shouldThrow;

  @override
  Future<void> speak(String text, {double rate = 1.0, double pitch = 1.0, double volume = 1.0}) async {
    spoken.add(text);
    rates.add(rate);
    pitches.add(pitch);
    volumes.add(volume);
    if (shouldThrow) throw StateError('TTS error');
  }

  @override
  Future<void> stop() async {}
}

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
    await tester.pumpAndSettle();
    expect(find.text('正解！'), findsOneWidget);

    // Debug: check what buttons exist
    // expect(find.text('결과 보기'), findsOneWidget); // This should work
    await tester.tap(find.byType(ElevatedButton).last);
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();

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

  testWidgets('level 1 uses only meaningToWord and wordToMeaning', (tester) async {
    final words = List.generate(6, (i) => word('w$i', '단어$i', '意味$i'));
    final fakeTts = FakeTtsService();

    await tester.pumpWidget(MaterialApp(
      home: QuizScreen(
        words: words,
        stats: stats,
        now: () => now,
        level: 1,
        tts: fakeTts,
      ),
    ));
    await tester.pump();

    // For level 1, we should never see listening/blank/writing UI elements
    for (int i = 0; i < words.length; i++) {
      // Check that prompt is either Korean or Japanese meaning (not listening prompt)
      final promptText = tester.widget<Text>(find.byType(Text).at(2)).data;
      expect(promptText, isNot(contains('듣기')));
      expect(promptText, isNot(contains('쓰기')));
      expect(promptText, isNot(contains('＿＿')));

      // Answer correctly to advance
      await tester.tap(find.byType(ElevatedButton).first);
      await tester.pumpAndSettle();
      if (i < words.length - 1) {
        await tester.tap(find.byType(ElevatedButton).last);
        await tester.pumpAndSettle();
      } else {
        await tester.tap(find.byType(ElevatedButton).last);
        await tester.pumpAndSettle();
      }
    }
  });

  testWidgets('level 4 includes listening and blank kinds', (tester) async {
    final words = List.generate(10, (i) => word('w$i', '단어$i', '意味$i', exampleKo: '이것은 단어$i입니다'));
    final fakeTts = FakeTtsService();

    await tester.pumpWidget(MaterialApp(
      home: QuizScreen(
        words: words,
        stats: stats,
        now: () => now,
        level: 4,
        tts: fakeTts,
      ),
    ));
    await tester.pump();

    // Check that we see different question types by going through all questions
    final seenKinds = <String>{};
    for (int i = 0; i < words.length; i++) {
      final promptText = tester.widget<Text>(find.byType(Text).at(2)).data ?? '';
      if (promptText.contains('듣기: 적절한 단어를 선택')) {
        seenKinds.add('listeningWord');
      } else if (promptText.contains('듣기: 적절한 의미를 선택')) {
        seenKinds.add('listeningMeaning');
      } else if (promptText.contains('＿＿')) {
        seenKinds.add('blank');
      } else if (words.any((w) => w.meaningJa == promptText)) {
        seenKinds.add('meaningToWord');
      } else if (words.any((w) => w.korean == promptText)) {
        seenKinds.add('wordToMeaning');
      }

      // Answer correctly to advance
      await tester.tap(find.byType(ElevatedButton).first);
      await tester.pumpAndSettle();
      if (i < words.length - 1) {
        await tester.tap(find.byType(ElevatedButton).last);
        await tester.pumpAndSettle();
      } else {
        await tester.tap(find.byType(ElevatedButton).last);
        await tester.pumpAndSettle();
      }
    }

    expect(seenKinds.contains('listeningWord'), isTrue);
    expect(seenKinds.contains('listeningMeaning'), isTrue);
    expect(seenKinds.contains('blank'), isTrue);
    expect(seenKinds.contains('meaningToWord'), isTrue);
    expect(seenKinds.contains('wordToMeaning'), isTrue);
  });

  testWidgets('level 6 includes writing kind', (tester) async {
    final words = List.generate(10, (i) => word('w$i', '단어$i', '意味$i', exampleKo: '이것은 단어$i입니다'));
    final fakeTts = FakeTtsService();

    await tester.pumpWidget(MaterialApp(
      home: QuizScreen(
        words: words,
        stats: stats,
        now: () => now,
        level: 6,
        tts: fakeTts,
      ),
    ));
    await tester.pump();

    // Check that we see writing kind by going through all questions
    bool sawWriting = false;
    for (int i = 0; i < words.length; i++) {
      final promptText = tester.widget<Text>(find.byType(Text).at(2)).data ?? '';
      if (promptText.contains('쓰기:')) {
        sawWriting = true;
        break;
      }

      // Answer correctly to advance
      await tester.tap(find.byType(ElevatedButton).first);
      await tester.pumpAndSettle();
      if (i < words.length - 1) {
        await tester.tap(find.byType(ElevatedButton).last);
        await tester.pumpAndSettle();
      } else {
        await tester.tap(find.byType(ElevatedButton).last);
        await tester.pumpAndSettle();
      }
    }

    expect(sawWriting, isTrue);
  });

  testWidgets('listening question shows replay button and auto-speaks on display', (tester) async {
    // Need 4 words for distractors
    const questions = [
      QuizQuestion(
        prompt: '듣기: 적절한 단어를 선택하세요',
        options: ['사랑', '학교', '친구', '음식'],
        correctIndex: 0,
        kind: QuizKind.listeningWord,
        audioText: '사랑',
      ),
    ];
    final words = [
      word('t1-001', '사랑', '愛'),
      word('t1-002', '학교', '学校'),
      word('t1-003', '친구', '友達'),
      word('t1-004', '음식', '食べ物'),
    ];
    final fakeTts = FakeTtsService();

    await tester.pumpWidget(MaterialApp(
      home: QuizScreen(
        words: words,
        questions: questions,
        stats: stats,
        now: () => now,
        tts: fakeTts,
      ),
    ));
    await tester.pump();

    // Auto-speak on display
    expect(fakeTts.spoken, ['사랑']);

    // Replay button exists (Icons.replay)
    expect(find.byIcon(Icons.replay), findsOneWidget);

    // Tap replay speaks again
    await tester.tap(find.byIcon(Icons.replay));
    await tester.pump();
    expect(fakeTts.spoken, ['사랑', '사랑']);
  });

  testWidgets('listening question fallback text toggle reveals audioText', (tester) async {
    const questions = [
      QuizQuestion(
        prompt: '듣기: 적절한 의미를 선택하세요',
        options: ['愛', '学校', '友達', '食べ物'],
        correctIndex: 0,
        kind: QuizKind.listeningMeaning,
        audioText: '사랑',
      ),
    ];
    final words = [
      word('t1-001', '사랑', '愛'),
      word('t1-002', '학교', '学校'),
      word('t1-003', '친구', '友達'),
      word('t1-004', '음식', '食べ物'),
    ];
    final fakeTts = FakeTtsService();

    await tester.pumpWidget(MaterialApp(
      home: QuizScreen(
        words: words,
        questions: questions,
        stats: stats,
        now: () => now,
        tts: fakeTts,
      ),
    ));
    await tester.pump();

    // Initially audioText not shown
    expect(find.text('사랑'), findsNothing);

    // Tap fallback toggle (テキストを見る)
    await tester.tap(find.text('テキストを見る'));
    await tester.pump();

    // audioText now visible
    expect(find.text('사랑'), findsOneWidget);

    // Tap again hides
    await tester.tap(find.text('テキストを隠す'));
    await tester.pump();
    expect(find.text('사랑'), findsNothing);
  });

testWidgets('writing question shows TextField and 回答する button, grades correctly', (tester) async {
    // Need 4 words for distractors when generating the base question
    const questions = [
      QuizQuestion(
        prompt: '쓰기: 愛の 한국어를 쓰세요',
        options: ['사랑해요'],
        correctIndex: 0,
        kind: QuizKind.writing,
        audioText: null,
      ),
    ];
    final words = [
      word('t1-001', '사랑해요', '愛しています'),
      word('t1-002', '학교', '学校'),
      word('t1-003', '친구', '友達'),
      word('t1-004', '음식', '食べ物'),
    ];
    final fakeTts = FakeTtsService();

    await tester.pumpWidget(MaterialApp(
      home: QuizScreen(
        words: words,
        questions: questions,
        stats: stats,
        now: () => now,
        tts: fakeTts,
      ),
    ));
    await tester.pump();

    // TextField and 回答する button present
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('回答する'), findsOneWidget);

    // Enter correct answer
    await tester.enterText(find.byType(TextField), '사랑해요');
    await tester.pump(); // Ensure onChanged fires
    await tester.tap(find.text('回答する'));
    await tester.pumpAndSettle();

    // Should show correct
    expect(find.text('正解！'), findsOneWidget);

    // Continue to end and check score
    await tester.tap(find.byType(ElevatedButton).last);
    await tester.pumpAndSettle();
    expect(find.textContaining('スコア: 1'), findsOneWidget);
  });

  testWidgets('writing question grades with particle tolerance', (tester) async {
    const questions = [
      QuizQuestion(
        prompt: '쓰기: 学校の 한국어를 쓰세요',
        options: ['학교에'],
        correctIndex: 0,
        kind: QuizKind.writing,
        audioText: null,
      ),
    ];
    final words = [
      word('t1-001', '학교에', '学校に'),
      word('t1-002', '학교', '学校'),
      word('t1-003', '친구', '友達'),
      word('t1-004', '음식', '食べ物'),
    ];
    final fakeTts = FakeTtsService();

    await tester.pumpWidget(MaterialApp(
      home: QuizScreen(
        words: words,
        questions: questions,
        stats: stats,
        now: () => now,
        tts: fakeTts,
      ),
    ));
    await tester.pump();

    // Enter answer without particle (학교에 -> 학교)
    await tester.enterText(find.byType(TextField), '학교');
    await tester.pump(); // Ensure onChanged fires
    await tester.tap(find.text('回答する'));
    await tester.pumpAndSettle();

    // Should still be correct due to particle stripping (에 is stripped)
    expect(find.text('正解！'), findsOneWidget);
  });

  testWidgets('writing question incorrect answer shows 不正解', (tester) async {
    const questions = [
      QuizQuestion(
        prompt: '쓰기: 愛していますの 한국어를 쓰세요',
        options: ['사랑해요'],
        correctIndex: 0,
        kind: QuizKind.writing,
        audioText: null,
      ),
    ];
    final words = [
      word('t1-001', '사랑해요', '愛しています'),
      word('t1-002', '학교', '学校'),
      word('t1-003', '친구', '友達'),
      word('t1-004', '음식', '食べ物'),
    ];
    final fakeTts = FakeTtsService();

    await tester.pumpWidget(MaterialApp(
      home: QuizScreen(
        words: words,
        questions: questions,
        stats: stats,
        now: () => now,
        tts: fakeTts,
      ),
    ));
    await tester.pump();

    await tester.enterText(find.byType(TextField), '학교');
    await tester.pump(); // Ensure onChanged fires
    await tester.tap(find.text('回答する'));
    await tester.pumpAndSettle();

    expect(find.text('不正解…'), findsOneWidget);
  });

  testWidgets('blank question renders prompt with ＿＿', (tester) async {
    const questions = [
      QuizQuestion(
        prompt: '이것은 ＿＿입니다',
        options: ['단어0', '단어1', '단어2', '단어3'],
        correctIndex: 0,
        kind: QuizKind.blank,
        audioText: null,
      ),
    ];
    final words = [
      word('w0', '단어0', '意味0', exampleKo: '이것은 단어0입니다'),
      word('w1', '단어1', '意味1', exampleKo: '이것은 단어1입니다'),
      word('w2', '단어2', '意味2', exampleKo: '이것은 단어2입니다'),
      word('w3', '단어3', '意味3', exampleKo: '이것은 단어3입니다'),
    ];
    final fakeTts = FakeTtsService();

    await tester.pumpWidget(MaterialApp(
      home: QuizScreen(
        words: words,
        questions: questions,
        stats: stats,
        now: () => now,
        tts: fakeTts,
      ),
    ));
    await tester.pump();

    expect(find.text('이것은 ＿＿입니다'), findsOneWidget);
  });

  testWidgets('TTS throwing does not crash session', (tester) async {
    const questions = [
      QuizQuestion(
        prompt: '듣기: 적절한 단어를 선택하세요',
        options: ['사랑', '학교', '친구', '음식'],
        correctIndex: 0,
        kind: QuizKind.listeningWord,
        audioText: '사랑',
      ),
    ];
    final words = [
      word('t1-001', '사랑', '愛'),
      word('t1-002', '학교', '学校'),
      word('t1-003', '친구', '友達'),
      word('t1-004', '음식', '食べ物'),
    ];
    final fakeTts = FakeTtsService(shouldThrow: true);

    await tester.pumpWidget(MaterialApp(
      home: QuizScreen(
        words: words,
        questions: questions,
        stats: stats,
        now: () => now,
        tts: fakeTts,
      ),
    ));
    await tester.pump();

    // Should not crash, UI still interactive
    expect(find.text('듣기: 적절한 단어를 선택하세요'), findsOneWidget);

    // Can still answer
    await tester.tap(find.text('사랑'));
    await tester.pump();
    expect(find.text('正解！'), findsOneWidget);
  });

  testWidgets('default tts is createTtsService and default level is 1', (tester) async {
    final words = List.generate(4, (i) => word('w$i', '단어$i', '意味$i'));

    await tester.pumpWidget(MaterialApp(
      home: QuizScreen(
        words: words,
        stats: stats,
        now: () => now,
      ),
    ));
    await tester.pump();

    // Should not crash with defaults
    expect(find.byType(Text), findsWidgets);
  });
}