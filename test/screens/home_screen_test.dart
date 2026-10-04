import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:korean_game/db/progress_store.dart';
import 'package:korean_game/models/word.dart';
import 'package:korean_game/screens/home_screen.dart';
import 'package:korean_game/srs/srs_scheduler.dart';
import 'package:korean_game/stats/stats_store.dart';

class FakeProgressStore extends ProgressStore {
  final List<SrsCard> cards;
  FakeProgressStore({this.cards = const []});
  @override
  Future<List<SrsCard>> dueCards(DateTime now) async => cards;
  @override
  Future<List<SrsCard>> allCardsForLevel(int level) async => cards;
  @override
  Future<void> upsert(SrsCard card) async {}
}

class FakeStatsStore extends StatsStore {
  final int streak;
  FakeStatsStore({this.streak = 0});
  @override
  Future<int> displayStreak(DateTime today) async => streak;
  @override
  Future<void> recordStudy(DateTime day) async {}
  @override
  Future<int> currentStreak(DateTime today) async => streak;
  @override
  Future<ProtectedStreak> protectedStreak(DateTime today) async =>
      ProtectedStreak(streak: streak, freezeUsed: false);
  @override
  Future<int> freezesLeft(DateTime today) async => 1;
}

Word word(String id) => Word(
      id: id,
      korean: '한국어',
      reading: 'hangugeo',
      meaningJa: '韓国語',
      exampleKo: '예문',
      exampleJa: '例文',
      topikLevel: 1,
    );

void main() {
  late ProgressStore store;
  late StatsStore stats;
  late Directory tmpDir;

  final DateTime now = DateTime(2026, 10, 3, 12);

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // ProgressStore and StatsStore must use distinct files: sharing
    // inMemoryDatabasePath reuses one SQLite db, so the second schema's
    // onCreate never runs (no such table).
    tmpDir = await Directory.systemTemp.createTemp('korean_game_home');
    store = ProgressStore(path: p.join(tmpDir.path, 'progress.db'));
    stats = StatsStore(path: p.join(tmpDir.path, 'stats.db'));
    // Seed progress outside the widget-test zone.
    await store.upsert(SrsCard(
        wordId: 't1-001',
        interval: const Duration(days: 1),
        ease: 2.5,
        dueDate: now.subtract(const Duration(hours: 3))));
    await store.upsert(SrsCard(
        wordId: 't1-002',
        interval: const Duration(days: 1),
        ease: 2.5,
        dueDate: now.subtract(const Duration(hours: 1))));
    await store.upsert(SrsCard(
        wordId: 't1-003',
        interval: const Duration(days: 1),
        ease: 2.5,
        dueDate: now.add(const Duration(days: 1))));
  });

  tearDown(() async {
    await store.close();
    await stats.close();
    await tmpDir.delete(recursive: true);
  });

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(
        store: store,
        stats: stats,
        levelSelectStats: FakeStatsStore(streak: 2),
        now: () => now,
        loadWords: (level) async => List.generate(
            10, (i) => word('t1-${(i + 1).toString().padLeft(3, '0')}')),
      ),
    ));
    // Poll with real time: FFI store futures resolve outside fake async.
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
      if (find.text('今日の復習: 9 / 10 枚').evaluate().isNotEmpty) return;
    }
  }

  testWidgets('shows count of due cards and streak from stats', (tester) async {
    await tester.runAsync(() async {
      await stats.recordStudy(DateTime(2026, 10, 2));
      await stats.recordStudy(DateTime(2026, 10, 1));
    });
    await pumpHome(tester);

    expect(find.text('今日の復習: 9 / 10 枚'), findsOneWidget);
    // Studied yesterday but not today: max(today=0, yesterday=2) = 2.
    expect(find.text('連続学習: 2日'), findsOneWidget);
  });

  testWidgets('today streak wins via max(today, yesterday)', (tester) async {
    await tester.runAsync(() async {
      await stats.recordStudy(DateTime(2026, 10, 1));
      await stats.recordStudy(DateTime(2026, 10, 2));
      await stats.recordStudy(DateTime(2026, 10, 3));
    });
    await pumpHome(tester);

    expect(find.text('連続学習: 3日'), findsOneWidget);
  });

  testWidgets('no stats yields zero streak', (tester) async {
    await pumpHome(tester);

    expect(find.text('連続学習: 0日'), findsOneWidget);
  });

  testWidgets('shows remaining streak freezes', (tester) async {
    final fakeProgress = FakeProgressStore(cards: []);
    final fakeStats = FakeStatsStore(streak: 2);
    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(
        store: fakeProgress,
        stats: fakeStats,
        levelSelectStats: fakeStats,
        now: () => now,
        loadWords: (level) async => List.generate(
            10, (i) => word('t1-${(i + 1).toString().padLeft(3, '0')}')),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('🛡️ 連続保護: 残り1回'), findsOneWidget);
  });

testWidgets('tapping level button opens level select', (tester) async {
    // Use FakeProgressStore and FakeStatsStore to avoid pending DB timers
    final fakeProgress = FakeProgressStore(cards: []);
    final fakeStats = FakeStatsStore(streak: 2);
    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(
        store: fakeProgress,
        stats: fakeStats,
        levelSelectStats: fakeStats,
        now: () => now,
        loadWords: (level) async => List.generate(
            10, (i) => word('t1-${(i + 1).toString().padLeft(3, '0')}')),
      ),
    ));
    // Wait for HomeScreen to render
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('レベルを選ぶ'), findsOneWidget);
    await tester.tap(find.text('レベルを選ぶ'));
    await tester.pumpAndSettle();

    expect(find.text('レベル選択'), findsOneWidget);
    expect(find.text('TOPIK 1級'), findsOneWidget);
  });
}
