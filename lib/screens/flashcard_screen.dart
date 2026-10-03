import 'dart:async';

import 'package:flutter/material.dart';

import '../db/progress_store.dart';
import '../models/word.dart';
import '../srs/srs_scheduler.dart';
import '../stats/stats_store.dart';

typedef ScheduleFn = SrsCard Function(SrsCard card, Grade grade, DateTime now);

class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({
    super.key,
    required this.store,
    required this.words,
    this.stats,
    this.initialCards = const [],
    this.now,
    this.scheduleFn = schedule,
  });

  final ProgressStore store;
  final List<Word> words;
  final StatsStore? stats;
  final List<SrsCard> initialCards;
  final DateTime Function()? now;
  final ScheduleFn scheduleFn;

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  int _index = 0;
  bool _revealed = false;
  bool _saving = false;
  bool _recorded = false;
  late final Map<String, SrsCard> _cards;

  @override
  void initState() {
    super.initState();
    _cards = {for (final c in widget.initialCards) c.wordId: c};
  }

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  Future<void> _grade(Grade grade) async {
    if (_saving || _index >= widget.words.length) return;
    setState(() => _saving = true);
    try {
      final word = widget.words[_index];
      final now = _now();
      final current = _cards[word.id] ??
          SrsCard(
            wordId: word.id,
            interval: Duration.zero,
            ease: 2.5,
            dueDate: now,
          );
      final next = widget.scheduleFn(current, grade, now);
      _cards[word.id] = next;
      await widget.store.upsert(next);
      final isLast = _index + 1 >= widget.words.length;
      if (isLast && !_recorded) {
        _recorded = true;
        // Fire-and-forget: stats must not block session completion.
        final pending = widget.stats?.recordStudy(now);
        if (pending != null) unawaited(pending);
      }
      if (!mounted) return;
      setState(() {
        _index += 1;
        _revealed = false;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('学習')),
      body: Center(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (widget.words.isEmpty) {
      return const Text('学習する単語がありません');
    }
    if (_index >= widget.words.length) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('学習完了！'),
          Text('お疲れさまでした'),
        ],
      );
    }
    final word = widget.words[_index];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${_index + 1} / ${widget.words.length} 枚'),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => setState(() => _revealed = !_revealed),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(word.korean, style: const TextStyle(fontSize: 32)),
                    Text(word.reading),
                    if (!_revealed) const Text('タップして意味を見る'),
                    if (_revealed) ...[
                      const SizedBox(height: 12),
                      Text(word.meaningJa,
                          style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 8),
                      Text(word.exampleKo),
                      Text(word.exampleJa),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_revealed)
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _saving ? null : () => _grade(Grade.again),
                  child: const Text('もう一度'),
                ),
                ElevatedButton(
                  onPressed: _saving ? null : () => _grade(Grade.hard),
                  child: const Text('難しい'),
                ),
                ElevatedButton(
                  onPressed: _saving ? null : () => _grade(Grade.good),
                  child: const Text('普通'),
                ),
                ElevatedButton(
                  onPressed: _saving ? null : () => _grade(Grade.easy),
                  child: const Text('簡単'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
