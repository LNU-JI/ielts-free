# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Listening module.** The six-step intensive-listening loop distilled from
  established IELTS method: blind listen → sentence dictation → compare with the
  transcript → **classify the error** → shadow the audio → replay the section.
  Audio is synthesised on device with `flutter_tts` (per sentence, slow mode,
  per-speaker pitch), so the content pack ships **no audio files at all** —
  strictly more offline than shipping mp3s. Mistakes are filed under a five-way
  taxonomy (unknown word / phonetics / spelling / comprehension / paraphrase),
  each with advice on how to fix that class of error, and hard sentences can be
  kept in a sentence book for repeat practice.
- **Speaking module.** Part 1/2/3 with the real timings (Part 2 gets 60 s
  preparation and 120 s to speak), cue cards, notes, microphone recording kept
  in the app's own documents directory, replay, and a five-item
  self-assessment. There is deliberately **no AI scoring** — the
  self-assessment is its offline replacement.
- **Writing module.** Timed writing with a live word count that handles mixed
  CJK/Latin text, Task 1 charts drawn with `CustomPainter` (line / bar / pie)
  and a `Table` for tabular data — **no charting dependency** — sample-essay
  comparison with paragraph outline and annotated highlights, and a phrase bank.
- **Statistics page.** Cumulative overview, five-dimension skill radar and a
  predicted band, all drawn with `CustomPainter`, plus the listening error-type
  breakdown.
- **Content pack v2.0.0.** 6 listening sections (97 sentence cues, 31 questions),
  13 speaking topics (51 questions), 10 writing tasks with 10 sample essays and
  45 phrases. All original — no official IELTS material is reproduced.

### Changed

- **User database schema is now v3.** Migration step 3 adds five additive tables
  (`listening_error_log`, `sentence_book`, `speaking_attempts`,
  `writing_attempts`, `phrase_book`). Verified against a real sqlite3 database:
  every v1 table survives with unchanged row counts, user values are untouched
  and `user_version` ends at 3.
- **Two new dependencies**, both for local-only audio: `flutter_tts` synthesises
  the listening audio and `just_audio` replays the user's own recording.
  `audioplayers` was evaluated first but rejected because its dependency tree
  pulls in `http`, which this project bans — the lock file contains no `http`,
  `dio`, `firebase`, `google_fonts`, `web_socket_channel` or
  `shared_preferences`.
- Android gains `RECORD_AUDIO` only. **The release manifest still declares no
  `INTERNET` permission**; the offline red line is intact.

### Fixed

- `listening_questions.options` is an array of `{label, content}` objects, not
  an array of strings — the model would have silently dropped every option of
  every multiple-choice question.
- `writing_samples.outline` is an array of `{section, content}` objects, not an
  array of strings — the paragraph outline would have been dropped.
- `tool/verify/schema_diff.py` normalised SQL comments on one side only, so
  adding the same comment to both schema copies was reported as a difference.
- `tool/verify/verify_migration.py` hard-coded the v2 block and could not read
  Dart triple-quoted strings. It is now version-agnostic: it discovers every
  step in `migrationSteps` and applies them in order.
- **Android build configuration realigned with Flutter 3.47.5.** The scaffolding
  had been written against the Flutter 3.22-era templates and could not build
  with the installed toolchain. Gradle `8.3` → `9.3.1`, Android Gradle Plugin
  `8.1.0` → `9.1.0`, Kotlin `1.9.22` → `2.4.0`, and the build files were migrated
  to the Kotlin DSL to match the official templates. `compileSdk` / `minSdk` /
  `targetSdk` / `versionCode` / `versionName` now come from the `flutter`
  extension instead of hard-coded numbers, so they track the SDK.
