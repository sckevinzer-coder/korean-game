import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

import '../db/progress_store.dart';
import '../i18n/app_locale.dart';
import '../i18n/app_strings.dart';
import '../models/word.dart';
import '../srs/srs_scheduler.dart';
import '../stats/bookmark_store.dart';
import '../stats/stats_store.dart';
import '../tts/tts_service.dart';

typedef ScheduleFn = SrsCard Function(SrsCard card, Grade grade, DateTime now);

class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({
    super.key,
    required this.store,
    required this.words,
    this.stats,
    this.bookmarks,
    this.initialCards = const [],
    this.now,
    this.scheduleFn = schedule,
    this.level = 1,
    this.locale = AppLocale.japanese,
  });

  final ProgressStore store;
  final List<Word> words;
  final StatsStore? stats;
  final BookmarkStore? bookmarks;
  final List<SrsCard> initialCards;
  final DateTime Function()? now;
  final ScheduleFn scheduleFn;
  final int level;
  final AppLocale locale;

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  bool _revealed = false;
  bool _saving = false;
  bool _recorded = false;
  late final Map<String, SrsCard> _cards;
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;
  late final TtsService _tts;
  late final FocusNode _focusNode;
  int _sessionCorrect = 0;
  int _sessionIncorrect = 0;
  Grade? _lastGrade;
  int _currentStreak = 0;
  int _maxStreak = 0;

  @override
  void initState() {
    super.initState();
    _cards = {for (final c in widget.initialCards) c.wordId: c};
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
    _tts = createTtsService();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _flipController.dispose();
    _tts.stop();
    _focusNode.dispose();
    super.dispose();
  }

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  Future<void> _grade(Grade grade) async {
    if (_saving || _index >= widget.words.length) return;
    _lightHaptic();
    setState(() {
      _saving = true;
      _lastGrade = grade;
      if (grade == Grade.again) {
        _sessionIncorrect++;
        _currentStreak = 0;
      } else {
        _sessionCorrect++;
        _currentStreak++;
        if (_currentStreak > _maxStreak) _maxStreak = _currentStreak;
      }
    });
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
        final pending = widget.stats?.recordStudy(now);
        if (pending != null) unawaited(pending);
      }
      if (!mounted) return;
      // Advance immediately for better test compatibility, animate in background
      _advanceToNextCard();
      _flipController.forward().then((_) {
        if (!mounted) return;
        _flipController.reset();
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _advanceToNextCard() {
    setState(() {
      _index += 1;
      _revealed = false;
    });
  }

  Future<void> _speakWord() async {
    _lightHaptic();
    final word = widget.words[_index];
    await _tts.speak(word.korean).catchError((_) {});
  }

  Future<void> _toggleBookmark(bool saved) async {
    final store = widget.bookmarks;
    if (store == null || _index >= widget.words.length) return;
    _lightHaptic();
    final id = widget.words[_index].id;
    if (saved) {
      await store.remove(id).catchError((_) {});
    } else {
      await store.add(id).catchError((_) {});
    }
    if (mounted) setState(() {});
  }

  Future<void> _lightHaptic() async {
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 10);
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (_index >= widget.words.length) return;

    if (!_revealed) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        setState(() {
          _revealed = true;
          _flipController.forward();
        });
      }
    } else {
      if (event.logicalKey == LogicalKeyboardKey.digit1) {
        _grade(Grade.again);
      } else if (event.logicalKey == LogicalKeyboardKey.digit2) {
        _grade(Grade.hard);
      } else if (event.logicalKey == LogicalKeyboardKey.digit3) {
        _grade(Grade.good);
      } else if (event.logicalKey == LogicalKeyboardKey.digit4) {
        _grade(Grade.easy);
      }
      else if (event.logicalKey == LogicalKeyboardKey.space) {
        if (_index + 1 < widget.words.length) {
          setState(() {
            _index += 1;
            _revealed = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          title: Text(trParams(widget.locale, 'card.title',
              {'n': widget.level})),
          actions: [
            if (widget.bookmarks != null &&
                _index < widget.words.length)
              FutureBuilder<bool>(
                future: widget.bookmarks!
                    .contains(widget.words[_index].id),
                builder: (context, snapshot) {
                  final saved = snapshot.data ?? false;
                  return IconButton(
                    icon: Icon(saved
                        ? Icons.bookmark
                        : Icons.bookmark_outline),
                    tooltip: tr(widget.locale, 'card.bookmarkTooltip'),
                    onPressed: () => _toggleBookmark(saved),
                  );
                },
              ),
            IconButton(
              icon: const Icon(Icons.volume_up),
              onPressed: _speakWord,
              tooltip: tr(widget.locale, 'card.ttsTooltip'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Center(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (widget.words.isEmpty) {
      return Text(tr(widget.locale, 'card.empty'));
    }
    if (_index >= widget.words.length) {
      return _buildCompletionScreen();
    }
    final word = widget.words[_index];
    final total = widget.words.length;
    final progress = (_index + 1) / total;
    final percent = (progress * 100).round();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height - 32,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildProgressHeader(total, progress, percent),
            const SizedBox(height: 20),
            _buildFlashcard(word),
            const SizedBox(height: 20),
            if (_revealed) _buildGradeButtons(),
            if (!_revealed) _buildHintText(),
            if (_revealed) _buildExampleSentences(word),
            if (_lastGrade != null) _buildLastGradeFeedback(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressHeader(int total, double progress, int percent) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$_index + 1 / $total 枚',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            ),
            const SizedBox(width: 12),
            if (_currentStreak > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department, size: 14, color: Colors.orange[700]),
                    const SizedBox(width: 4),
                    Text(
                      trParams(widget.locale, 'card.chain',
                          {'n': _currentStreak}),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[700],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                trParams(widget.locale, 'card.tally', {
                  'c': _sessionCorrect,
                  'i': _sessionIncorrect,
                }),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue[700],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFlashcard(Word word) {
    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, child) {
        final isFlipped = _flipAnimation.value > 0.5;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(_flipAnimation.value * 3.14159),
          child: _revealed || isFlipped
              ? _buildCardBack(word)
              : _buildCardFront(word),
        );
      },
    );
  }

  Widget _buildCardFront(Word word) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _revealed = true;
          _flipController.forward();
        });
        _lightHaptic();
      },
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                word.korean,
                style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                word.reading,
                style: TextStyle(fontSize: 20, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(24),
                ),
              child: Text(
                tr(widget.locale, 'card.tapToReveal'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardBack(Word word) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.green[50],
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  word.korean,
                  style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                Text(
                  word.reading,
                  style: TextStyle(fontSize: 20, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              word.meaningJa,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHintText() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        tr(widget.locale, 'card.tapOrSpace'),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildGradeButtons() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _buildGradeButton(
            tr(widget.locale, 'card.again'), Grade.again, Colors.red, Icons.refresh),
        _buildGradeButton(
            tr(widget.locale, 'card.hard'), Grade.hard, Colors.orange, Icons.sentiment_dissatisfied),
        _buildGradeButton(
            tr(widget.locale, 'card.good'), Grade.good, Colors.blue, Icons.sentiment_neutral),
        _buildGradeButton(
            tr(widget.locale, 'card.easy'), Grade.easy, Colors.green, Icons.sentiment_satisfied),
      ],
    );
  }

  Widget _buildGradeButton(String label, Grade grade, Color color, IconData icon) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 18),
      label: Text(label),
      onPressed: _saving ? null : () => _grade(grade),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  Widget _buildExampleSentences(Word word) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(widget.locale, 'card.example'),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Text(word.exampleKo, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 4),
          Text(word.exampleJa, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildLastGradeFeedback() {
    if (_lastGrade == null) return const SizedBox.shrink();
    Color color;
    String text;
    IconData icon;
    switch (_lastGrade!) {
      case Grade.again:
        color = Colors.red;
        text = tr(widget.locale, 'card.fbAgain');
        icon = Icons.refresh;
        break;
      case Grade.hard:
        color = Colors.orange;
        text = tr(widget.locale, 'card.fbHard');
        icon = Icons.trending_up;
        break;
      case Grade.good:
        color = Colors.blue;
        text = tr(widget.locale, 'card.fbGood');
        icon = Icons.check_circle;
        break;
      case Grade.easy:
        color = Colors.green;
        text = tr(widget.locale, 'card.fbEasy');
        icon = Icons.bolt;
        break;
    }
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildCompletionScreen() {
    final total = widget.words.length;
    final percent = total > 0 ? (_sessionCorrect / total * 100).round() : 0;
    String message;
    Color messageColor;
    IconData messageIcon;
    final locale = widget.locale;
    if (percent >= 90) {
      message = tr(locale, 'card.msg90');
      messageColor = Colors.green[700]!;
      messageIcon = Icons.emoji_events;
    } else if (percent >= 70) {
      message = tr(locale, 'card.msg70');
      messageColor = Colors.blue[700]!;
      messageIcon = Icons.thumb_up;
    } else if (percent >= 50) {
      message = tr(locale, 'card.msg50');
      messageColor = Colors.orange[700]!;
      messageIcon = Icons.trending_up;
    } else {
      message = tr(locale, 'card.msgLow');
      messageColor = Colors.grey[700]!;
      messageIcon = Icons.favorite;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(messageIcon, size: 64, color: messageColor),
        const SizedBox(height: 16),
        Text(
          tr(locale, 'card.done'),
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: messageColor),
        ),
        const SizedBox(height: 8),
        Text(
          trParams(locale, 'card.score', {
            'c': _sessionCorrect,
            't': total,
            'p': percent,
          }),
          style: const TextStyle(fontSize: 20),
        ),
        const SizedBox(height: 8),
        Text(
          trParams(locale, 'card.best', {'n': _maxStreak}),
          style: TextStyle(fontSize: 16, color: Colors.orange[700], fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Text(message, style: TextStyle(fontSize: 16, color: messageColor), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.replay),
              label: Text(tr(locale, 'card.retry')),
              onPressed: () {
                setState(() {
                  _index = 0;
                  _revealed = false;
                  _sessionCorrect = 0;
                  _sessionIncorrect = 0;
                  _currentStreak = 0;
                  _maxStreak = 0;
                  _lastGrade = null;
                });
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.arrow_back),
              label: Text(tr(locale, 'card.backToLevels')),
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[200],
                foregroundColor: Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }
}