import 'package:flutter/material.dart';

import '../data/word_repository.dart';
import '../models/word.dart';
import '../quiz/quiz_generator.dart';
import '../stats/bookmark_store.dart';
import '../stats/error_stats.dart';
import '../stats/learning_analytics.dart';
import '../stats/stats_store.dart';
import 'quiz_screen.dart';

/// One notebook entry: the word plus its mistake record.
class ReviewEntry {
  const ReviewEntry({required this.word, required this.weak});

  final Word word;
  final WeakItem weak;
}

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.errors,
    this.stats,
    this.bookmarks,
    this.loadWords = loadWordsForLevel,
    this.levels = const [1, 2, 3, 4, 5, 6],
    this.now,
  });

  final ErrorStatsStore errors;
  final StatsStore? stats;
  final BookmarkStore? bookmarks;
  final Future<List<Word>> Function(int level) loadWords;
  final List<int> levels;
  final DateTime Function()? now;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late final Future<List<ReviewEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  static String _answerOf(String key) {
    final sep = key.indexOf(':');
    return sep < 0 ? key : key.substring(sep + 1);
  }

  static String? _kindLabelOf(String key) {
    final sep = key.indexOf(':');
    if (sep < 0) return null;
    final kind = QuizKind.values.asNameMap()[key.substring(0, sep)];
    if (kind == null) return null;
    return kindLabel(kind);
  }

  Future<List<ReviewEntry>> _load() async {
    final weak = await widget.errors.topWeak(limit: 20);
    if (weak.isEmpty) return const [];
    final entries = <ReviewEntry>[];
    final seen = <String>{};
    for (final level in widget.levels) {
      List<Word> words;
      try {
        words = await widget.loadWords(level);
      } catch (_) {
        continue;
      }
      final byAnswer = <String, Word>{};
      for (final w in words) {
        byAnswer.putIfAbsent(w.korean, () => w);
        byAnswer.putIfAbsent(w.meaningJa, () => w);
      }
      for (final item in weak) {
        final answer = _answerOf(item.key);
        final word = byAnswer[answer];
        if (word != null && seen.add(word.id)) {
          entries.add(ReviewEntry(word: word, weak: item));
        }
      }
      if (seen.length >= weak.length) break;
    }
    // Keep error-rank order.
    final order = <String, int>{
      for (var i = 0; i < weak.length; i++) _answerOf(weak[i].key): i,
    };
    entries.sort((a, b) => order[_answerOf(a.weak.key)]!
        .compareTo(order[_answerOf(b.weak.key)]!));
    return entries;
  }

  void _startReviewQuiz(List<ReviewEntry> entries) {
    final words = [for (final e in entries) e.word];
    if (words.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('クイズには4語以上必要です')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          words: List<Word>.of(words)..shuffle(),
          stats: widget.stats,
          errors: widget.errors,
          bookmarks: widget.bookmarks,
          now: widget.now,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('間違いノート')),
      body: FutureBuilder<List<ReviewEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('読み込みに失敗しました'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data!;
          if (entries.isEmpty) {
            return const Center(child: Text('間違い記録はまだありません'));
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text('記録: ${entries.length}語'),
                    const Spacer(),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.quiz, size: 18),
                      label: const Text('復習クイズ'),
                      onPressed: () => _startReviewQuiz(entries),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, i) {
                    final entry = entries[i];
                    final kindLabel = _kindLabelOf(entry.weak.key);
                    final rate =
                        (entry.weak.errorRate * 100).round();
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.word.korean,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  'ミス ${entry.weak.errors}/${entry.weak.attempts}',
                                  style: TextStyle(
                                    color: Colors.red[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Text(entry.word.meaningJa),
                            const SizedBox(height: 4),
                            Text(
                              entry.word.exampleKo,
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              [
                                ?kindLabel,
                                '正答率 ${100 - rate}%',
                              ].join(' · '),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
