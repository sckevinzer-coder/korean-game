import 'dart:math';

import 'package:flutter/material.dart';

import '../models/word.dart';
import '../quiz/quiz_generator.dart';
import '../quiz/writing_grader.dart';
import '../stats/stats_store.dart';
import '../tts/tts_service.dart';

typedef QuestionBuilder = QuizQuestion Function(Word target, List<Word> pool);

class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.words,
    this.stats,
    this.questions,
    this.rng,
    this.questionBuilder,
    this.now,
    this.tts,
    this.level = 1,
  });

  final List<Word> words;
  final StatsStore? stats;
  final List<QuizQuestion>? questions;
  final Random? rng;
  final QuestionBuilder? questionBuilder;
  final DateTime Function()? now;
  final TtsService? tts;
  final int level;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late final List<QuizQuestion> _questions;
  int _index = 0;
  int _score = 0;
  int? _selected;
  bool _recorded = false;
  bool _showFallbackText = false;
  String? _writingInput;
  late final TtsService _tts;

  @override
  void initState() {
    super.initState();
    _tts = widget.tts ?? createTtsService();
    _questions = widget.questions ?? _generate(widget.rng ?? Random());
    _speakIfListening();
  }

  @override
  void didUpdateWidget(covariant QuizScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.questions != widget.questions ||
        oldWidget.words != widget.words ||
        oldWidget.level != widget.level) {
      setState(() {
        _questions = widget.questions ?? _generate(widget.rng ?? Random());
        _index = 0;
        _score = 0;
        _selected = null;
        _recorded = false;
        _showFallbackText = false;
        _writingInput = null;
      });
      _speakIfListening();
    }
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  List<QuizKind> _kindsForLevel(int level) {
    switch (level) {
      case 1:
      case 2:
        return [QuizKind.meaningToWord, QuizKind.wordToMeaning];
      case 3:
      case 4:
        return [
          QuizKind.meaningToWord,
          QuizKind.wordToMeaning,
          QuizKind.listeningWord,
          QuizKind.listeningMeaning,
          QuizKind.blank,
        ];
      case 5:
      case 6:
        return [
          QuizKind.meaningToWord,
          QuizKind.wordToMeaning,
          QuizKind.listeningWord,
          QuizKind.listeningMeaning,
          QuizKind.blank,
          QuizKind.writing,
        ];
      default:
        return [
          QuizKind.meaningToWord,
          QuizKind.wordToMeaning,
          QuizKind.listeningWord,
          QuizKind.listeningMeaning,
          QuizKind.blank,
          QuizKind.writing,
        ];
    }
  }

  List<QuizQuestion> _generate(Random rng) {
    final kinds = _kindsForLevel(widget.level);
    final questions = <QuizQuestion>[];
    for (var i = 0; i < widget.words.length; i++) {
      final kind = kinds[i % kinds.length];
      late QuizQuestion q;
      if (kind == QuizKind.blank) {
        q = makeBlankQuestion(widget.words[i], widget.words, rng) ??
            makeQuestion(
              widget.words[i],
              widget.words,
              QuizKind.wordToMeaning,
              rng,
            );
      } else if (kind == QuizKind.writing) {
        q = makeQuestion(
          widget.words[i],
          widget.words,
          QuizKind.meaningToWord,
          rng,
        );
        q = QuizQuestion(
          prompt: '쓰기: ${q.prompt}의 한국어를 쓰세요',
          options: [q.correctAnswer],
          correctIndex: 0,
          kind: QuizKind.writing,
          audioText: null,
        );
      } else {
        q = makeQuestion(widget.words[i], widget.words, kind, rng);
      }
      questions.add(q);
    }
    return questions;
  }

  void _speakIfListening() {
    if (_index >= _questions.length) return;
    final question = _questions[_index];
    if ((question.kind == QuizKind.listeningWord ||
            question.kind == QuizKind.listeningMeaning) &&
        question.audioText != null) {
      _tts.speak(question.audioText!).catchError((_) {});
    }
  }

  void _replayAudio() {
    if (_index >= _questions.length) return;
    final question = _questions[_index];
    if (question.audioText != null) {
      _tts.speak(question.audioText!).catchError((_) {});
    }
  }

  void _answer(int selected) {
    if (_selected != null) return;
    setState(() {
      _selected = selected;
      if (selected == _questions[_index].correctIndex) _score += 1;
    });
  }

  void _submitWriting() {
    if (_selected != null || _writingInput == null) return;
    final question = _questions[_index];
    final isCorrect = gradeWriting(_writingInput!, question.correctAnswer);
    setState(() {
      _selected = isCorrect ? 0 : -1;
      if (isCorrect) _score += 1;
    });
  }

  void _next() {
    final isLast = _index + 1 >= _questions.length;
    if (isLast && !_recorded) {
      _recorded = true;
      final day = widget.now?.call() ?? DateTime.now();
      widget.stats?.recordStudy(day);
    }
    setState(() {
      _index += 1;
      _selected = null;
      _showFallbackText = false;
      _writingInput = null;
    });
    _speakIfListening();
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
          _buildQuestionCard(question, answered),
          const SizedBox(height: 16),
          if (!answered) ..._buildAnswerArea(question),
          if (answered) ..._buildResultArea(question),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(QuizQuestion question, bool answered) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    question.prompt,
                    style: const TextStyle(fontSize: 28),
                    textAlign: TextAlign.center,
                  ),
                ),
                if ((question.kind == QuizKind.listeningWord ||
                        question.kind == QuizKind.listeningMeaning) &&
                    question.audioText != null)
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.replay),
                        onPressed: _replayAudio,
                        tooltip: '다시 듣기',
                      ),
                      TextButton(
                        onPressed: () => setState(() => _showFallbackText = !_showFallbackText),
                        child: Text(_showFallbackText ? 'テキストを隠す' : 'テキストを見る'),
                      ),
                    ],
                  ),
              ],
            ),
            if (_showFallbackText && question.audioText != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.grey[200],
                child: Text(
                  question.audioText!,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAnswerArea(QuizQuestion question) {
    switch (question.kind) {
      case QuizKind.writing:
        return [
          TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '한국어를 입력하세요',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _writingInput = v),
            onSubmitted: (_) => _submitWriting(),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _writingInput?.trim().isNotEmpty == true ? _submitWriting : null,
            child: const Text('回答する'),
          ),
        ];
      case QuizKind.blank:
      case QuizKind.meaningToWord:
      case QuizKind.wordToMeaning:
      case QuizKind.listeningWord:
      case QuizKind.listeningMeaning:
        return [
          for (var i = 0; i < question.options.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ElevatedButton(
                onPressed: () => _answer(i),
                child: Text(question.options[i]),
              ),
            ),
        ];
    }
  }

  List<Widget> _buildResultArea(QuizQuestion question) {
    return [
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
    ];
  }
}