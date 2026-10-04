import '../i18n/app_locale.dart';
import '../i18n/app_strings.dart';
import '../quiz/quiz_generator.dart';

class KindAccuracy {
  final QuizKind kind;
  final int total;
  final int correct;

  const KindAccuracy({required this.kind, required this.total, required this.correct});

  double get rate => total == 0 ? 0.0 : correct / total;
}

class SessionAnalysis {
  final int total;
  final int correct;
  final List<KindAccuracy> byKind;
  final List<QuizKind> weakKinds;
  final List<String> suggestions;

  const SessionAnalysis({
    required this.total,
    required this.correct,
    required this.byKind,
    required this.weakKinds,
    required this.suggestions,
  });

  double get rate => total == 0 ? 0.0 : correct / total;
}

String kindLabel(QuizKind kind, [AppLocale locale = AppLocale.japanese]) {
  switch (kind) {
    case QuizKind.meaningToWord:
      return tr(locale, 'kind.meaningToWord');
    case QuizKind.wordToMeaning:
      return tr(locale, 'kind.wordToMeaning');
    case QuizKind.listeningWord:
      return tr(locale, 'kind.listeningWord');
    case QuizKind.listeningMeaning:
      return tr(locale, 'kind.listeningMeaning');
    case QuizKind.blank:
      return tr(locale, 'kind.blank');
    case QuizKind.writing:
      return tr(locale, 'kind.writing');
  }
}

/// Pure session analysis used by the result screen.
SessionAnalysis analyzeSession({
  required List<QuizQuestion> questions,
  required List<bool> correct,
  AppLocale locale = AppLocale.japanese,
}) {
  final totals = <QuizKind, int>{};
  final hits = <QuizKind, int>{};
  for (var i = 0; i < questions.length; i++) {
    final kind = questions[i].kind;
    totals[kind] = (totals[kind] ?? 0) + 1;
    if (i < correct.length && correct[i]) {
      hits[kind] = (hits[kind] ?? 0) + 1;
    }
  }
  final byKind = totals.entries
      .map((e) => KindAccuracy(
            kind: e.key,
            total: e.value,
            correct: hits[e.key] ?? 0,
          ))
      .toList()
    ..sort((a, b) => a.rate.compareTo(b.rate));

  final weakKinds =
      byKind.where((k) => k.total > 0 && k.rate < 0.7).map((k) => k.kind).toList();
  final suggestions = <String>[];
  for (final kind in weakKinds.take(2)) {
    final label = kindLabel(kind, locale);
    switch (kind) {
      case QuizKind.listeningWord:
      case QuizKind.listeningMeaning:
        suggestions.add(trParams(locale, 'sug.listening', {'k': label}));
        break;
      case QuizKind.writing:
        suggestions.add(trParams(locale, 'sug.writing', {'k': label}));
        break;
      case QuizKind.blank:
        suggestions.add(trParams(locale, 'sug.blank', {'k': label}));
        break;
      default:
        suggestions.add(trParams(locale, 'sug.default', {'k': label}));
    }
  }
  final total = questions.length;
  final ok = correct.where((c) => c).length;
  return SessionAnalysis(
    total: total,
    correct: ok,
    byKind: byKind,
    weakKinds: weakKinds,
    suggestions: suggestions,
  );
}

/// Weekday labels for the last 7 days, oldest first.
List<String> last7WeekdayLabels(DateTime today,
    [AppLocale locale = AppLocale.japanese]) {
  const names = {
    AppLocale.japanese: ['日', '月', '火', '水', '木', '金', '土'],
    AppLocale.korean: ['일', '월', '화', '수', '목', '금', '토'],
    AppLocale.english: ['S', 'M', 'T', 'W', 'T', 'F', 'S'],
  };
  final days = names[locale] ?? names[AppLocale.japanese]!;
  final base = DateTime(today.year, today.month, today.day);
  return [
    for (var i = 6; i >= 0; i--) days[base.subtract(Duration(days: i)).weekday % 7],
  ];
}
