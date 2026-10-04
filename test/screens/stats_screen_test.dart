import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:korean_game/db/progress_store.dart';
import 'package:korean_game/models/word.dart';
import 'package:korean_game/screens/stats_screen.dart';
import 'package:korean_game/srs/srs_scheduler.dart';
import 'package:korean_game/stats/error_stats.dart';
import 'package:korean_game/stats/stats_store.dart';

class FakeProgressStore extends ProgressStore {
  @override
  Future<List<SrsCard>> allCardsForLevel(int level) async => [];
}

class FakeStatsStore extends StatsStore {
  @override
  Future<int> displayStreak(DateTime today) async => 2;
  @override
  Future<List<bool>> last7Days(DateTime today) async =>
      [true, false, true, false, false, false, true];
  @override
  Future<List<bool>> last30Days(DateTime today) async => [
        for (var i = 0; i < 30; i++) i % 10 == 0,
      ];
  @override
  Future<List<SessionRecord>> recentSessions(int limit) async => const [
        SessionRecord(day: '2026-10-01', total: 10, correct: 7),
        SessionRecord(day: '2026-10-02', total: 10, correct: 9),
        SessionRecord(day: '2026-10-03', total: 10, correct: 8),
      ];
  @override
  Future<Set<String>> unlockedAchievements() async => {};
  @override
  Future<List<String>> allStudyDays() async => [];
  @override
  Future<List<SessionRecord>> allSessions() async => [];
  @override
  Future<List<String>> allFreezeWeeks() async => [];
  @override
  Future<Map<String, String>> allSettings() async => {};
  @override
  Future<bool> getLenientGrading() async => false;
  @override
  Future<String> getLocaleCode() async => 'ja';
  @override
  Future<void> setLocaleCode(String code) async {}
}

class FakeErrorStats extends ErrorStatsStore {
  @override
  Future<List<WeakItem>> topWeak({int limit = 5}) async => [];
  @override
  Future<List<WeakItem>> allEntries() async => [];
  @override
  Future<void> importEntries(List<WeakItem> items) async {}
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
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('monthly report shows 30-day bar summary', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: StatsScreen(
        store: FakeProgressStore(),
        stats: FakeStatsStore(),
        errors: FakeErrorStats(),
        levels: const [1],
        loadWords: (level) async => [word('t1-001')],
        now: () => DateTime(2026, 10, 4),
      ),
    ));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('月間レポート'), findsOneWidget);
    expect(find.text('30日: 3 / 30 日学習'), findsOneWidget);
    expect(find.text('週間レポート'), findsOneWidget);
    expect(find.text('正答率の推移'), findsOneWidget);
    expect(find.text('直近3回平均: 80%'), findsOneWidget);
    expect(find.text('実績バッジ'), findsOneWidget);
    expect(find.text('初クイズ'), findsOneWidget);
    expect(find.text('全レベル制覇'), findsOneWidget);
    expect(find.text('間違いノート'), findsOneWidget);

    await tester.ensureVisible(find.text('間違いノート'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('間違いノート'));
    await tester.pumpAndSettle();

    expect(find.text('間違いノート', skipOffstage: false), findsWidgets);
    expect(find.text('間違い記録はまだありません'), findsOneWidget);
  });

  testWidgets('export opens dialog and import rejects invalid JSON',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: StatsScreen(
        store: FakeProgressStore(),
        stats: FakeStatsStore(),
        errors: FakeErrorStats(),
        levels: const [1],
        loadWords: (level) async => [word('t1-001')],
        now: () => DateTime(2026, 10, 4),
      ),
    ));
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('エクスポート'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('エクスポート'));
    await tester.pumpAndSettle();
    expect(find.text('データをエクスポート'), findsOneWidget);
    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('インポート'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('インポート'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'not json');
    await tester.pump();
    expect(find.text('データをインポート'), findsOneWidget);
    await tester.tap(find.text('取り込む'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('無効なバックアップデータです'), findsOneWidget);
  });
}
