import '../models/word.dart';

/// Orders words so error-prone items come first.
///
/// [errorRate] maps Word.id to an error rate in 0.0..1.0.
/// Words without an entry are treated as 0.0. Order is stable for ties.
List<Word> prioritizeWeakWords({
  required List<Word> words,
  required Map<String, double> errorRate,
  int? limit,
}) {
  final indexed = words.asMap().entries.toList();
  indexed.sort((a, b) {
    final ra = errorRate[a.value.id] ?? 0.0;
    final rb = errorRate[b.value.id] ?? 0.0;
    final cmp = rb.compareTo(ra);
    if (cmp != 0) return cmp;
    return a.key.compareTo(b.key);
  });
  final ordered = indexed.map((e) => e.value).toList();
  if (limit == null || limit >= ordered.length) return ordered;
  return ordered.sublist(0, limit);
}

double errorRateFor({required int attempts, required int errors}) {
  if (attempts <= 0) return 0.0;
  return (errors / attempts).clamp(0.0, 1.0);
}

/// Builds Word.id -> error rate from weak items keyed as "<kind>:<answer>".
///
/// Matches when the weak key's answer equals the word's Korean or Japanese
/// meaning. Keeps the max rate on multiple matches.
Map<String, double> ratesForWords({
  required List<Word> words,
  required List<({String key, double rate})> weakRates,
}) {
  final rates = <String, double>{};
  for (final word in words) {
    double best = 0.0;
    for (final w in weakRates) {
      final sep = w.key.indexOf(':');
      final answer = sep < 0 ? w.key : w.key.substring(sep + 1);
      if (answer.isNotEmpty &&
          (answer == word.korean || answer == word.meaningJa)) {
        if (w.rate > best) best = w.rate;
      }
    }
    if (best > 0) rates[word.id] = best;
  }
  return rates;
}
