import 'package:flutter/material.dart';

import '../data/word_repository.dart';
import '../db/progress_store.dart';
import '../models/word.dart';
import 'flashcard_screen.dart';
import 'quiz_screen.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({
    super.key,
    required this.store,
    this.levels = const [1, 2],
    this.loadWords = loadWordsForLevel,
  });

  final ProgressStore store;
  final List<int> levels;
  final Future<List<Word>> Function(int level) loadWords;

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  late final Future<Map<int, List<Word>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<int, List<Word>>> _load() async {
    final entries = <int, List<Word>>{};
    for (final level in widget.levels) {
      entries[level] = await widget.loadWords(level);
    }
    return entries;
  }

  void _startFlashcards(List<Word> words) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FlashcardScreen(store: widget.store, words: words),
      ),
    );
  }

  void _startQuiz(List<Word> words) {
    // QuizScreen generates 4-option questions in initState and throws for
    // pools of 1-3 words, so gate here; empty pools are safe (message state).
    if (words.isNotEmpty && words.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('クイズには4語以上必要です')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => QuizScreen(words: words)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('レベル選択')),
      body: FutureBuilder<Map<int, List<Word>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('読み込みに失敗しました'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final byLevel = snapshot.data!;
          return ListView(
            children: [
              for (final level in widget.levels)
                ListTile(
                  title: Text('TOPIK $level級'),
                  subtitle: Text('${byLevel[level]!.length}語'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => _startFlashcards(byLevel[level]!),
                        child: const Text('学習する'),
                      ),
                      TextButton(
                        onPressed: () => _startQuiz(byLevel[level]!),
                        child: const Text('クイズ'),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
