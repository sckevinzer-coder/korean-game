import 'package:flutter/material.dart';

import '../data/word_repository.dart';
import '../db/progress_store.dart';
import '../models/word.dart';
import '../stats/stats_store.dart';
import 'level_select_screen.dart';

typedef WordsLoader = Future<List<Word>> Function(int level);

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.store,
    this.stats,
    this.level = 1,
    this.loadWords = loadWordsForLevel,
    this.now,
  });

  final ProgressStore store;
  final StatsStore? stats;
  final int level;
  final WordsLoader loadWords;
  final DateTime Function()? now;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _Counts {
  const _Counts(this.due, this.total, this.streak);
  final int due;
  final int total;
  final int streak;
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<_Counts> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Counts> _load() async {
    final now = widget.now?.call() ?? DateTime.now();
    // Dispatch concurrently: awaiting FFI stores one by one stalls
    // completion inside the widget test zone.
    final dueFuture = widget.store.dueCards(now);
    final wordsFuture = widget.loadWords(widget.level);
    final knownFuture = widget.store.allCardsForLevel(widget.level);
    final stats = widget.stats;
    final streakFuture =
        stats == null ? Future<int>.value(0) : stats.displayStreak(now);
    final dueCards = await dueFuture;
    final words = await wordsFuture;
    final knownIds =
        (await knownFuture).map((c) => c.wordId).toSet();
    final total = words.length;
    final unstudied = words.where((w) => !knownIds.contains(w.id)).length;
    final due = dueCards.length + unstudied;
    final streak = await streakFuture;
    return _Counts(due, total, streak);
  }

  void _openLevels() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LevelSelectScreen(
          store: widget.store,
          stats: widget.stats,
          loadWords: widget.loadWords,
          now: widget.now,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ホーム')),
      body: Center(
        child: FutureBuilder<_Counts>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('読み込みに失敗しました');
            }
            if (!snapshot.hasData) {
              return const CircularProgressIndicator();
            }
            final counts = snapshot.data!;
            return Column(
              mainAxisAlignment: .center,
              children: [
                Text('今日の復習: ${counts.due} / ${counts.total} 枚'),
                Text('連続学習: ${counts.streak}日'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _openLevels,
                  child: const Text('レベルを選ぶ'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
