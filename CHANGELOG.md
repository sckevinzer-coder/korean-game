# Changelog

## 1.7.0

### Mini-game
- Match-pairs mini-game (Home 🧩 icon): 4 Korean words paired with
  meanings in a tappable grid, +100 per pair, -20 per mistake,
  clear bonus + best-of score display.
- Localized result and instructions (JA/KO/EN coverage included).

### Tests
- 183 tests passing (`flutter test`), `flutter analyze` zero issues.

## 1.6.0

### Offline TTS cache
- `CachedTtsService` synthesizes repeated words to wav on mobile/desktop
  (via `flutter_tts.synthesizeToFile` + `audioplayers`), keyed by
  text/rate/pitch/voice with an LRU cap (200), eviction, and per-playback
  fallback to live speech when synthesis fails or the cache is cold.
- Web keeps live `speechSynthesis` (passthrough) — browsers cannot capture
  synthesized audio.
- SSML bypasses the cache. "音声キャッシュ削除" button in the stats
  データ管理 section; hit playback reports a full-span progress event.

### Translation review
- `docs/TRANSLATION_REVIEW.md` contains all 203 keys with JA source and
  KO/EN draft columns for review.

### Tests
- 179 tests passing (`flutter test`), `flutter analyze` zero issues.

## 1.5.0

### i18n (JA/KO/EN)
- Full UI localization: home, level select, stats, quiz, flashcards,
  bookmarks, review notebook, writing feedback, achievements,
  notifications, kind labels, suggestions, and weekday labels.
- Japanese stays the default and fallback; Korean and English cover
  every key with `{param}` substitution.
- Language switcher in the Home app bar, persisted in `stats.db`
  settings, forwarded through the navigation chain (no new queries).
- Listening prompts stay in Korean by design (listening exercise).

### Tests
- 170 tests passing (`flutter test`), `flutter analyze` zero issues.

## 1.4.0

### Lenient writing grading
- New `lenient` mode in `WritingGrader` accepting verb/adjective ending
  variations (먹어요 vs 먹다) while still rejecting stem differences.
- `やさしい採点（語尾OK）` toggle in the quiz 出題設定 menu, persisted in
  `stats.db` settings and applied to grading plus live hints.

### Data transfer (B4)
- Versioned JSON export/import of study days, sessions (with level),
  achievements, freezes, settings, error stats, and bookmarks.
- Merge-on-import (no duplicates); SRS progress stays device-local.
- エクスポート/インポート UI in the stats データ管理 section with
  clipboard copy and invalid-payload handling.

### Achievement expansion
- `10連続正解` (10-answer combo in one session) and `全レベル完全制覇`
  (perfect 5+ question session in each of levels 1–6).

### Quality
- `flutter analyze`: zero issues (was 20).
- Removed dead quiz code (celebration animation, level banner,
  keyboard flag) and fixed async-context and interop lints.
- `stats.db` v3 migration adding the settings table.

### Tests
- 159 tests passing (`flutter test`).

## 1.3.0

### Review reinforcement
- Review reminders: browser Notification with due-card count on Home
  open (web only, opt-in button when permission undecided, silent
  no-op elsewhere).
- Wrong-answer notebook (間違いノート): top-20 error entries with word,
  example sentence, miss counts, and accuracy, plus a review quiz;
  opened from the stats screen weak section.
- Daily goal: configurable target (5/10/20/30 questions) with a
  progress ring on Home, counted from recorded session totals.

### Tests
- 145 tests passing (`flutter test`).

## 1.2.0

### Quiz improvements
- Time attack mode (10 seconds per question) via 出題設定 menu or
  `timeAttack` flag, with countdown bar, timeout-as-wrong handling,
  and average answer time on the result screen.
- Confusable-first distractors: error-prone words are prioritized as
  answer options when error data exists (toggleable, default on,
  session regenerates on toggle).
- Streak freeze: a single missed day is bridged once per week
  (Monday-based), shown on Home as remaining uses.

### Stats dashboard
- 30-day activity bar chart (月間レポート) reusing `study_days`.
- Accuracy trend line over the last 10 sessions with average rate,
  recorded automatically on quiz completion (`sessions` table).
- Six achievement badges (初クイズ, 3日連続, 7日連続, 正答率80%,
  100問正解, 全レベル制覇) with unlock dialog, haptics, and a badge
  grid on the stats screen.

### Database
- `stats.db` v2 migration (freezes, sessions with level, achievements),
  preserving v1 study days.

### Tests
- 133 tests passing (`flutter test`).

## 1.1.0

### Vocabulary & levels
- TOPIK 1–6 word banks, 500 words each (3,000 total).
- Level select with per-level progress bars, streak banner, and quiz-format legend.
- Quiz pools require at least 4 words, with a notice otherwise.

### Quiz formats
- Level-based question mix: levels 1–2 (meaning ↔ word), 3–4 (+ listening, blank),
  5–6 (+ writing).
- Listening questions with replay, fallback text toggle, and adjustable speech rate.
- Blank questions with inline input on level 3+.
- Writing questions with particle-tolerant grading.

### Writing analysis (levels 5–6)
- Detailed Hangul analysis: vowel / consonant / particle / missing / extra errors.
- Real-time similarity hint while typing and per-error chips after grading.
- Near-miss partial bonus shown separately (integer scores unchanged).
- Model-answer audio playback ("お手本を聞く") and writing hints.

### TTS
- Speech rate / pitch / volume controls on mobile and web.
- Voice selection (`getVoices` / `setVoice`).
- SSML support (`speakSsml`, plain-text fallback on web).
- Playback progress callbacks (`setProgressHandler`).

### Learning feedback
- Session streak display and per-kind accuracy analysis with review suggestions.
- Persistent error stats with top-weak list and adaptive review ordering.
- Statistics dashboard: streak, totals, per-level progress, 7-day report,
  and level review quizzes.
- Bookmarks: save from flashcards/quiz, list, delete, and bookmark quizzes.
- Haptic feedback on key interactions.

### First-run & empty states
- Home onboarding card (level → flashcards → quiz).
- Empty-state messages for quiz, flashcards, bookmarks, and stats.
- Load-failure messages for word assets and database timeouts.

### Tests
- 107 tests passing (`flutter test`), covering SRS, stores, quiz generation,
  writing grading, TTS, screens, bookmarks, error stats, analytics, and
  the full study cycle.
