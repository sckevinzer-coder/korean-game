import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/word_repository.dart';
import '../db/progress_store.dart';
import '../models/word.dart';
import '../i18n/app_locale.dart';
import '../i18n/app_strings.dart';
import '../quiz/adaptive_selector.dart';
import '../srs/srs_scheduler.dart';
import '../stats/achievements.dart';
import '../stats/bookmark_store.dart';
import '../stats/data_transfer.dart';
import '../tts/tts_cache.dart';
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
    this.locale = AppLocale.japanese,
  });

  final ProgressStore store;
  final StatsStore? stats;
  final ErrorStatsStore? errors;
  final BookmarkStore? bookmarks;
  final List<int> levels;
  final Future<List<Word>> Function(int level) loadWords;
  final DateTime Function()? now;
  final AppLocale locale;

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

  Future<void> _exportData(BuildContext context) async {
    final stats = widget.stats;
    if (stats == null) return;
    String json;
    try {
      json = await exportJson(
        stats: stats,
        errors: widget.errors,
        bookmarks: widget.bookmarks,
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(widget.locale, 'stats.exportError'))),
      );
      return;
    }
    if (!context.mounted) return;
    final locale = widget.locale;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(locale, 'stats.exportTitle')),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(child: Text(json)),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: json));
              if (context.mounted) Navigator.of(context).pop();
            },
            child: Text(tr(locale, 'stats.copy')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr(locale, 'stats.close')),
          ),
        ],
      ),
    );
  }

  Future<void> _importData(BuildContext context) async {
    final stats = widget.stats;
    if (stats == null) return;
    final json = await showDialog<String>(
      context: context,
      builder: (context) => _ImportDialog(locale: widget.locale),
    );
    if (json == null || json.trim().isEmpty) return;
    TransferSummary? summary;
    try {
      summary = await importJson(
        json,
        stats: stats,
        errors: widget.errors,
        bookmarks: widget.bookmarks,
      );
    } catch (_) {
      summary = null;
    }
    // Defer past the dialog pop transition to avoid overlay races.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        summary == null
            ? SnackBar(content: Text(tr(widget.locale, 'stats.importError')))
            : SnackBar(
                content: Text(trParams(widget.locale, 'stats.importDone', {
                  'd': summary.days,
                  's': summary.sessions,
                })),
              ),
      );
    });
  }

  Future<void> _clearTtsCache(BuildContext context) async {
    final removed = await CachedTtsService.clearDefaultCache();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            trParams(widget.locale, 'cache.cleared', {'n': removed})),
      ),
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
          locale: widget.locale,
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
        SnackBar(content: Text(tr(widget.locale, 'stats.wordsLoadError'))),
      );
      return;
    }
    if (words.length < 4) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(widget.locale, 'stats.needWords'))),
      );
      return;
    }
    final rates = ratesForWords(
      words: words,
      weakRates: weak.map((w) => (key: w.key, rate: w.errorRate)).toList(),
    );
    var lenientGrading = false;
    try {
      lenientGrading = await (widget.stats
              ?.getLenientGrading()
              .timeout(const Duration(seconds: 2), onTimeout: () => false) ??
          Future.value(false));
    } catch (_) {
      lenientGrading = false;
    }
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
          lenientGrading: lenientGrading,
          now: widget.now,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = widget.locale;
    return Scaffold(
      appBar: AppBar(title: Text(tr(locale, 'stats.title'))),
      body: FutureBuilder<_StatsData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(tr(locale, 'stats.loadError')));
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
                Text(trParams(locale, 'stats.streak', {'n': data.streak}),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(trParams(locale, 'stats.total', {
                  'a': totalLearned,
                  'b': totalWords,
                })),
                const SizedBox(height: 16),
                Text(tr(locale, 'stats.weekly'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
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
                              last7WeekdayLabels(
                                  widget.now?.call() ?? DateTime.now(),
                                  locale)[i],
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
                Text(trParams(locale, 'stats.weekCount', {
                  'n': data.week.where((d) => d).length,
                })),
                const SizedBox(height: 16),
                Text(tr(locale, 'stats.monthly'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
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
                  Text(trParams(locale, 'stats.monthCount', {
                    'n': data.month.where((d) => d).length,
                  })),
                  const SizedBox(height: 16),
                ],
                Text(tr(locale, 'stats.trend'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (data.sessions.length < 2)
                  Text(tr(locale, 'stats.noSessions'))
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
                  Text(trParams(locale, 'stats.recentAvg', {
                    'n': data.sessions.length,
                    'p': (_averageRate(data.sessions) * 100).round(),
                  })),
                  const SizedBox(height: 16),
                ],
                Text(tr(locale, 'stats.badges'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
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
                              def.titleFor(locale),
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
                Text(tr(locale, 'stats.levels'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
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
                              child: Text(trParams(locale, 'stats.levelRow', {
                                'l': level,
                                'a': data.learnedByLevel[level] ?? 0,
                                'b': data.totalByLevel[level] ?? 0,
                              })),
                            ),
                            TextButton(
                              onPressed: () => _startLevelReview(
                                  context, level, data.weak),
                              child: Text(tr(locale, 'stats.review')),
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
                    Text(tr(locale, 'stats.weak'),
                        style:
                            const TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _openReview(context),
                      child: Text(tr(locale, 'stats.notebook')),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (data.weak.isEmpty)
                  Text(tr(locale, 'stats.noWeak'))
                else
                  for (final w in data.weak)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(trParams(locale, 'stats.weakRow', {
                        'key': w.key,
                        'e': w.errors,
                        'a': w.attempts,
                      })),
                    ),
                const SizedBox(height: 16),
                Text(tr(locale, 'stats.dataTitle'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.upload, size: 18),
                        label: Text(tr(locale, 'stats.export')),
                        onPressed: () => _exportData(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.download, size: 18),
                        label: Text(tr(locale, 'stats.import')),
                        onPressed: () => _importData(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.cleaning_services, size: 18),
                    label: Text(tr(locale, 'cache.clear')),
                    onPressed: () => _clearTtsCache(context),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Import dialog owning its TextEditingController lifecycle.
class _ImportDialog extends StatefulWidget {
  const _ImportDialog({required this.locale});

  final AppLocale locale;

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = widget.locale;
    return AlertDialog(
      title: Text(tr(locale, 'stats.importTitle')),
      content: TextField(
        controller: _controller,
        maxLines: 6,
        decoration: InputDecoration(
          hintText: tr(locale, 'stats.importHint'),
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr(locale, 'stats.cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(tr(locale, 'stats.doImport')),
        ),
      ],
    );
  }
}
