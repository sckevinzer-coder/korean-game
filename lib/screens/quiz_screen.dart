import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

import '../models/word.dart';
import '../quiz/adaptive_selector.dart';
import '../quiz/quiz_generator.dart';
import '../quiz/writing_grader.dart';
import '../i18n/app_locale.dart';
import '../i18n/app_strings.dart';
import '../stats/achievements.dart';
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
    this.timeAttack = false,
    this.lenientGrading = false,
    this.locale = AppLocale.japanese,
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
  final bool timeAttack;
  final bool lenientGrading;
  final AppLocale locale;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<QuizQuestion> _questions = const [];
  bool _confusableFirst = true;
  late bool _lenientGrading;
  static const double _timeLimitSeconds = 10.0;
  late bool _timeAttack;
  Timer? _questionTimer;
  double _timeLeft = _timeLimitSeconds;
  DateTime? _questionStart;
  final List<double> _answerDurations = [];
  int _index = 0;
  int _score = 0;
  int? _selected;
  bool _recorded = false;
  bool _showFallbackText = false;
  String? _writingInput;
  WritingAnalysisResult? _lastWritingAnalysis;
  final List<bool> _results = [];
  late final TtsService _tts;
  int _hintsUsed = 0;
  static const int _maxHints = 3;
  int _sessionStreak = 0;
  int _maxSessionStreak = 0;
  final double _ttsSpeed = 1.0;
  double _bonusPoints = 0.0;

  List<QuizQuestion> get questionsForTesting => _questions;

  @override
  void initState() {
    super.initState();
    _timeAttack = widget.timeAttack;
    _lenientGrading = widget.lenientGrading;
    _tts = widget.tts ?? createTtsService();
    _questions = widget.questions ?? _generate(widget.rng ?? Random());
    _startQuestionTimer();
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
        _lastWritingAnalysis = null;
        _results.clear();
        _bonusPoints = 0.0;
        _hintsUsed = 0;
        _answerDurations.clear();
        _sessionStreak = 0;
        _maxSessionStreak = 0;
      });
      _speakIfListening();
      _startQuestionTimer();
    }
  }

  @override
  void dispose() {
    _tts.stop();
    _questionTimer?.cancel();
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
    final weakForOptions =
        _confusableFirst ? widget.weakRates : null;
    final questions = <QuizQuestion>[];
    for (var i = 0; i < orderedWords.length; i++) {
      final kind = kinds[i % kinds.length];
      late QuizQuestion q;
      if (kind == QuizKind.blank) {
        q = makeBlankQuestion(
              orderedWords[i],
              widget.words,
              rng,
              weakRates: weakForOptions,
            ) ??
            makeQuestion(
              orderedWords[i],
              widget.words,
              QuizKind.wordToMeaning,
              rng,
              weakRates: weakForOptions,
            );
      } else if (kind == QuizKind.writing) {
        q = makeQuestion(
          orderedWords[i],
          widget.words,
          QuizKind.meaningToWord,
          rng,
          weakRates: weakForOptions,
        );
        q = QuizQuestion(
          prompt: trParams(widget.locale, 'quiz.writingPrompt',
              {'m': q.prompt}),
          options: [q.correctAnswer],
          correctIndex: 0,
          kind: QuizKind.writing,
          audioText: null,
          wordId: orderedWords[i].id,
        );
      } else {
        q = makeQuestion(
          orderedWords[i],
          widget.words,
          kind,
          rng,
          weakRates: weakForOptions,
        );
      }
      questions.add(q);
    }
    return questions;
  }

  /// Loads the persisted lenient-grading preference on demand.
  ///
  /// Called when the settings menu opens and before writing answers are
  /// graded, so no store read happens during screen build or tests.
  Future<void> _loadLenientGrading() async {
    final stats = widget.stats;
    if (stats == null) return;
    try {
      final value = await stats.getLenientGrading();
      if (mounted) setState(() => _lenientGrading = value);
    } catch (_) {}
  }

  void _regenerateQuestions() {
    _questionTimer?.cancel();
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
      _answerDurations.clear();
      _sessionStreak = 0;
      _maxSessionStreak = 0;
    });
    _speakIfListening();
    _startQuestionTimer();
  }

  void _startQuestionTimer() {
    _questionTimer?.cancel();
    _questionStart = null;
    _timeLeft = _timeLimitSeconds;
    if (!_timeAttack || _index >= _questions.length) return;
    _questionStart = DateTime.now();
    _questionTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted || _index >= _questions.length || _selected != null) {
        t.cancel();
        return;
      }
      setState(() {
        _timeLeft -= 0.1;
      });
      if (_timeLeft <= 0) {
        t.cancel();
        _onTimeout();
      }
    });
  }

  void _stopTimerAndRecordDuration() {
    _questionTimer?.cancel();
    final start = _questionStart;
    _questionStart = null;
    if (start != null) {
      final elapsed = DateTime.now().difference(start).inMilliseconds / 1000.0;
      _answerDurations.add(elapsed.clamp(0.0, _timeLimitSeconds));
    }
  }

  double get _averageDuration {
    if (_answerDurations.isEmpty) return 0.0;
    return _answerDurations.reduce((a, b) => a + b) / _answerDurations.length;
  }

  void _onTimeout() {
    if (_index >= _questions.length || _selected != null) return;
    final question = _questions[_index];
    _recordError(question, false, question.correctAnswer);
    _trackStreak(false);
    _answerDurations.add(_timeLimitSeconds);
    setState(() {
      _selected = -1;
      _results.add(false);
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(widget.locale, 'quiz.timeout')),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    _next();
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

  void _trackStreak(bool isCorrect) {
    if (isCorrect) {
      _sessionStreak += 1;
      if (_sessionStreak > _maxSessionStreak) {
        _maxSessionStreak = _sessionStreak;
      }
    } else {
      _sessionStreak = 0;
    }
  }

  void _answer(int selected) {
    if (_selected != null) return;
    _stopTimerAndRecordDuration();
    final question = _questions[_index];
    final isCorrect = selected == question.correctIndex;
    _recordError(question, isCorrect, question.correctAnswer);
    _trackStreak(isCorrect);
    setState(() {
      _selected = selected;
      _results.add(isCorrect);
      if (isCorrect) _score += 1;
    });
  }

  /// Records the finished session, then evaluates achievements in order.
  Future<void> _finishSession(DateTime day) async {
    final stats = widget.stats;
    if (stats != null) {
      try {
        await stats.recordStudy(day);
        await stats.recordSession(
          day,
          _questions.length,
          _score,
          level: widget.level,
        );
      } catch (_) {}
    }
    await _checkAchievements(day);
  }

  /// Evaluates achievement conditions after a session and celebrates news.
  Future<void> _checkAchievements(DateTime day) async {
    final stats = widget.stats;
    if (stats == null) return;
    List<String> fresh;
    try {
      fresh = await evaluateNewAchievements(
        stats: stats,
        today: day,
        sessionBestStreak: _maxSessionStreak,
      );
    } catch (_) {
      return;
    }
    if (fresh.isEmpty || !mounted) return;
    final defs = {
      for (final d in allAchievements) d.id: d,
    };
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 50);
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(widget.locale, 'quiz.achTitle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final id in fresh)
              Text(
                  '🏅 ${defs[id]?.titleFor(widget.locale) ?? id}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr(widget.locale, 'quiz.close')),
          ),
        ],
      ),
    );
  }

  void _speakModelAnswer(String answer) {
    _tts.speak(answer, rate: _ttsSpeed).catchError((_) {});
  }

  Future<void> _submitWriting() async {
    if (_selected != null || _writingInput == null) return;
    await _loadLenientGrading();
    if (_selected != null) return;
    _stopTimerAndRecordDuration();
    final question = _questions[_index];
    final analysis = WritingGrader.analyze(
      _writingInput!,
      question.correctAnswer,
      lenient: _lenientGrading,
      locale: widget.locale,
    );
    final bonus = WritingGrader.bonusFor(analysis);
    final bucket =
        '${analysis.errorType.name}:${(analysis.similarityScore * 10).round()}';
    _recordError(question, analysis.isCorrect, bucket);
    _trackStreak(analysis.isCorrect);
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
      _finishSession(day);
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
    _startQuestionTimer();
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
          Text(tr(widget.locale, 'quiz.byKind'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          for (final k in analysis.byKind)
            Text(
                '${kindLabel(k.kind, widget.locale)}: ${k.correct}/${k.total}'),
          if (analysis.suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final s in analysis.suggestions.take(2))
              Text('${tr(widget.locale, 'quiz.bullet')}$s'),
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
          return Text(tr(widget.locale, 'quiz.noWeak'));
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
              Text(tr(widget.locale, 'quiz.reviewTitle'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              for (final w in items)
                Text(trParams(widget.locale, 'quiz.weakRow', {
                  'key': w.key,
                  'p': ((1 - w.errorRate) * 100).round(),
                })),
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
        content: Text(trParams(widget.locale, 'quiz.hintContent', {
          'n': _hintsUsed + 1,
          'm': _maxHints,
          'f': first,
          'len': answer.length,
        })),
        duration: const Duration(seconds: 3),
      ),
    );
    setState(() => _hintsUsed += 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(widget.locale, 'quiz.title')),
        actions: [
          if (_showWritingHintButton)
            IconButton(
              icon: const Icon(Icons.lightbulb_outline),
              tooltip: trParams(widget.locale, 'quiz.hintUsed', {
                'used': _hintsUsed,
                'max': _maxHints,
              }),
              onPressed: _useWritingHint,
            ),
          PopupMenuButton<String>(
            tooltip: tr(widget.locale, 'quiz.settings'),
            onOpened: () {
              _loadLenientGrading();
            },
            onSelected: (value) async {
              if (value == 'confusable') {
                setState(() => _confusableFirst = !_confusableFirst);
                _regenerateQuestions();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(tr(widget.locale,
                          _confusableFirst ? 'quiz.confusableOn' : 'quiz.confusableOff')),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } else if (value == 'timeattack') {
                setState(() => _timeAttack = !_timeAttack);
                _regenerateQuestions();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(tr(widget.locale,
                          _timeAttack ? 'quiz.timeattackOn' : 'quiz.timeattackOff')),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } else if (value == 'lenient') {
                setState(() => _lenientGrading = !_lenientGrading);
                try {
                  await widget.stats
                      ?.setLenientGrading(_lenientGrading);
                } catch (_) {}
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(tr(widget.locale,
                          _lenientGrading ? 'quiz.lenientOn' : 'quiz.lenientOff')),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: 'confusable',
                checked: _confusableFirst,
                child: Text(tr(widget.locale, 'quiz.confusable')),
              ),
              CheckedPopupMenuItem(
                value: 'timeattack',
                checked: _timeAttack,
                child: Text(tr(widget.locale, 'quiz.timeattack')),
              ),
              CheckedPopupMenuItem(
                value: 'lenient',
                checked: _lenientGrading,
                child: Text(tr(widget.locale, 'quiz.lenient')),
              ),
            ],
          ),
        ],
      ),
      body: Center(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final locale = widget.locale;
    if (widget.words.isEmpty || _questions.isEmpty) {
      return Text(tr(locale, 'quiz.empty'));
    }
    if (_index >= _questions.length) {
      final analysis = analyzeSession(
        questions: _questions,
        correct: _results,
        locale: locale,
      );
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(tr(locale, 'quiz.done')),
            Text(trParams(locale, 'quiz.result', {
              's': _score,
              't': _questions.length,
            })),
            if (_timeAttack && _answerDurations.isNotEmpty)
              Text(
                trParams(locale, 'quiz.avgTime', {
                  'n': _averageDuration.toStringAsFixed(1),
                }),
              ),
            Text(tr(locale, 'quiz.goodJob')),
            if (_bonusPoints > 0)
              Text(trParams(locale, 'quiz.bonus', {
                'n': _bonusPoints.toStringAsFixed(1),
              })),
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
          Text(trParams(locale, 'quiz.progress', {
            'i': _index + 1,
            't': _questions.length,
          })),
          Text(trParams(locale, 'quiz.score', {'n': _score})),
          if (_timeAttack && !answered) ...[
            const SizedBox(height: 8),
            Text(trParams(locale, 'quiz.remain', {
              'n': _timeLeft.toStringAsFixed(0),
            })),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: (_timeLeft / _timeLimitSeconds).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                _timeLeft <= 3 ? Colors.red : Colors.green,
              ),
            ),
          ],
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
                        tooltip: tr(widget.locale, 'quiz.bookmarkTooltip'),
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
                        tooltip: tr(widget.locale, 'quiz.replayTooltip'),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _showFallbackText = !_showFallbackText),
                        child: Text(tr(widget.locale,
                            _showFallbackText ? 'quiz.hideText' : 'quiz.showText')),
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
            ? WritingGrader.analyze(
                liveInput,
                question.correctAnswer,
                lenient: _lenientGrading,
                locale: widget.locale,
              )
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
                  child: Text(tr(widget.locale, 'quiz.submit')),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.volume_up),
                tooltip: tr(widget.locale, 'quiz.modelTooltip'),
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
        trParams(widget.locale, 'quiz.liveHint', {
          'p': pct,
          'm': live.characterAnalysis.where((c) => c.isMatch).length,
          't': live.characterAnalysis.length,
        }),
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
            Text(tr(widget.locale, 'quiz.detailTitle'),
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                    label = trParams(widget.locale, 'quiz.chipMissing',
                        {'c': c.expectedChar});
                    break;
                  case CharacterErrorType.extra:
                    chipColor = Colors.purple;
                    label = trParams(widget.locale, 'quiz.chipExtra',
                        {'c': c.actualChar ?? ''});
                    break;
                  case CharacterErrorType.wrongVowel:
                    chipColor = Colors.red;
                    label = trParams(widget.locale, 'quiz.chipVowel', {
                      'a': c.actualChar ?? '',
                      'e': c.expectedChar,
                    });
                    break;
                  case CharacterErrorType.wrongConsonant:
                    chipColor = Colors.blue;
                    label = trParams(widget.locale, 'quiz.chipConsonant', {
                      'a': c.actualChar ?? '',
                      'e': c.expectedChar,
                    });
                    break;
                  case CharacterErrorType.wrongParticle:
                    chipColor = Colors.teal;
                    label = trParams(widget.locale, 'quiz.chipParticle', {
                      'a': c.actualChar ?? '',
                      'e': c.expectedChar,
                    });
                    break;
                  default:
                    chipColor = Colors.grey;
                    label = trParams(widget.locale, 'quiz.chipOther', {
                      'a': c.actualChar ?? '',
                      'e': c.expectedChar,
                    });
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
    final locale = widget.locale;
    return [
      const SizedBox(height: 12),
      Text(
        tr(locale,
            _selected == question.correctIndex ? 'quiz.correct' : 'quiz.wrong'),
        style: const TextStyle(fontSize: 20),
      ),
      if (_selected != question.correctIndex)
        Text(trParams(locale, 'quiz.answerIs',
            {'a': question.correctAnswer})),
      if (isWriting && _lastWritingAnalysis != null) ...[
        const SizedBox(height: 8),
        _buildWritingFeedback(),
        if (WritingGrader.isNearMiss(_lastWritingAnalysis!)) ...[
          const SizedBox(height: 4),
          Text(
            trParams(locale, 'quiz.nearMiss', {
              'label': WritingGrader.similarityLabel(
                  _lastWritingAnalysis!.similarityScore, locale),
              'n': WritingGrader.bonusFor(_lastWritingAnalysis!)
                  .toStringAsFixed(1),
            }),
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ],
      const SizedBox(height: 8),
      ElevatedButton(
        onPressed: _next,
        child: Text(
          tr(locale,
              _index + 1 >= _questions.length ? 'quiz.seeResults' : 'quiz.next'),
        ),
      ),
    ];
  }
}