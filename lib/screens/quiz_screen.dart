import 'dart:math';

import 'package:flutter/material.dart';

import '../models/word.dart';
import '../quiz/quiz_generator.dart';

typedef QuestionBuilder = QuizQuestion Function(Word target, List<Word> pool);

class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.words,
    this.questions,
    this.rng,
    this.questionBuilder,
  });

  final List<Word> words;
  final List<QuizQuestion>? questions;
  final Random? rng;
  final QuestionBuilder? questionBuilder;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late final List<QuizQuestion> _questions;
  int _index = 0;
  int _score = 0;
  int? _selected;

  @override
  void initState() {
    super.initState();
    _questions = widget.questions ?? _generate(widget.rng ?? Random());
  }

  List<QuizQuestion> _generate(Random rng) {
    final kinds = QuizKind.values;
    return [
      for (var i = 0; i < widget.words.length; i++)
        (widget.questionBuilder ??
                (target, pool) =>
                    makeQuestion(target, pool, kinds[i % kinds.length], rng))(
          widget.words[i],
          widget.words,
        ),
    ];
  }

  void _answer(int selected) {
    if (_selected != null) return;
    setState(() {
      _selected = selected;
      if (selected == _questions[_index].correctIndex) _score += 1;
    });
  }

  void _next() {
    setState(() {
      _index += 1;
      _selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('クイズ')),
      body: Center(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (widget.words.isEmpty || _questions.isEmpty) {
      return const Text('クイズにする単語がありません');
    }
    if (_index >= _questions.length) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('クイズ完了！'),
          Text('スコア: $_score / ${_questions.length}'),
          const Text('お疲れさまでした'),
        ],
      );
    }
    final question = _questions[_index];
    final answered = _selected != null;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${_index + 1} / ${_questions.length} 問'),
          Text('スコア: $_score'),
          const SizedBox(height: 12),
          Text(question.prompt, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 16),
          for (var i = 0; i < question.options.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ElevatedButton(
                onPressed: answered ? null : () => _answer(i),
                child: Text(question.options[i]),
              ),
            ),
          if (answered) ...[
            const SizedBox(height: 12),
            Text(
              _selected == question.correctIndex ? '正解！' : '不正解…',
              style: const TextStyle(fontSize: 20),
            ),
            if (_selected != question.correctIndex)
              Text('正解: ${question.correctAnswer}'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _next,
              child: Text(
                _index + 1 >= _questions.length ? '結果を見る' : '次へ',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
