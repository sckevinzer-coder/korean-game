import 'dart:math';

import 'package:flutter/material.dart';

import '../data/word_repository.dart';
import '../db/progress_store.dart';
import '../i18n/app_locale.dart';
import '../i18n/app_strings.dart';
import '../models/word.dart';
import '../notify/review_notify.dart';
import 'mini_game_screen.dart';
import 'sentence_fill_screen.dart';
import '../stats/bookmark_store.dart';
import '../stats/error_stats.dart';
import '../stats/stats_store.dart';
import 'level_select_screen.dart';

typedef WordsLoader = Future<List<Word>> Function(int level);

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.store,
    this.stats,
    this.errors,
    this.bookmarks,
    this.levelSelectStats,
    this.level = 1,
    this.loadWords = loadWordsForLevel,
    this.now,
    this.random,
  });

  final ProgressStore store;
  final StatsStore? stats;
  final ErrorStatsStore? errors;
  final BookmarkStore? bookmarks;
  final StatsStore? levelSelectStats;
  final int level;
  final WordsLoader loadWords;
  final DateTime Function()? now;
  final Random? random;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _Counts {
  const _Counts(this.due, this.total, this.streak,
      {this.freezesLeft = 0,
      this.freezeUsed = false,
      this.notifyState = 'hidden',
      this.goal = 10,
      this.solved = 0});
  final int due;
  final int total;
  final int streak;
  final int freezesLeft;
  final bool freezeUsed;
  final String notifyState;
  final int goal;
  final int solved;
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<_Counts> _future;
  bool _notifyOptedIn = false;
  AppLocale _locale = AppLocale.japanese;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _loadLocale();
  }

  Future<_Counts> _load() async {
    final now = widget.now?.call() ?? DateTime.now();
    // Dispatch concurrently: awaiting FFI stores one by one stalls
    // completion inside the widget test zone.
    final dueFuture = widget.store.dueCards(now);
    final wordsFuture = widget.loadWords(widget.level);
    final knownFuture = widget.store.allCardsForLevel(widget.level);
    final stats = widget.stats;
    final streakFuture = stats == null
        ? Future<ProtectedStreak>.value(
            const ProtectedStreak(streak: 0, freezeUsed: false))
        : stats.protectedStreak(now);
    final displayFuture =
        stats == null ? Future<int>.value(0) : stats.displayStreak(now);
    final freezesFuture =
        stats == null ? Future<int>.value(0) : stats.freezesLeft(now);
    final dueCards = await dueFuture;
    final words = await wordsFuture;
    final knownIds =
        (await knownFuture).map((c) => c.wordId).toSet();
    final total = words.length;
    final unstudied = words.where((w) => !knownIds.contains(w.id)).length;
    final due = dueCards.length + unstudied;
    final protected = await streakFuture;
    final display = await displayFuture;
    final streak = protected.streak >= display ? protected.streak : display;
    final freezes = await freezesFuture;
    final goal = stats == null ? 10 : await stats.getDailyGoal();
    final solved = stats == null ? 0 : await stats.todaySolvedCount(now);
    var notifyState = 'hidden';
    try {
      final supported = await reviewNotifySupported()
          .timeout(const Duration(seconds: 2), onTimeout: () => false);
      if (supported) {
        final permission = await reviewNotifyPermission()
            .timeout(const Duration(seconds: 2), onTimeout: () => 'denied');
        notifyState = reminderState(
          supported: supported,
          permission: permission,
          dueCount: due,
        );
        if (notifyState == 'notify') {
          showReviewNotification(due, _locale).catchError((_) {});
        }
      }
    } catch (_) {
      notifyState = 'hidden';
    }
    return _Counts(
      due,
      total,
      streak,
      freezesLeft: freezes,
      freezeUsed: protected.freezeUsed,
      notifyState: notifyState,
      goal: goal,
      solved: solved,
    );
  }

  Future<void> _optIntoNotifications() async {
    String permission = 'denied';
    try {
      permission = await requestReviewNotifyPermission()
          .timeout(const Duration(seconds: 30), onTimeout: () => 'denied');
    } catch (_) {
      permission = 'denied';
    }
    if (!mounted) return;
    if (permission == 'granted') {
      setState(() => _notifyOptedIn = true);
      final counts = await _future;
      showReviewNotification(counts.due, _locale).catchError((_) {});
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(_locale, 'home.notifyDenied'))),
      );
    }
  }

  Future<void> _loadLocale() async {
    final stats = widget.stats;
    if (stats == null) return;
    try {
      final code = await stats.getLocaleCode();
      if (mounted) setState(() => _locale = AppLocale.parse(code));
    } catch (_) {}
  }

  Future<void> _changeLocale(AppLocale locale) async {
    setState(() => _locale = locale);
    try {
      await widget.stats?.setLocaleCode(locale.code);
    } catch (_) {}
  }

  void _openLevels() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LevelSelectScreen(
          store: widget.store,
          stats: widget.levelSelectStats ?? widget.stats,
          errors: widget.errors,
          bookmarks: widget.bookmarks,
          locale: _locale,
          loadWords: widget.loadWords,
          now: widget.now,
          random: widget.random,
        ),
      ),
    );
  }

  Future<void> _changeGoal() async {
    final stats = widget.stats;
    if (stats == null) return;
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(tr(_locale, 'home.goalTitle')),
        children: [
          for (final g in [5, 10, 20, 30])
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(g),
              child: Text(trParams(_locale, 'home.goalOption', {'n': g})),
            ),
        ],
      ),
    );
    if (picked != null && mounted) {
      await stats.setDailyGoal(picked);
      setState(() {
        _future = _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = _locale;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(locale, 'home.title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.extension),
            tooltip: tr(locale, 'game.title'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MiniGameScreen(
                    locale: _locale,
                    loadWords: widget.loadWords,
                    level: widget.level,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.text_snippet_outlined),
            tooltip: tr(locale, 'game2.title'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SentenceFillScreen(
                    locale: _locale,
                    loadWords: widget.loadWords,
                    level: widget.level,
                  ),
                ),
              );
            },
          ),
          PopupMenuButton<AppLocale>(
            tooltip: tr(locale, 'home.language'),
            icon: const Icon(Icons.language),
            onSelected: _changeLocale,
            itemBuilder: (context) => [
              for (final l in AppLocale.values)
                CheckedPopupMenuItem(
                  value: l,
                  checked: l == locale,
                  child: Text(l.label),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: tr(locale, 'home.goalTitle'),
            onPressed: widget.stats == null ? null : _changeGoal,
          ),
        ],
      ),
      body: Center(
        child: FutureBuilder<_Counts>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text(tr(locale, 'home.loadError'));
            }
            if (!snapshot.hasData) {
              return const CircularProgressIndicator();
            }
            final counts = snapshot.data!;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: .center,
                children: [
                  Text(trParams(locale, 'home.review', {
                    'due': counts.due,
                    'total': counts.total,
                  })),
                  Text(trParams(locale, 'home.streak', {'n': counts.streak})),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: counts.goal <= 0
                              ? 0.0
                              : (counts.solved / counts.goal)
                                  .clamp(0.0, 1.0),
                          strokeWidth: 8,
                        ),
                        Text('${counts.solved}/${counts.goal}'),
                      ],
                    ),
                  ),
                  Text(trParams(locale, 'home.goal', {
                    'solved': counts.solved,
                    'goal': counts.goal,
                  })),
                  if (counts.freezeUsed)
                    Text(tr(locale, 'home.freezeUsed')),
                  Text(trParams(
                      locale, 'home.freezeLeft', {'n': counts.freezesLeft})),
                  if (counts.notifyState == 'opt-in' && !_notifyOptedIn) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _optIntoNotifications,
                      child: Text(tr(locale, 'home.reminderOptIn')),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _openLevels,
                    child: Text(tr(locale, 'home.pickLevel')),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.deepPurple[50],
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr(locale, 'home.introTitle'),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(tr(locale, 'home.intro1')),
                          Text(tr(locale, 'home.intro2')),
                          Text(tr(locale, 'home.intro3')),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
