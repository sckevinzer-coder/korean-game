import 'package:flutter_test/flutter_test.dart';

import 'package:korean_game/srs/srs_scheduler.dart';

SrsCard cardWith({Duration interval = Duration.zero, double ease = 2.5}) =>
    SrsCard(wordId: 'w1', interval: interval, ease: ease, dueDate: DateTime(2026, 1, 1));

void main() {
  final now = DateTime(2026, 10, 3, 12);

  test('again resets interval to 1 minute and dueDate ~now+1m', () {
    final result = schedule(cardWith(interval: const Duration(days: 5)), Grade.again, now);
    expect(result.interval, const Duration(minutes: 1));
    expect(result.dueDate.difference(now.add(const Duration(minutes: 1))).inSeconds.abs(), lessThan(2));
  });

  test('good multiplies interval by ease (min 1 day first time)', () {
    final first = schedule(cardWith(), Grade.good, now);
    expect(first.interval, const Duration(days: 1));

    final later = schedule(cardWith(interval: const Duration(days: 4), ease: 2.0), Grade.good, now);
    expect(later.interval, const Duration(days: 8));
  });

  test('easy increases ease more than hard', () {
    final hard = schedule(cardWith(), Grade.hard, now);
    final easy = schedule(cardWith(), Grade.easy, now);
    expect(easy.ease - 2.5, greaterThan(hard.ease - 2.5));
  });

  test('again and hard lower ease; ease floored at 1.3', () {
    expect(schedule(cardWith(), Grade.again, now).ease, closeTo(2.3, 1e-9));
    expect(schedule(cardWith(), Grade.hard, now).ease, closeTo(2.35, 1e-9));
    expect(schedule(cardWith(ease: 1.3), Grade.again, now).ease, 1.3);
  });

  test('dueDate is set to now + interval', () {
    final result = schedule(cardWith(interval: const Duration(days: 2), ease: 2.0), Grade.good, now);
    expect(result.dueDate, now.add(result.interval));
  });
}
