# Phase 2: New Quiz Formats + TTS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add listening / writing / sentence-blank question formats with level-weighted session mix, backed by a platform-abstracted TTS service (mobile flutter_tts, web Speech Synthesis).

**Architecture:** `QuizKind` gains `listeningWord`, `listeningMeaning`, `blank`, `writing`; `QuizQuestion` gains nullable `audioText` (exact string TTS speaks — never the Japanese instruction prompt). `TtsService` interface with conditional-import implementations (mobile `flutter_tts`, web `dart:js_interop` SpeechSynthesis, noop fallback for tests). `QuizScreen` takes `tts` + `level`, builds kind list from level, renders replay button / fallback-text toggle / writing input.

**Tech Stack:** Flutter, Dart, flutter_tts (mobile only via conditional import), dart:js_interop (web), flutter_test, flutter analyze + flutter test + flutter build web.

**Spec:** `docs/superpowers/specs/2026-10-04-difficulty-expansion-design.md` (Phase 2 + Phase 3 TTS sections)

## Global Constraints

- UI language: Japanese
- Offline only; no server (Web Speech API uses OS/browser voices, no network dependency in code)
- Listening prompt NEVER spoken — only `audioText` (target.korean) is spoken
- 4 distinct options including correct one for all choice kinds; blank falls back (returns null) when the word/stem is absent from exampleKo
- Quiz ≥4-word gate unchanged (makeQuestion still throws below 3 distractors)
- Writing grading: whitespace/punctuation-insensitive; particle-insensitive by default (`ignoreParticles: true`), exact otherwise
- Level mix: 1–2 → meaningToWord/wordToMeaning only; 3–4 → adds listeningWord/listeningMeaning/blank; 5–6 → adds writing
- Out of scope: user word lists, sync, typo-tolerant (edit-distance) grading

## Review Focus

- A listening question whose `audioText` is null or the Japanese prompt (expect always target.korean, never null for listening kinds)
- A blank question whose prompt contains no blank marker (expect ＿＿ present; null returned otherwise)
- Writing input " 먹다 " with spaces grading wrong (expect correct after normalization)
- QuizScreen with `tts` that throws on speak crashing the session (expect fire-and-forget, session continues)
- Web build referencing `dart:html` or mobile-only TTS import (expect conditional imports only; `flutter build web` must pass)

---

### Task 1: TtsService + platform implementations

**Files:**
- Create: `lib/tts/tts_service.dart` (abstract + `NoopTtsService` + `createTtsService()` via conditional export)
- Create: `lib/tts/tts_service_stub.dart` (mobile: flutter_tts, ko-KR)
- Create: `lib/tts/tts_service_web.dart` (dart:js_interop SpeechSynthesis, lang ko-KR)
- Test: `test/tts/tts_service_test.dart`
- Modify: `pubspec.yaml` (add flutter_tts)

**Interfaces:**
- Produces: `abstract class TtsService { Future<void> speak(String text); Future<void> stop(); }`
- Produces: `class NoopTtsService implements TtsService` (does nothing, completes)
- Produces: `TtsService createTtsService()` (conditional: web impl on `dart.library.js_interop`, flutter_tts elsewhere)

- [ ] **Step 1: Write the failing test**

```dart
test('noop completes without doing anything', () async {
  await NoopTtsService().speak('안녕');
});
test('factory returns a service', () {
  expect(createTtsService(), isA<TtsService>());
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/tts/tts_service_test.dart`
Expected: FAIL (no such file/class)

- [ ] **Step 3: Implement interface + noop + conditional factory + both platform impls** (flutter_tts: setLanguage('ko-KR') once, speak/stop delegate; web: SpeechSynthesisUtterance with lang='ko-KR', cancel-then-speak; never import flutter_tts or js_interop outside their own files)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/tts/tts_service_test.dart`, `flutter analyze`, `flutter build web`
Expected: PASS, clean, web builds

- [ ] **Step 5: Commit**

```bash
git add lib/tts test/tts pubspec.yaml pubspec.lock
git commit -m "feat: TTS service with mobile and web implementations"
```

### Task 2: Listening + blank question generation

**Files:**
- Modify: `lib/quiz/quiz_generator.dart`
- Test: `test/quiz/quiz_generator_test.dart` (extend)

**Interfaces:**
- Consumes: `Word`, existing `makeQuestion` distractor logic
- Produces: `QuizKind.listeningWord`, `QuizKind.listeningMeaning`, `QuizKind.blank`
- Produces: `QuizQuestion.audioText` (`String?`, null except listening kinds where it equals target.korean)
- Produces: `QuizQuestion? makeBlankQuestion(Word target, List<Word> pool, Random rng)` (null when neither korean nor 다-stripped stem found in exampleKo; prompt replaces first occurrence with ＿＿)

- [ ] **Step 1: Write failing tests** — listeningWord: audioText == target.korean, prompt is Japanese instruction (contains 聞いて), options are 4 distinct korean; listeningMeaning: same audio, options are meanings; blank: prompt contains ＿＿ and not the word, correct is korean; blank returns null when word absent from example
- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/quiz/quiz_generator_test.dart`
Expected: FAIL

