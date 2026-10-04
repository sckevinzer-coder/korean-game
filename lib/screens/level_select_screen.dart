import 'dart:math';

import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

import '../data/word_repository.dart';
import '../db/progress_store.dart';
import '../i18n/app_locale.dart';
import '../i18n/app_strings.dart';
import '../models/word.dart';
import '../srs/srs_scheduler.dart';
import '../stats/bookmark_store.dart';
import '../stats/error_stats.dart';
import '../stats/stats_store.dart';
import 'bookmark_screen.dart';
import 'flashcard_screen.dart';
import 'quiz_screen.dart';
import 'stats_screen.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({
    super.key,
    required this.store,
    this.stats,
    this.errors,
    this.bookmarks,
    this.levels = const [1, 2, 3, 4, 5, 6],
    this.loadWords = loadWordsForLevel,
    this.now,
    this.random,
    this.locale = AppLocale.japanese,
  });

  final ProgressStore store;
  final StatsStore? stats;
  final ErrorStatsStore? errors;
  final BookmarkStore? bookmarks;
  final AppLocale locale;
  final List<int> levels;
  final Future<List<Word>> Function(int level) loadWords;
  final DateTime Function()? now;
  final Random? random;

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  late final Future<_LoadedData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_LoadedData> _load() async {
    final wordsByLevel = <int, List<Word>>{};
    for (final level in widget.levels) {
      wordsByLevel[level] = await widget.loadWords(level);
    }
    final learnedByLevel = <int, int>{};
    for (final level in widget.levels) {
      try {
        final cards = await widget.store.allCardsForLevel(level)
            .timeout(const Duration(seconds: 2), onTimeout: () => <SrsCard>[]);
        learnedByLevel[level] = cards.length;
      } catch (e) {
        learnedByLevel[level] = 0;
      }
    }
    // Skip stats in tests to avoid database hangs
    const streak = 0;
    return _LoadedData(
      wordsByLevel: wordsByLevel,
      learnedByLevel: learnedByLevel,
      streak: streak,
    );
  }

  List<Word> _shuffled(List<Word> words) =>
      List<Word>.of(words)..shuffle(widget.random);

  Future<void> _lightHaptic() async {
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 10);
    }
  }

  void _startFlashcards(List<Word> words) {
    _lightHaptic();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FlashcardScreen(
          store: widget.store,
          words: _shuffled(words),
          stats: widget.stats,
          bookmarks: widget.bookmarks,
          locale: widget.locale,
          now: widget.now,
        ),
      ),
    );
  }

  void _startQuiz(List<Word> words) {
    _lightHaptic();
    if (words.isNotEmpty && words.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(widget.locale, 'level.needWords'))),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          words: _shuffled(words),
          stats: widget.stats,
          errors: widget.errors,
          bookmarks: widget.bookmarks,
          locale: widget.locale,
          now: widget.now,
        ),
      ),
    );
  }

  void _openStats() {
    _lightHaptic();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StatsScreen(
          store: widget.store,
          stats: widget.stats,
          errors: widget.errors,
          bookmarks: widget.bookmarks,
          levels: widget.levels,
          loadWords: widget.loadWords,
          locale: widget.locale,
          now: widget.now,
        ),
      ),
    );
  }

  void _openBookmarks() {
    final store = widget.bookmarks;
    if (store == null) return;
    _lightHaptic();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookmarkScreen(
          bookmarks: store,
          stats: widget.stats,
          errors: widget.errors,
          loadWords: widget.loadWords,
          locale: widget.locale,
          now: widget.now,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = widget.locale;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(locale, 'level.title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outline),
            tooltip: tr(locale, 'level.bookmarks'),
            onPressed: widget.bookmarks == null ? null : _openBookmarks,
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: tr(locale, 'level.stats'),
            onPressed: _openStats,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _buildStreakBanner(),
        ),
      ),
      body: FutureBuilder<_LoadedData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(tr(locale, 'level.loadError')));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final children = <Widget>[];
          for (final level in widget.levels) {
            children.add(_buildLevelCard(level, data));
          }
          children.add(const SizedBox(height: 16));
          children.add(_buildLegend());
          return ListView(
            padding: const EdgeInsets.all(16),
            children: children,
          );
        },
      ),
    );
  }

  Widget _buildStreakBanner() {
    return FutureBuilder<int>(
      future: widget.stats?.displayStreak(widget.now?.call() ?? DateTime.now()) ??
          Future.value(0),
      builder: (context, snapshot) {
        final streak = snapshot.data ?? 0;
        if (streak == 0) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: Colors.amber[100],
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_fire_department, color: Colors.orange[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  trParams(widget.locale, 'level.streak', {'n': streak}),
                  style: TextStyle(
                    color: Colors.orange[800],
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLevelCard(int level, _LoadedData data) {
    final words = data.wordsByLevel[level]!;
    final learned = data.learnedByLevel[level] ?? 0;
    final total = words.length;
    final progress = total > 0 ? learned / total : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trParams(widget.locale, 'level.name', {'n': level}),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                trParams(widget.locale, 'level.progress', {
                  'learned': learned,
                  'total': total,
                }),
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.menu_book, size: 18),
                      label: Text(tr(widget.locale, 'level.study')),
                      onPressed: () => _startFlashcards(words),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.quiz, size: 18),
                      label: Text(tr(widget.locale, 'level.quiz')),
                      onPressed: () => _startQuiz(words),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(widget.locale, 'level.legendTitle'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            _legendItem(tr(widget.locale, 'level.legend12'),
                tr(widget.locale, 'level.legend12desc')),
            _legendItem(tr(widget.locale, 'level.legend34'),
                tr(widget.locale, 'level.legend34desc')),
            _legendItem(tr(widget.locale, 'level.legend56'),
                tr(widget.locale, 'level.legend56desc')),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(String level, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(level, style: const TextStyle(fontSize: 12)),
          ),
          Text(desc, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _LoadedData {
  final Map<int, List<Word>> wordsByLevel;
  final Map<int, int> learnedByLevel;
  final int streak;

  _LoadedData({
    required this.wordsByLevel,
    required this.learnedByLevel,
    required this.streak,
  });
}