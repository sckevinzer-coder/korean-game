# Korean Vocab SRS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Flutter mobile app that teaches beginner Korean vocabulary with SRS flashcards, quizzes, TOPIK-level word sets, and Japanese UI.

**Architecture:** Single Flutter app, offline-first. Word data bundled as JSON asset; learning progress and stats in local SQLite (drift or sqflite). Riverpod for state. Pure Dart `SrsScheduler` class owns interval logic; UI layers consume it.

**Tech Stack:** Flutter, Dart, Riverpod, sqflite, JSON assets, flutter_test / widget_test, flutter analyze + flutter test.

**Spec:** `docs/superpowers/specs/2026-10-03-korean-vocab-srs-design.md`

## Global Constraints

- UI language: Japanese
- Target learner: beginner Korean (can read Hangul)
- Offline only; no server, no accounts
- TOPIK levels start at 1급
- SRS grades: 다시/어려움/보통/쉬움 (4단계)
- Quiz formats: 뜻 맞히기 / 단어 맞히기 (4지선다)
- Out of scope: TTS, user-editable word lists, sync

## Review Focus

- Same-day "due" cards must not reappear in the same session (expect due_date > reviewed_at filtering)
- New words not yet studied must appear in "today's" count alongside due reviews
- Streak must increment only once per calendar day, reset after a missed day
- Quiz options must contain exactly 4 distinct entries including the correct one
- Words from the wrong TOPIK level must never leak into a level's session

---

### Task 1: Environment & project scaffold

**Files:**
- Create: Flutter project at repo root (`pubspec.yaml`, `lib/main.dart`)
- Create: `assets/words/topik1.json` (sample)
- Modify: `.gitignore`

- [ ] Install Flutter SDK (e.g. `brew install --cask flutter` or FVM), verify `flutter doctor`
- [ ] `git init` (done) and commit spec docs: `git add docs && git commit -m "docs: add design spec"`
- [ ] Run `flutter create .` in repo root, pick org `com.example`
- [ ] Verify `flutter test` passes on the default counter test
- [ ] Commit: `chore: scaffold Flutter project`

### Task 2: Word data model + bundled asset

**Files:**
- Create: `lib/models/word.dart`
- Create: `assets/words/topik1.json`
- Test: `test/models/word_test.dart`

**Interfaces:**
- Produces: `class Word { final String id; final String korean; final String reading; final String meaningJa; final String exampleKo; final String exampleJa; final int topikLevel; factory Word.fromJson(Map<String,dynamic>); }`
- Produces: `Future<List<Word>> loadWordsForLevel(int level)` in `lib/data/word_repository.dart`

- [ ] Write test: parses a JSON entry into Word with all fields; throws FormatException on missing field
- [ ] Run: `flutter test test/models/word_test.dart` → FAIL
- [ ] Implement `Word.fromJson` + minimal `topik1.json` (5 words is enough for dev)
- [ ] Write test: `loadWordsForLevel(1)` returns only level-1 words
- [ ] Implement `WordRepository.loadWordsForLevel`
- [ ] Verify tests pass; commit `feat: add Word model and repository`

### Task 3: SRS scheduler

**Files:**
- Create: `lib/srs/srs_scheduler.dart`
- Test: `test/srs/srs_scheduler_test.dart`

**Interfaces:**
- Produces: `enum Grade { again, hard, good, easy }`
- Produces: `class SrsCard { String wordId; Duration interval; double ease; DateTime dueDate; }`
- Produces: `SrsCard schedule(SrsCard card, Grade grade, DateTime now)`

- [ ] Test: `again` resets interval to 1 minute and keeps dueDate ~now+1m
- [ ] Test: `good` multiplies interval by ease (min 1 day first time)
- [ ] Test: `easy` increases ease more than `hard`
- [ ] Test: dueDate is set to now + interval
- [ ] Implement minimal scheduler to pass; commit `feat: add SRS scheduler`

### Task 4: Progress persistence

**Files:**
- Create: `lib/db/progress_store.dart`
- Test: `test/db/progress_store_test.dart`

**Interfaces:**
- Produces: `class ProgressStore { Future<void> upsert(SrsCard card); Future<List<SrsCard>> dueCards(DateTime now); Future<List<SrsCard>> allCardsForLevel(int level); }`

- [ ] Test: upsert then dueCards returns only cards with dueDate <= now
- [ ] Test: newly studied card due later today is excluded from dueCards(now)
- [ ] Use sqflite (or sqflite_common_ffi for tests); commit `feat: persist card progress`

### Task 5: Home screen (today's counts)

**Files:**
- Create: `lib/screens/home_screen.dart`
- Modify: `lib/main.dart`
- Test: `test/screens/home_screen_test.dart`

**Interfaces:**
- Consumes: `ProgressStore.dueCards`, `WordRepository.loadWordsForLevel`

- [ ] Widget test: shows count of due cards and streak
- [ ] Implement screen; commit `feat: home screen with due count and streak`

### Task 6: Flashcard session

**Files:**
- Create: `lib/screens/flashcard_screen.dart`
- Test: `test/screens/flashcard_screen_test.dart`

**Interfaces:**
- Consumes: `WordRepository`, `ProgressStore`, `SrsScheduler.schedule`

- [ ] Widget test: tap card flips to reveal meaning; selecting a grade persists via ProgressStore and advances to next card
- [ ] Implement; commit `feat: flashcard study session`

### Task 7: Quiz session

**Files:**
- Create: `lib/screens/quiz_screen.dart`
- Create: `lib/quiz/quiz_generator.dart`
- Test: `test/quiz/quiz_generator_test.dart`

**Interfaces:**
- Produces: `class QuizQuestion { String prompt; List<String> options; int correctIndex; QuizKind kind; }`, `enum QuizKind { meaningToWord, wordToMeaning }`
- Produces: `QuizQuestion makeQuestion(Word target, List<Word> pool, QuizKind kind, Random rng)`

- [ ] Test: exactly 4 distinct options, one correct, wrong options drawn from same level pool
- [ ] Test: both quiz kinds produce question/answer from the right fields
- [ ] Widget test: answering updates score; commit `feat: quiz session`

### Task 8: Streak & stats

**Files:**
- Create: `lib/stats/stats_store.dart`
- Test: `test/stats/stats_store_test.dart`

**Interfaces:**
- Produces: `class StatsStore { Future<void> recordStudy(DateTime day); Future<int> currentStreak(DateTime today); }`

- [ ] Test: same day twice doesn't double-count; consecutive days increment; gap resets
- [ ] Implement; commit `feat: study streak tracking`

### Task 9: Level selection + seed more words

**Files:**
- Create: `lib/screens/level_select_screen.dart`
- Modify: `assets/words/` (add topik2.json skeleton)

- [ ] Screen lists TOPIK levels; selecting one starts a session with that level's words
- [ ] Commit `feat: level selection`

### Task 10: QA pass

- [ ] `flutter analyze` clean
- [ ] `flutter test` all green
- [ ] Manual smoke: one full daily cycle (home → flashcards → quiz → result)
- [ ] Commit `chore: QA pass`
