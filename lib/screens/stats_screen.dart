import 'package:flutter/material.dart';

import '../data/word_repository.dart';
import '../db/progress_store.dart';
import '../models/word.dart';
import '../quiz/adaptive_selector.dart';
import '../srs/srs_scheduler.dart';
import '../stats/achievements.dart';
import '../stats/bookmark_store.dart';
import '../stats/error_stats.dart';
import '../stats/learning_analytics.dart';
import '../stats/stats_store.dart';
import 'quiz_screen.dart';
import 'review_screen.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({
    super.key,
    required this.store,
    this.stats,
    this.errors,
    this.bookmarks,
    this.levels = const [1, 2, 3, 4, 5, 6],
    this.loadWords = loadWordsForLevel,
    this.now,
  });

  final ProgressStore store;
  final StatsStore? stats;
  final ErrorStatsStore? errors;
  final BookmarkStore? bookmarks;
  final List<int> levels;
  final Future<List<Word>> Function(int level) loadWords;
  final DateTime Function()? now;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsData {
  final Map<int, int> totalByLevel;
  final Map<int, int> learnedByLevel;
  final int streak;
  final List<WeakItem> weak;
  final List<bool> week;
  final List<bool> month;
  final List<SessionRecord> sessions;
  final Set<String> achievements;

  const _StatsData({
    required this.totalByLevel,
    required this.learnedByLevel,
    required this.streak,
    required this.weak,
    required this.week,
    this.month = const [],
    this.sessions = const [],
    this.achievements = const {},
  });
}

double _averageRate(List<SessionRecord> sessions) {
  if (sessions.isEmpty) return 0.0;
  return sessions.map((s) => s.rate).reduce((a, b) => a + b) /
      sessions.length;
}

/// Line chart of recent session accuracy rates (0.0..1.0, oldest first).
class _TrendPainter extends CustomPainter {
  _TrendPainter(this.rates);
  final List<double> rates;