- **Windows build configuration realigned with Flutter 3.47.5.** The scaffolding
  had been assembled from a Flutter 3.22-era template and was missing
  `project(ielts_free LANGUAGES CXX)` in `windows/CMakeLists.txt`, so CMake never
  enabled C++ and `flutter build windows` failed on CI. The whole `windows/` tree
  is now reproduced from the installed SDK's templates, with `windows/.gitignore`
  added. Two deliberate local customisations are preserved: the window title reads
  "IELTS Free", and the `IDI_APP_ICON` line in `Runner.rc` stays commented out
  because the project ships no `app_icon.ico` (the SDK's own template placeholder
  is a 0-byte file).
- **Generated files are no longer committed.** `android/.gitignore` was added
  (matching Flutter's own template) and `gradlew`, `gradlew.bat`,
  `gradle-wrapper.jar` and `GeneratedPluginRegistrant.java` were removed from
  version control. `GradleUtils.injectGradleWrapperIfNeeded()` copies the first
  three from the Flutter SDK but deliberately does **not** overwrite files that
  already exist, so committing them froze a stale wrapper. The committed
  `GeneratedPluginRegistrant.java` was stale and omitted `path_provider`, which
  would have thrown `MissingPluginException` at runtime.

### Added

- `docs/RELEASING.md` — how to push, tag and publish a release through GitHub
  Actions, plus what to check before publishing for real.
- `.gitattributes` — normalises line endings so `android/gradlew` cannot be
  checked out with CRLF, which breaks the Android build on Linux CI.
- `tool/verify/` — Python scripts that validate the content database, the schema
  and the database migration without needing a Flutter toolchain.

### Verified

- `flutter analyze` → `No issues found!`
- `flutter test` → `All tests passed!`

## [0.1.0] - 2026-10-01

The first MVP release: a fully offline, adaptive IELTS learning loop.

### Added

- **Project foundation.** Flutter app skeleton with a layered architecture
  (`app/`, `core/`, `features/`, `shared/`), Material 3 design tokens
  (light + dark), and `go_router` navigation with responsive mobile (bottom
  navigation) and desktop (sidebar) shells.
- **Onboarding.** A five-step first-run flow: target band, exam timing, daily
  study time, weakest skill and an initial ability test that seeds the five skill
  scores. Guest mode with a default `local_user`.
- **Dashboard.** Today's plan at a glance: target band, exam countdown, daily
  progress, task list, five skill scores, study streak and minutes studied.
- **Vocabulary.** Word detail (phonetic, part of speech, meanings, collocations,
  IELTS Writing/Speaking usage, examples) with speak / favorite / master / don't
  know actions, seven practice question types, and an L0–L6 spaced-repetition
  memory system (4h / 1d / 3d / 7d / 14d / 30d / 60d).
- **Reading.** Original passages with True/False/Not Given, Multiple Choice and
  Summary Completion questions; a 55/45 desktop split view and a stacked mobile
  view; per-question explanations with evidence, keywords and synonym
  substitutions.
- **Mistakes.** Automatic collection of every wrong answer, error-type taxonomy,
  filtering, detail view and re-do with mastery tracking.
- **Adaptive engine.** Skill scoring, training priority, difficulty adaptation,
  memory scheduling, streak tracking and a daily planner — all local, all
  unit-tested.
- **Data layer.** Two separate SQLite databases: a read-only content database and
  a read-write user database, with versioned migrations that never drop user data.
- **Content pipeline.** Offline scripts to validate and compile seed JSON into
  `ielts_content_v1.db` + a `manifest.json` checksum.
- **CI/CD.** GitHub Actions for analyze + test, Android build, Windows build and
  tag-driven releases with SHA256 checksums. No code-generation steps.
- **Docs & legal.** README with offline verification steps, MIT license for code,
  a separate content license, contribution guidelines, code of conduct and a
  security/privacy policy.

### Notes

- Listening, Writing, Speaking and Statistics are planned for v0.2 and appear as
  greyed-out "V0.2" placeholders in the desktop sidebar.
- This project uses sqflite + sqflite_common_ffi with hand-written SQL, so it
  requires **no** code generation (`build_runner` / `drift` are not used).

[Unreleased]: https://github.com/ielts-free/ielts-free/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/ielts-free/ielts-free/releases/tag/v0.1.0
