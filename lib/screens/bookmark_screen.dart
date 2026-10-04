import 'package:flutter/material.dart';

import '../data/word_repository.dart';
import '../models/word.dart';
import '../stats/bookmark_store.dart';
import '../stats/error_stats.dart';
import '../stats/stats_store.dart';
import 'quiz_screen.dart';

class BookmarkScreen extends StatefulWidget {
  const BookmarkScreen({
    super.key,
    required this.bookmarks,
    this.stats,
    this.errors,
    this.loadWords = loadWordsForLevel,
    this.levels = const [1, 2, 3, 4, 5, 6],
    this.now,
  });

  final BookmarkStore bookmarks;
  final StatsStore? stats;
  final ErrorStatsStore? errors;
  final Future<List<Word>> Function(int level) loadWords;
  final List<int> levels;
  final DateTime Function()? now;

  @override
  State<BookmarkScreen> createState() => _BookmarkScreenState();
}

class _BookmarkScreenState extends State<BookmarkScreen> {
  late Future<List<Word>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Word>> _load() async {
    final ids = await widget.bookmarks.allIds();
    if (ids.isEmpty) return const [];
    final wanted = ids.toSet();
    final found = <String, Word>{};
    for (final level in widget.levels) {
      List<Word> words;
      try {
        words = await widget.loadWords(level);
      } catch (_) {
        continue;
      }
      for (final w in words) {
        if (wanted.contains(w.id)) found[w.id] = w;
      }
      if (found.length >= wanted.length) break;
    }
    return [for (final id in ids) if (found.containsKey(id)) found[id]!];
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  void _startReviewQuiz(List<Word> words) {
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
      appBar: AppBar(title: const Text('ブックマーク')),
      body: FutureBuilder<List<Word>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('読み込みに失敗しました'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final words = snapshot.data!;
          if (words.isEmpty) {
            return const Center(
              child: Text('ブックマークはまだありません\n単語カードの☆から保存できます'),
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text('保存済み: ${words.length}語'),
                    const Spacer(),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.quiz, size: 18),
                      label: const Text('ブックマーククイズ'),
                      onPressed: () => _startReviewQuiz(words),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: words.length,
                  itemBuilder: (context, i) {
                    final w = words[i];
                    return ListTile(
                      title: Text(w.korean),
                      subtitle: Text(w.meaningJa),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: '削除',
                        onPressed: () async {
                          await widget.bookmarks.remove(w.id);
                          await _refresh();
                        },
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