  @override
  void paint(Canvas canvas, Size size) {
    if (rates.isEmpty) return;
    final line = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final dot = Paint()..color = Colors.blue;
    double x(int i) =>
        rates.length == 1 ? size.width / 2 : i * size.width / (rates.length - 1);
    double y(double r) => size.height - (r.clamp(0.0, 1.0) * size.height);
    final path = Path();
    for (var i = 0; i < rates.length; i++) {
      final p = Offset(x(i), y(rates[i]));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path, line);
    for (var i = 0; i < rates.length; i++) {
      canvas.drawCircle(Offset(x(i), y(rates[i])), 3, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => old.rates != rates;
}

class _StatsScreenState extends State<StatsScreen> {
  late final Future<_StatsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_StatsData> _load() async {
    final totalByLevel = <int, int>{};
    for (final level in widget.levels) {
      try {
        totalByLevel[level] = (await widget.loadWords(level)).length;
      } catch (_) {
        totalByLevel[level] = 0;
      }
    }
    final learnedByLevel = <int, int>{};
    for (final level in widget.levels) {
      try {
        final cards = await widget.store.allCardsForLevel(level).timeout(
              const Duration(seconds: 2),
              onTimeout: () => <SrsCard>[],
            );
        learnedByLevel[level] = cards.length;
      } catch (_) {
        learnedByLevel[level] = 0;
      }
    }
    int streak = 0;
    try {
      streak = await (widget.stats
              ?.displayStreak(widget.now?.call() ?? DateTime.now())
              .timeout(const Duration(seconds: 2), onTimeout: () => 0) ??
          Future.value(0));
    } catch (_) {
      streak = 0;
    }
    List<WeakItem> weak = const [];
    try {
      weak = await (widget.errors
              ?.topWeak(limit: 5).timeout(const Duration(seconds: 2), onTimeout: () => <WeakItem>[]) ??
          Future.value(const <WeakItem>[]));
    } catch (_) {
      weak = const [];
    }
    List<bool> week = const [false, false, false, false, false, false, false];
    try {
      week = await (widget.stats
              ?.last7Days(widget.now?.call() ?? DateTime.now())
              .timeout(const Duration(seconds: 2), onTimeout: () => week) ??
          Future.value(week));
    } catch (_) {
      week = const [false, false, false, false, false, false, false];
    }
    var month = const <bool>[];
    try {
      month = await (widget.stats
              ?.last30Days(widget.now?.call() ?? DateTime.now())
              .timeout(const Duration(seconds: 2), onTimeout: () => month) ??
          Future.value(month));
    } catch (_) {
      month = const <bool>[];
    }
    var sessions = const <SessionRecord>[];
    try {
      sessions = await (widget.stats
              ?.recentSessions(10)
              .timeout(const Duration(seconds: 2), onTimeout: () => sessions) ??
          Future.value(sessions));
    } catch (_) {
      sessions = const <SessionRecord>[];
    }
    var achievements = const <String>{};
    try {
      achievements = await (widget.stats
              ?.unlockedAchievements()
              .timeout(const Duration(seconds: 2), onTimeout: () => achievements) ??
          Future.value(achievements));
    } catch (_) {
      achievements = const <String>{};
    }
    return _StatsData(
      totalByLevel: totalByLevel,
      learnedByLevel: learnedByLevel,
      streak: streak,
      weak: weak,
      week: week,
      month: month,
      sessions: sessions,
      achievements: achievements,
    );
  }

  void _openReview(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReviewScreen(
          errors: widget.errors ?? ErrorStatsStore(),
          stats: widget.stats,
          bookmarks: widget.bookmarks,
          levels: widget.levels,
          loadWords: widget.loadWords,
          now: widget.now,
        ),
      ),
    );
  }

  Future<void> _startLevelReview(
      BuildContext context, int level, List<WeakItem> weak) async {
    List<Word> words;
    try {
      words = await widget.loadWords(level);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('単語の読み込みに失敗しました')),
      );
      return;
    }
    if (words.length < 4) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('クイズには4語以上必要です')),
      );
      return;
    }
    final rates = ratesForWords(
      words: words,
      weakRates: weak.map((w) => (key: w.key, rate: w.errorRate)).toList(),
    );
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          words: List<Word>.of(words),
          stats: widget.stats,
          errors: widget.errors,
          bookmarks: widget.bookmarks,
          weakRates: rates.isEmpty ? null : rates,
          level: level,
          now: widget.now,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('学習統計')),
      body: FutureBuilder<_StatsData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('読み込みに失敗しました'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final totalLearned =
              data.learnedByLevel.values.fold<int>(0, (a, b) => a + b);
          final totalWords =
              data.totalByLevel.values.fold<int>(0, (a, b) => a + b);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('連続学習: ${data.streak}日',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('学習済み: $totalLearned / $totalWords 語'),
                const SizedBox(height: 16),
                const Text('週間レポート',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < 7; i++)
                      Column(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: data.week[i]
                                  ? Colors.green[400]
                                  : Colors.grey[300],
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              last7WeekdayLabels(widget.now?.call() ??
                                  DateTime.now())[i],
                              style: TextStyle(
                                color: data.week[i]
                                    ? Colors.white
                                    : Colors.grey[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                Text(
                    '今週: ${data.week.where((d) => d).length} / 7 日学習'),
                const SizedBox(height: 16),
                const Text('月間レポート',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (data.month.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final studied in data.month)
                        Expanded(
                          child: Container(
                            height: studied ? 40 : 8,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: studied
                                  ? Colors.green[400]
                                  : Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                      '30日: ${data.month.where((d) => d).length} / 30 日学習'),
                  const SizedBox(height: 16),
                ],
                const Text('正答率の推移',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (data.sessions.length < 2)
                  const Text('セッション記録はまだありません')
                else ...[
                  SizedBox(
                    height: 80,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _TrendPainter(
                        [for (final s in data.sessions) s.rate],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '直近${data.sessions.length}回平均: '
                    '${(_averageRate(data.sessions) * 100).round()}%',
                  ),
                  const SizedBox(height: 16),
                ],
                const Text('実績バッジ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    for (final def in allAchievements)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: data.achievements.contains(def.id)
                              ? Colors.amber[100]
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              data.achievements.contains(def.id)
                                  ? '🏅'
                                  : '🔒',
                              style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              def.title,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('レベル別進捗',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                for (final level in widget.levels)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                  'TOPIK $level級: ${data.learnedByLevel[level] ?? 0} / ${data.totalByLevel[level] ?? 0}'),
                            ),
                            TextButton(
                              onPressed: () => _startLevelReview(
                                  context, level, data.weak),
                              child: const Text('復習'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: (data.totalByLevel[level] ?? 0) == 0
                              ? 0.0
                              : (data.learnedByLevel[level] ?? 0) /
                                  (data.totalByLevel[level] ?? 1),
                          minHeight: 6,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('苦手トップ5',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _openReview(context),
                      child: const Text('間違いノート'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (data.weak.isEmpty)
                  const Text('苦手データはまだありません')
                else
                  for (final w in data.weak)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                          '${w.key}（ミス ${w.errors}/${w.attempts}）'),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}
