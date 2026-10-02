# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
