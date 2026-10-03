enum Grade { again, hard, good, easy }

class SrsCard {
  String wordId;
  Duration interval;
  double ease;
  DateTime dueDate;

  SrsCard({
    required this.wordId,
    required this.interval,
    required this.ease,
    required this.dueDate,
  });
}

SrsCard schedule(SrsCard card, Grade grade, DateTime now) {
  late Duration interval;
  late double ease;
  switch (grade) {
    case Grade.again:
      interval = const Duration(minutes: 1);
      ease = card.ease - 0.2;
    case Grade.hard:
      interval = card.interval <= Duration.zero
          ? const Duration(days: 1)
          : card.interval * 1.2;
      ease = card.ease - 0.15;
    case Grade.good:
      interval = card.interval <= Duration.zero
          ? const Duration(days: 1)
          : card.interval * card.ease;
      ease = card.ease;
    case Grade.easy:
      interval = card.interval <= Duration.zero
          ? const Duration(days: 2)
          : card.interval * card.ease * 1.5;
      ease = card.ease + 0.3;
  }
  ease = ease.clamp(1.3, 3.5);
  return SrsCard(wordId: card.wordId, interval: interval, ease: ease, dueDate: now.add(interval));
}
