import 'dart:math';

import 'package:flutter/material.dart';

import '../data/word_repository.dart';
import '../i18n/app_locale.dart';
import '../i18n/app_strings.dart';
import '../models/word.dart';
import '../quiz/quiz_generator.dart';

/// Sentence-fill mini-game: pick the word that completes the example.
class SentenceFillScreen extends StatefulWidget {
  const SentenceFillScreen({
    super.key,
    this.words = const [],
    this.locale = AppLocale.japanese,
    this.rounds = 5,
    this.level = 1,
    this.loadWords = loadWordsForLevel,
    this.rng,
  });

  final List<Word> words;
  final AppLocale locale;
  final int rounds;
  final int level;
  final Future<List<Word>> Function(int level) loadWords;
  final Random? rng;

  @override
  State<SentenceFillScreen> createState() => _SentenceFillScreenState();
}

class _SentenceFillScreenState extends State<SentenceFillScreen> {
  late final Future<void> _boot;
  final _questions = <QuizQuestion>[];
  int _index = 0;
  int _score = 0;
  int _mistakes = 0;
  bool _answered = false;
  int? _picked;

  @override
  void initState() {
    super.initState();
    _boot = _start();
  }

  Future<void> _start() async {
    final source = List<Word>.of(widget.words);
    if (source.length < 4) {
      try {
        source.addAll(await widget.loadWords(widget.level));
      } catch (_) {}
    }
    final rng = widget.rng ?? Random();
    final shuffled = source..shuffle(rng);
    for (final word in shuffled) {
      if (_questions.length >= widget.rounds) break;
      if (_questions.any((q) => q.wordId == word.id)) continue;
      try {
        final q = makeBlankQuestion(word, shuffled, rng);
        if (q != null) _questions.add(q);
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  void _answer(int i) {
    if (_answered) return;
    final correct = i == _questions[_index].correctIndex;
    setState(() {
      _answered = true;
      _picked = i;
      if (correct) {
        _score += 100;
      } else {
        _mistakes += 1;
      }
    });
  }

  void _next() {
    setState(() {
      _index += 1;
      _answered = false;
      _picked = null;
    });
  }

  bool get _complete => _index >= _questions.length;

  @override
  Widget build(BuildContext context) {
    final locale = widget.locale;
    return Scaffold(
      appBar: AppBar(title: Text(tr(locale, 'game2.title'))),
      body: FutureBuilder<void>(
        future: _boot,
        builder: (context, snapshot) {
          if (_questions.isEmpty &&
              snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_questions.isEmpty) {
            return Center(child: Text(tr(locale, 'game2.empty')));
          }
          if (_complete) {
            return Center(
              child: Text(
                trParams(locale, 'game2.clear',
                    {'s': _score, 'm': _mistakes}),
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold),
              ),
            );
          }
          final q = _questions[_index];
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(trParams(locale, 'game2.progress',
                    {'i': _index + 1, 'n': _questions.length})),
                const SizedBox(height: 8),
                Text(trParams(locale, 'game2.score', {'n': _score})),
                const SizedBox(height: 24),
                Text(q.prompt, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 24),
                for (var i = 0; i < q.options.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: !_answered
                            ? null
                            : i == q.correctIndex
                                ? Colors.green
                                : i == _picked
                                    ? Colors.red
                                    : null,
                        foregroundColor: !_answered ? null : Colors.white,
                      ),
                      onPressed: () => _answer(i),
                      child: Text(q.options[i]),
                    ),
                  ),
                const SizedBox(height: 16),
                if (_answered)
                  ElevatedButton(
                    onPressed: _next,
                    child: Text(tr(locale, 'game2.next')),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
