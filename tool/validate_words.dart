import 'dart:convert';
import 'dart:io';

// Canonical fields (camelCase as stored in assets) with snake_case aliases
// accepted for compatibility with spec wording (meaning_ja/example_ko/example_ja).
const _fieldAliases = <String, List<String>>{
  'id': ['id'],
  'korean': ['korean'],
  'reading': ['reading'],
  'meaningJa': ['meaningJa', 'meaning_ja'],
  'exampleKo': ['exampleKo', 'example_ko'],
  'exampleJa': ['exampleJa', 'example_ja'],
  'topikLevel': ['topikLevel'],
};

Object? _lookup(Map<String, Object?> entry, String canonical) {
  for (final alias in _fieldAliases[canonical]!) {
    if (entry.containsKey(alias)) return entry[alias];
  }
  return null;
}

bool _isNonEmpty(Object? value) {
  if (value == null) return false;
  if (value is String) return value.trim().isNotEmpty;
  if (value is num) return true;
  if (value is bool) return true;
  return true;
}

/// Validates a single level file. Returns a list of violation messages
/// (empty when valid).
List<String> validateLevelFile(File file, int level) {
  final violations = <String>[];
  final path = file.path;

  late final String raw;
  try {
    raw = file.readAsStringSync();
  } catch (e) {
    return ['$path: cannot read file: $e'];
  }

  dynamic decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (e) {
    return ['$path: invalid JSON: $e'];
  }

  if (decoded is! List) {
    return ['$path: valid JSON array expected, found ${decoded.runtimeType}'];
  }

  final idPattern = RegExp('^t$level-\\d+\$');
  final seenIds = <String>{};
  final seenKorean = <String>{};

  for (var i = 0; i < decoded.length; i++) {
    final entry = decoded[i];
    final where = '$path[$i]';
    if (entry is! Map) {
      violations.add('$where: entry must be an object');
      continue;
    }
    final map = Map<String, Object?>.from(entry);

    // All 7 fields non-empty.
    for (final field in _fieldAliases.keys) {
      final value = _lookup(map, field);
      if (!_isNonEmpty(value)) {
        violations.add('$where: field "$field" missing or empty');
      }
    }

    // topikLevel must equal filename level.
    final levelValue = _lookup(map, 'topikLevel');
    if (levelValue != level) {
      violations.add('$where: topikLevel "$levelValue" != file level $level');
    }

    // id format + level match.
    final idValue = _lookup(map, 'id');
    if (idValue is String && idValue.trim().isNotEmpty) {
      final id = idValue.trim();
      if (!idPattern.hasMatch(id)) {
        violations.add('$where: id "$id" must match ^t$level-\\d+\$');
      }
      if (!seenIds.add(id)) {
        violations.add('$where: duplicate id "$id"');
      }
    }

    // No duplicate korean within file.
    final koreanValue = _lookup(map, 'korean');
    if (koreanValue is String && koreanValue.trim().isNotEmpty) {
      final korean = koreanValue.trim();
      if (!seenKorean.add(korean)) {
        violations.add('$where: duplicate korean "$korean"');
      }
    }
  }

  return violations;
}

/// Validates assets/words/topik{1..6}.json. Missing files are skipped with
/// a clear stdout message (Tasks 2-7 land the remaining levels).
/// Returns all violations (empty when valid).
List<String> validateAllLevels({String basePath = 'assets/words'}) {
  final violations = <String>[];
  for (var level = 1; level <= 6; level++) {
    final file = File('$basePath/topik$level.json');
    if (!file.existsSync()) {
      // ignore: avoid_print
      print('SKIP: ${file.path} missing (pending Tasks 2-7)');
      continue;
    }
    violations.addAll(validateLevelFile(file, level));
  }
  return violations;
}

void main() {
  final violations = validateAllLevels();
  if (violations.isEmpty) {
    // ignore: avoid_print
    print('OK: word bank validation passed');
    return;
  }
  for (final v in violations) {
    // ignore: avoid_print
    print('VIOLATION: $v');
  }
  exit(1);
}
