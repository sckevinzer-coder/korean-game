import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/word.dart';

Future<List<Word>> loadWordsForLevel(int level) async {
  final raw = await rootBundle.loadString('assets/words/topik$level.json');
  final decoded = jsonDecode(raw);
  if (decoded is! List) {
    throw const FormatException('Word asset must be a JSON array');
  }
  return decoded
      .whereType<Map<String, dynamic>>()
      .map(Word.fromJson)
      .where((w) => w.topikLevel == level)
      .toList();
}
