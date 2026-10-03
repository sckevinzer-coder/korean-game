import 'package:flutter/material.dart';

import '../data/word_repository.dart';
import '../db/progress_store.dart';
import '../models/word.dart';

typedef WordsLoader = Future<List<Word>> Function(int level);

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.store,
    this.level = 1,
    this.streak = 0,
    this.loadWords = loadWordsForLevel,
    this.now,
  });

  final ProgressStore store;
  final int level;
  final int streak;
  final WordsLoader loadWords;
  final DateTime Function()? now;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _Counts {
  const _Counts(this.due, this.total);
  final int due;
  final int total;
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
    final due = (await widget.store.dueCards(now)).length;
    final total = (await widget.loadWords(widget.level)).length;
    return _Counts(due, total);
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
                Text('連続学習: ${widget.streak}日'),
              ],
            );
          },
        ),
      ),
    );
  }
}
