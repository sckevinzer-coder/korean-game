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

String kindLabel(QuizKind kind) {
  switch (kind) {
    case QuizKind.meaningToWord:
      return '意味→単語';
    case QuizKind.wordToMeaning:
      return '単語→意味';
    case QuizKind.listeningWord:
      return 'リスニング(単語)';
    case QuizKind.listeningMeaning:
      return 'リスニング(意味)';
    case QuizKind.blank:
      return '空欄補充';
    case QuizKind.writing:
      return '書き取り';
  }
}

/// Pure session analysis used by the result screen.
SessionAnalysis analyzeSession({
  required List<QuizQuestion> questions,
  required List<bool> correct,
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
    switch (kind) {
      case QuizKind.listeningWord:
      case QuizKind.listeningMeaning:
        suggestions.add('${kindLabel(kind)}が苦手: 速度を0.85xに下げて聞き取り練習');
        break;
      case QuizKind.writing:
        suggestions.add('${kindLabel(kind)}が苦手: 母音・받침の内訳を確認して復習');
        break;
      case QuizKind.blank:
        suggestions.add('${kindLabel(kind)}が苦手: 文脈から品詞を推測する練習');
        break;
      default:
        suggestions.add('${kindLabel(kind)}が苦手: フラッシュカードで復習');
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

/// Weekday labels (日月火水木金土) for the last 7 days, oldest first.
List<String> last7WeekdayLabels(DateTime today) {
  const names = ['日', '月', '火', '水', '木', '金', '土'];
  final base = DateTime(today.year, today.month, today.day);
  return [
    for (var i = 6; i >= 0; i--) names[base.subtract(Duration(days: i)).weekday % 7],
  ];
}
