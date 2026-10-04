import 'dart:convert';

import 'bookmark_store.dart';
import 'error_stats.dart';
import 'stats_store.dart';

/// Backup payload version.
const int backupVersion = 1;

/// Summary of an import operation.
class TransferSummary {
  const TransferSummary({
    this.days = 0,
    this.sessions = 0,
    this.achievements = 0,
    this.freezes = 0,
    this.settings = 0,
    this.errorEntries = 0,
    this.bookmarks = 0,
  });

  final int days;
  final int sessions;
  final int achievements;
  final int freezes;
  final int settings;
  final int errorEntries;
  final int bookmarks;
}

/// Exports learning data as a JSON string.
///
/// Covers study days, sessions, achievements, freezes, settings,
/// error stats, and bookmarks. SRS progress is device-local and excluded.
Future<String> exportJson({
  required StatsStore stats,
  ErrorStatsStore? errors,
  BookmarkStore? bookmarks,
}) async {
  final sessions = await stats.allSessions();
  final errorEntries = await errors?.allEntries() ?? const <WeakItem>[];
  final payload = {
    'version': backupVersion,
    'study_days': await stats.allStudyDays(),
    'sessions': [
      for (final s in sessions)
        {
          'day': s.day,
          'total': s.total,
          'correct': s.correct,
          'level': s.level,
        },
    ],
    'achievements': (await stats.unlockedAchievements()).toList(),
    'freezes': await stats.allFreezeWeeks(),
    'settings': await stats.allSettings(),
    'error_stats': [
      for (final e in errorEntries)
        {
          'key': e.key,
          'attempts': e.attempts,
          'errors': e.errors,
          'lastError': e.lastError,
        },
    ],
    'bookmarks': await bookmarks?.allIds() ?? <String>[],
  };
  return jsonEncode(payload);
}

/// Imports a JSON backup, merging into existing data.
///
/// Days, freezes, achievements, and bookmarks merge without duplicates;
/// sessions append; error entries merge by summing attempts/errors.
/// Throws [FormatException] on invalid payloads.
Future<TransferSummary> importJson(
  String json, {
  required StatsStore stats,
  ErrorStatsStore? errors,
  BookmarkStore? bookmarks,
}) async {
  final dynamic decoded;
  try {
    decoded = jsonDecode(json);
  } catch (_) {
    throw const FormatException('Not valid JSON');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Top-level JSON must be an object');
  }
  if (decoded['version'] != backupVersion) {
    throw const FormatException('Unsupported backup version');
  }
  final days = _stringList(decoded, 'study_days');
  final freezes = _stringList(decoded, 'freezes');
  final achievementIds = _stringList(decoded, 'achievements');
  final bookmarkIds = _stringList(decoded, 'bookmarks');
  final settings = _stringMap(decoded, 'settings');
  final sessions = _sessions(decoded);
  final errorEntries = _errorEntries(decoded);

  await stats.importStudyDays(days);
  await stats.importSessions(sessions);
  final now = DateTime.now();
  for (final id in achievementIds) {
    await stats.unlockAchievement(id, now);
  }
  await stats.importFreezeWeeks(freezes);
  await stats.importSettings(settings);
  if (errors != null) {
    await errors.importEntries(errorEntries);
  }
  if (bookmarks != null) {
    for (final id in bookmarkIds) {
      await bookmarks.add(id);
    }
  }
  return TransferSummary(
    days: days.length,
    sessions: sessions.length,
    achievements: achievementIds.length,
    freezes: freezes.length,
    settings: settings.length,
    errorEntries: errorEntries.length,
    bookmarks: bookmarkIds.length,
  );
}

List<String> _stringList(Map<String, dynamic> data, String field) {
  final value = data[field];
  if (value == null) return const [];
  if (value is! List || value.any((e) => e is! String)) {
    throw FormatException('Field "$field" must be a list of strings');
  }
  return [for (final e in value) e as String];
}

Map<String, String> _stringMap(Map<String, dynamic> data, String field) {
  final value = data[field];
  if (value == null) return const {};
  if (value is! Map ||
      value.keys.any((k) => k is! String) ||
      value.values.any((v) => v is! String)) {
    throw FormatException('Field "$field" must be a string map');
  }
  return {for (final e in value.entries) e.key as String: e.value as String};
}

List<SessionRecord> _sessions(Map<String, dynamic> data) {
  final value = data['sessions'];
  if (value == null) return const [];
  if (value is! List) {
    throw const FormatException('Field "sessions" must be a list');
  }
  return [
    for (final e in value)
      if (e is Map &&
          e['day'] is String &&
          e['total'] is int &&
          e['correct'] is int)
        SessionRecord(
          day: e['day'] as String,
          total: e['total'] as int,
          correct: e['correct'] as int,
          level: e['level'] is int ? e['level'] as int : 0,
        )
      else
        throw const FormatException('Invalid session entry'),
  ];
}

List<WeakItem> _errorEntries(Map<String, dynamic> data) {
  final value = data['error_stats'];
  if (value == null) return const [];
  if (value is! List) {
    throw const FormatException('Field "error_stats" must be a list');
  }
  return [
    for (final e in value)
      if (e is Map &&
          e['key'] is String &&
          e['attempts'] is int &&
          e['errors'] is int)
        WeakItem(
          key: e['key'] as String,
          attempts: e['attempts'] as int,
          errors: e['errors'] as int,
          lastError: e['lastError'] is String ? e['lastError'] as String : '',
        )
      else
        throw const FormatException('Invalid error entry'),
  ];
}
