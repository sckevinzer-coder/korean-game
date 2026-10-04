# Changelog

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
