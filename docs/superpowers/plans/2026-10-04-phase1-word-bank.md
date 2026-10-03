# Phase 1: Word Bank Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand word assets to TOPIK 1–6 with 500+ words each, validated and wired into level selection.

**Architecture:** Word data stays as bundled JSON (same `Word` schema, no model change). A `tool/validate_words.dart` script enforces schema/dup/level rules; `test/words/word_bank_test.dart` runs it over all assets. Level select lists 1–6 with per-level counts.

**Tech Stack:** Flutter, Dart, JSON assets, flutter_test, flutter analyze + flutter test + flutter build web.

**Spec:** `docs/superpowers/specs/2026-10-04-difficulty-expansion-design.md` (Phase 1 section)

## Global Constraints

- UI language: Japanese
- Offline only; no server, no accounts
- Word schema unchanged: id, korean, reading (romaji), meaning_ja, example_ko, example_ja, topikLevel
- ID format: `t<level>-<nnn>` (e.g. `t3-001`), unique per file
- 500+ words per level, levels 1–6
- Quiz ≥4-word gate unchanged; 1–3 word pools must never reach QuizScreen unguarded
- Out of scope: new quiz formats (Phase 2), TTS (Phase 3), user word lists, sync

## Review Focus

- Duplicate Korean word within the same level file (expect validation to fail the asset)
- Entry whose `topikLevel` field disagrees with its filename (expect failure)
- Malformed entry (missing/empty field) slipping into a 500-word file (expect failure)
- Level select showing a level whose asset failed to load (expect error state, not crash)
- Quiz launched with fewer than 4 words after asset changes (expect ≥4 gate or graceful message)

---

### Task 1: Word validation tooling

**Files:**
- Create: `tool/validate_words.dart`
- Create: `test/words/word_bank_test.dart`

**Interfaces:**
- Produces: `tool/validate_words.dart` exits non-zero listing violations; checks per file: valid JSON array, every entry has all 7 fields non-empty, id matches `^t<level>-\d+$` with level == filename level, no duplicate id, no duplicate korean within file
- Produces: `word_bank_test.dart` runs validation over `assets/words/topik{1..6}.json` (skips missing files with a clear message until Tasks 2–7 land them)

- [ ] **Step 1: Write the failing test**

```dart
test('word bank validation passes', () {
  expect(validateAllLevels(), isEmpty);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/words/word_bank_test.dart`
Expected: FAIL (validator/tool missing)

- [ ] **Step 3: Implement validator + wire test to existing topik1/topik2 assets**

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/words/word_bank_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tool/validate_words.dart test/words/word_bank_test.dart
git commit -m "feat: word bank validation tooling"
```

### Task 2: TOPIK 1 — expand to 500 words

**Files:**
- Modify: `assets/words/topik1.json`
- Test: `test/words/word_bank_test.dart` (already covers)

**Interfaces:**
- Consumes: Task 1 validator

- [ ] **Step 1: Generate words in batches of ~100** (5 batches; beginner nouns/verbs/adjectives/adverbs, everyday topics; each entry: korean, romaji reading, concise meaning_ja, natural example_ko + example_ja; ids `t1-001`… continuing after existing entries — existing 5 keep their ids, renumber or append from `t1-006`)
- [ ] **Step 2: Run validation**

Run: `dart run tool/validate_words.dart` (or via flutter test)
Expected: PASS, count ≥ 500

- [ ] **Step 3: Run full suite**

Run: `flutter test`
Expected: PASS (existing quiz tests use small pools, unaffected)

- [ ] **Step 4: Commit**

```bash
git add assets/words/topik1.json
git commit -m "feat: expand TOPIK 1 word bank to 500+"
```

### Task 3: TOPIK 2 — expand to 500 words

Same steps as Task 2 with `topik2.json`, ids `t2-001`… (keep/renumber existing 5 the same way).

### Task 4: TOPIK 3 — create 500 words

Same steps with `assets/words/topik3.json`, ids `t3-001`…, intermediate vocabulary.

### Task 5: TOPIK 4 — create 500 words

Same steps with `assets/words/topik4.json`, ids `t4-001`….

### Task 6: TOPIK 5 — create 500 words

Same steps with `assets/words/topik5.json`, ids `t5-001`…, advanced vocabulary, formal/written words.

### Task 7: TOPIK 6 — create 500 words

Same steps with `assets/words/topik6.json`, ids `t6-001`…, advanced vocabulary, idioms/proverbs welcome.

### Task 8: Level select 1–6 + QA

**Files:**
- Modify: `lib/screens/level_select_screen.dart` (levels [1..6], per-level word counts)
- Modify: `test/screens/level_select_screen_test.dart`

**Interfaces:**
- Consumes: all six asset files via `loadWordsForLevel`

- [ ] **Step 1: Update widget tests** — lists 6 levels with counts; selecting level 6 starts session with level-6 words; load failure shows Japanese error
- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/screens/level_select_screen_test.dart`
Expected: FAIL

- [ ] **Step 3: Implement levels 1–6 + counts in `LevelSelectScreen`**
- [ ] **Step 4: Run tests + analyze + full suite**

Run: `flutter test`, `flutter analyze`, `flutter build web`
Expected: all green

- [ ] **Step 5: Commit**

```bash
git add lib/screens/level_select_screen.dart test/screens/level_select_screen_test.dart
git commit -m "feat: level select for TOPIK 1-6"
```
