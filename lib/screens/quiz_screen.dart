import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

import '../models/word.dart';
import '../quiz/adaptive_selector.dart';
import '../quiz/quiz_generator.dart';
import '../quiz/writing_grader.dart';
import '../stats/bookmark_store.dart';
import '../stats/error_stats.dart';
import '../stats/learning_analytics.dart';
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
    this.errors,
    this.bookmarks,
    this.weakRates,
  });

  final List<Word> words;
  final StatsStore? stats;
  final List<QuizQuestion>? questions;
  final Random? rng;
  final QuestionBuilder? questionBuilder;
  final DateTime Function()? now;
  final TtsService? tts;
  final int level;
  final ErrorStatsStore? errors;
  final BookmarkStore? bookmarks;
  final Map<String, double>? weakRates;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen>
    with SingleTickerProviderStateMixin {
  late final List<QuizQuestion> _questions;
  int _index = 0;
  int _score = 0;
  int? _selected;
  bool _recorded = false;
  bool _showFallbackText = false;
  String? _writingInput;
  WritingAnalysisResult? _lastWritingAnalysis;
  final List<bool> _results = [];
  late final TtsService _tts;
  late final AnimationController _celebrationController;
  late final Animation<double> _celebrationScale;
  int _hintsUsed = 0;
  static const int _maxHints = 3;
  bool _showLevelBanner = true;
  Timer? _bannerTimer;
  int _sessionStreak = 0;
  int _maxSessionStreak = 0;
  bool _showKeyboard = false;
  double _ttsSpeed = 1.0;
  double _bonusPoints = 0.0;

  List<QuizQuestion> get questionsForTesting => _questions;

  @override
  void initState() {
    super.initState();
    _tts = widget.tts ?? createTtsService();
    _questions = widget.questions ?? _generate(widget.rng ?? Random());
    _celebrationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _celebrationScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _celebrationController, curve: Curves.elasticOut),
    );
    _speakIfListening();
    _showLevelBannerTimer();
  }

  void _showLevelBannerTimer() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showLevelBanner = false);
    });
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
        _lastWritingAnalysis = null;
        _results.clear();
        _bonusPoints = 0.0;
        _hintsUsed = 0;
        _showLevelBanner = true;
      });
      _speakIfListening();
      _showLevelBannerTimer();
    }
  }

  @override
  void dispose() {
    _tts.stop();
    _celebrationController.dispose();
    _bannerTimer?.cancel();
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
    final orderedWords = widget.weakRates == null
        ? widget.words
        : prioritizeWeakWords(
            words: widget.words,
            errorRate: widget.weakRates!,
          );
    final questions = <QuizQuestion>[];
    for (var i = 0; i < orderedWords.length; i++) {
      final kind = kinds[i % kinds.length];
      late QuizQuestion q;
      if (kind == QuizKind.blank) {
        q = makeBlankQuestion(orderedWords[i], widget.words, rng) ??
            makeQuestion(
              orderedWords[i],
              widget.words,
              QuizKind.wordToMeaning,
              rng,
            );
      } else if (kind == QuizKind.writing) {
        q = makeQuestion(
          orderedWords[i],
          widget.words,
          QuizKind.meaningToWord,
          rng,
        );
        q = QuizQuestion(
          prompt: '쓰기: ${q.prompt}の韓国語を書きなさい',
          options: [q.correctAnswer],
          correctIndex: 0,
          kind: QuizKind.writing,
          audioText: null,
          wordId: orderedWords[i].id,
        );
      } else {
        q = makeQuestion(orderedWords[i], widget.words, kind, rng);
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

  String? _questionBookmarkKey(QuizQuestion question) {
    if (widget.bookmarks == null) return null;
    return question.wordId ?? question.correctAnswer;
  }

  Future<void> _toggleQuestionBookmark(
      QuizQuestion question, bool saved) async {
    final store = widget.bookmarks;
    final key = _questionBookmarkKey(question);
    if (store == null || key == null) return;
    if (saved) {
      await store.remove(key).catchError((_) {});
    } else {
      await store.add(key).catchError((_) {});
    }
    if (mounted) setState(() {});
  }

  void _recordError(QuizQuestion question, bool isCorrect, String detail) {
    final store = widget.errors;
    if (store == null) return;
    final key = '${question.kind.name}:$detail';
    store.recordAttempt(
      key: key,
      isCorrect: isCorrect,
      lastError: isCorrect ? '' : detail,
    ).catchError((_) {});
  }

  void _answer(int selected) {
    if (_selected != null) return;
    final question = _questions[_index];
    final isCorrect = selected == question.correctIndex;
    _recordError(question, isCorrect, question.correctAnswer);
    setState(() {
      _selected = selected;
      _results.add(isCorrect);
      if (isCorrect) _score += 1;
    });
  }

  void _speakModelAnswer(String answer) {
    _tts.speak(answer, rate: _ttsSpeed).catchError((_) {});
  }

  void _submitWriting() {
    if (_selected != null || _writingInput == null) return;
    final question = _questions[_index];
    final analysis =
        WritingGrader.analyze(_writingInput!, question.correctAnswer);
    final bonus = WritingGrader.bonusFor(analysis);
    final bucket =
        '${analysis.errorType.name}:${(analysis.similarityScore * 10).round()}';
    _recordError(question, analysis.isCorrect, bucket);
    setState(() {
      _lastWritingAnalysis = analysis;
      _results.add(analysis.isCorrect);
      _selected = analysis.isCorrect ? 0 : -1;
      if (analysis.isCorrect) {
        _score += 1;
      } else {
        _bonusPoints += bonus;
      }
    });
    _speakModelAnswer(question.correctAnswer);
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
      _lastWritingAnalysis = null;
      _hintsUsed = 0;
    });
    _speakIfListening();
  }

  Widget _buildSessionAnalysis(SessionAnalysis analysis) {
    if (analysis.total == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('形式別正解率', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          for (final k in analysis.byKind)
            Text('${kindLabel(k.kind)}: ${k.correct}/${k.total}'),
          if (analysis.suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final s in analysis.suggestions.take(2)) Text('・$s'),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewSection() {
    final store = widget.errors;
    if (store == null) return const SizedBox.shrink();
    return FutureBuilder<List<WeakItem>>(
      future: store.topWeak(limit: 3),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <WeakItem>[];
        if (items.isEmpty) {
          return const Text('苦手データはまだありません');
        }
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('復習おすすめ', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              for (final w in items)
                Text('${w.key}（正答率 ${((1 - w.errorRate) * 100).round()}%）'),
            ],
          ),
        );
      },
    );
  }

  bool get _showWritingHintButton {
    if (widget.level < 5 || _index >= _questions.length) return false;
    final q = _questions[_index];
    return q.kind == QuizKind.writing &&
        _selected == null &&
        _hintsUsed < _maxHints;
  }

  void _useWritingHint() {
    if (!_showWritingHintButton) return;
    final answer = _questions[_index].correctAnswer;
    final first = answer.isEmpty ? '' : answer[0];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ヒント ${_hintsUsed + 1}/$_maxHints: 最初「$first」・${answer.length}文字'),
        duration: const Duration(seconds: 3),
      ),
    );
    setState(() => _hintsUsed += 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('クイズ'),
        actions: [
          if (_showWritingHintButton)
            IconButton(
              icon: const Icon(Icons.lightbulb_outline),
              tooltip: 'ヒント ($_hintsUsed/$_maxHints)',
              onPressed: _useWritingHint,
            ),
        ],
      ),
      body: Center(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (widget.words.isEmpty || _questions.isEmpty) {
      return const Text('クイズにする単語がありません');
    }
    if (_index >= _questions.length) {
      final analysis = analyzeSession(
        questions: _questions,
        correct: _results,
      );
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('クイズ完了！'),
            Text('$_score / ${_questions.length} 正解'),
            const Text('お疲れさまでした'),
            if (_bonusPoints > 0)
              Text('惜しいボーナス: +${_bonusPoints.toStringAsFixed(1)}'),
            const SizedBox(height: 16),
            _buildSessionAnalysis(analysis),
            const SizedBox(height: 8),
            _buildReviewSection(),
          ],
        ),
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
          Text('正解: $_score'),
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
                if (widget.bookmarks != null &&
                    _questionBookmarkKey(question) != null)
                  FutureBuilder<bool>(
                    future: widget.bookmarks!.contains(
                        _questionBookmarkKey(question)!),
                    builder: (context, snapshot) {
                      final saved = snapshot.data ?? false;
                      return IconButton(
                        icon: Icon(saved
                            ? Icons.bookmark
                            : Icons.bookmark_outline),
                        tooltip: 'ブックマーク',
                        onPressed: () => _toggleQuestionBookmark(
                            question, saved),
                      );
                    },
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
        final liveInput = _writingInput ?? '';
        final showLive = widget.level >= 5 &&
            liveInput.trim().isNotEmpty &&
            _selected == null;
        final live = showLive
            ? WritingGrader.analyze(liveInput, question.correctAnswer)
            : null;
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
          if (live != null) ...[
            const SizedBox(height: 8),
            _buildWritingLiveHint(live),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _writingInput?.trim().isNotEmpty == true
                      ? _submitWriting
                      : null,
                  child: const Text('回答する'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.volume_up),
                tooltip: 'お手本を聞く',
                onPressed: () => _speakModelAnswer(question.correctAnswer),
              ),
            ],
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

  Widget _buildWritingLiveHint(WritingAnalysisResult live) {
    final pct = (live.similarityScore * 100).round();
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blueGrey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '入力チェック: 類似度 $pct%（${live.characterAnalysis.where((c) => c.isMatch).length}/${live.characterAnalysis.length}）',
        style: const TextStyle(fontSize: 13),
      ),
    );
  }

  Widget _buildWritingFeedback() {
    final analysis = _lastWritingAnalysis!;
    final Color feedbackColor =
        analysis.isCorrect ? Colors.green[700]! : Colors.red[700]!;
    final IconData feedbackIcon =
        analysis.isCorrect ? Icons.check_circle : Icons.error_outline;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: feedbackColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: feedbackColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(feedbackIcon, color: feedbackColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  analysis.feedback,
                  style: TextStyle(
                    color: feedbackColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          if (!analysis.isCorrect &&
              analysis.characterAnalysis.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('詳細分析:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: analysis.characterAnalysis
                  .where((c) => !c.isMatch)
                  .take(6)
                  .map((c) {
                Color chipColor;
                String label;
                switch (c.errorType) {
                  case CharacterErrorType.missing:
                    chipColor = Colors.orange;
                    label = '不足: ${c.expectedChar}';
                    break;
                  case CharacterErrorType.extra:
                    chipColor = Colors.purple;
                    label = '余分: ${c.actualChar}';
                    break;
                  case CharacterErrorType.wrongVowel:
                    chipColor = Colors.red;
                    label = '母音: ${c.actualChar}→${c.expectedChar}';
                    break;
                  case CharacterErrorType.wrongConsonant:
                    chipColor = Colors.blue;
                    label = '子音: ${c.actualChar}→${c.expectedChar}';
                    break;
                  case CharacterErrorType.wrongParticle:
                    chipColor = Colors.teal;
                    label = '助詞: ${c.actualChar}→${c.expectedChar}';
                    break;
                  default:
                    chipColor = Colors.grey;
                    label = '確認: ${c.actualChar}→${c.expectedChar}';
                }
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: chipColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: chipColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 11, color: chipColor),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildResultArea(QuizQuestion question) {
    final isWriting = question.kind == QuizKind.writing;
    return [
      const SizedBox(height: 12),
      Text(
        _selected == question.correctIndex ? '正解！' : '不正解…',
        style: const TextStyle(fontSize: 20),
      ),
      if (_selected != question.correctIndex)
        Text('正解: ${question.correctAnswer}'),
      if (isWriting && _lastWritingAnalysis != null) ...[
        const SizedBox(height: 8),
        _buildWritingFeedback(),
        if (WritingGrader.isNearMiss(_lastWritingAnalysis!)) ...[
          const SizedBox(height: 4),
          Text(
            '惜しい！${WritingGrader.similarityLabel(_lastWritingAnalysis!.similarityScore)}（ボーナス +${WritingGrader.bonusFor(_lastWritingAnalysis!).toStringAsFixed(1)}）',
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ],
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