- [ ] **Step 3: Implement new kinds in `makeQuestion` + `makeBlankQuestion`** (blank distractors = korean from pool, same 4-distinct rule, throws below 3 like others)
- [ ] **Step 4: Run to verify they pass**

Run: `flutter test test/quiz/quiz_generator_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/quiz/quiz_generator.dart test/quiz/quiz_generator_test.dart
git commit -m "feat: listening and blank question generation"
```

### Task 3: Writing grader

**Files:**
- Create: `lib/quiz/writing_grader.dart`
- Test: `test/quiz/writing_grader_test.dart`

**Interfaces:**
- Produces: `bool gradeWriting(String input, String answer, {bool ignoreParticles = true})`

- [ ] **Step 1: Write failing tests** — exact match true; surrounding/inner whitespace ignored (' 먹다 ' vs '먹다'); 。/period ignored; particle-insensitive ('먹다를' vs '먹다' → true by default, false with ignoreParticles:false); wrong word false; empty input false
- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/quiz/writing_grader_test.dart`
Expected: FAIL

- [ ] **Step 3: Implement normalization** (strip all whitespace + 。.?!, then if ignoreParticles strip ONE trailing particle from {은,는,이,가,을,를,에,에서,으로,로,와,과,도,만,의} on both sides, compare)
- [ ] **Step 4: Run to verify they pass**

Run: `flutter test test/quiz/writing_grader_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/quiz/writing_grader.dart test/quiz/writing_grader_test.dart
git commit -m "feat: writing answer grader"
```

### Task 4: QuizScreen — audio, writing UI, level mix

**Files:**
- Modify: `lib/screens/quiz_screen.dart`
- Test: `test/screens/quiz_screen_test.dart` (extend)

**Interfaces:**
- Consumes: Task 1 `TtsService`/`NoopTtsService`, Task 2 kinds + `makeBlankQuestion`, Task 3 `gradeWriting`
- Produces: `QuizScreen(..., {TtsService? tts, int level = 1})` (tts defaults to `createTtsService()`)

- [ ] **Step 1: Update/extend widget tests** — kind mix by level (level 1: only meaningToWord/wordToMeaning; level 4: includes listening+blank; level 6: includes writing); listening shows 🔊 replay button and speaks audioText via injected fake TtsService exactly once on display; writing shows TextField, correct input scores; fallback-text toggle reveals audioText; tts throwing does not crash session
- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/screens/quiz_screen_test.dart`
Expected: FAIL

- [ ] **Step 3: Implement** — kind list per level rule (rotation `i % kinds.length` like current code; blank via makeBlankQuestion with wordToMeaning fallback when null); auto-speak audioText on question display (post-frame, fire-and-forget, errors swallowed); replay button; テキストを見る toggle; writing TextField + 回答する button graded by gradeWriting; score counts writing-correct
- [ ] **Step 4: Run to verify they pass**

Run: `flutter test test/screens/quiz_screen_test.dart`, `flutter analyze`
Expected: PASS, clean

- [ ] **Step 5: Commit**

```bash
git add lib/screens/quiz_screen.dart test/screens/quiz_screen_test.dart
git commit -m "feat: audio, writing input, and level-weighted mix in quiz"
```

### Task 5: QA pass

- [ ] **Step 1: Run full suite**

Run: `flutter test`
Expected: all green (existing 48 + new)

- [ ] **Step 2: Run analyze + web build**

Run: `flutter analyze`, `flutter build web`
Expected: clean, builds (proves no mobile-only TTS import leaks to web)

- [ ] **Step 3: Commit if fixes needed, else empty**

```bash
git commit -m "chore: phase 2 QA pass"  # only if changes; skip if clean
```
