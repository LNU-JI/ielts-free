# IELTS Free

**Free and Offline IELTS Learning App**

[![Tests](https://github.com/LNU-JI/ielts-free/actions/workflows/tests.yml/badge.svg)](https://github.com/LNU-JI/ielts-free/actions/workflows/tests.yml)
[![Release](https://img.shields.io/github/v/release/LNU-JI/ielts-free?label=release)](https://github.com/LNU-JI/ielts-free/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.47.5-02569B?logo=flutter&logoColor=white)](https://flutter.dev)

> IELTS Free is an independent, offline-first, open-source IELTS learning app.
> No account required. No server required. No AI required.
> Learn anywhere. Learn offline. Learn for free.

✓ Offline &nbsp;&nbsp; ✓ Free &nbsp;&nbsp; ✓ Open Source &nbsp;&nbsp; ✓ No AI required &nbsp;&nbsp; ✓ No account required &nbsp;&nbsp; ✓ Adaptive learning &nbsp;&nbsp; ✓ Android &nbsp;&nbsp; ✓ Windows

---

## Download

**Latest release: [v0.1.0](https://github.com/LNU-JI/ielts-free/releases/latest)**

| Platform | File | Size |
| --- | --- | --- |
| Android | [`IELTS-Free-Android-v0.1.0.apk`](https://github.com/LNU-JI/ielts-free/releases/download/v0.1.0/IELTS-Free-Android-v0.1.0.apk) | 57 MB |
| Windows 10/11 (x64) | [`IELTS-Free-Windows-v0.1.0.zip`](https://github.com/LNU-JI/ielts-free/releases/download/v0.1.0/IELTS-Free-Windows-v0.1.0.zip) | 13 MB |
| Checksums | [`SHA256SUMS.txt`](https://github.com/LNU-JI/ielts-free/releases/download/v0.1.0/SHA256SUMS.txt) | — |

Verify a download before installing:

```powershell
Get-FileHash .\IELTS-Free-Android-v0.1.0.apk -Algorithm SHA256
```

The APK is signed with the **debug** keystore, so Android will warn about an
unknown developer. A real signing key is on the pre-publish checklist in
[`docs/RELEASING.md`](docs/RELEASING.md).

Every release is produced by GitHub Actions from a version tag, so the binaries
always match the tagged source. Source archives (`zip` / `tar.gz`) are attached
automatically by GitHub.

> **Prefer to build it yourself?** See [Installation](#installation). The whole
> point of this project is that the source builds with a plain Flutter SDK and
> **zero code-generation steps**.
>
> **Maintainers:** see [`docs/RELEASING.md`](docs/RELEASING.md) for how to push,
> tag and publish a release through GitHub Actions. You do **not** need a local
> Android SDK or Visual Studio — the CI runners provide both.

---

## Features

- **Today, in one screen.** A dashboard that answers "what should I study today?"
  — target band, exam countdown, daily progress bar, today's task list, five skill
  scores, study streak and minutes studied.
- **Vocabulary that sticks.** Spaced-repetition memory levels (L0–L6) with the
  intervals 4h / 1d / 3d / 7d / 14d / 30d / 60d, seven practice question types,
  phonetics, collocations, IELTS Writing & Speaking usage and example sentences.
- **Reading practice with real explanations.** Original passages with
  True/False/Not Given, Multiple Choice and Summary Completion questions. Every
  question stores evidence, keywords, synonym substitutions, logic and explanation.
- **Mistakes that teach.** Every wrong answer is collected automatically, tagged by
  error type, and can be re-done until mastery.
- **An adaptive engine.** Skill scores, training priority, difficulty adjustment,
  memory scheduling, streak tracking and a daily planner — all running locally.
- **Offline first.** The core learning loop never touches the network. The Android
  release build does not even request the `INTERNET` permission.
- **Local data first.** Two SQLite databases: a read-only **content** database and a
  read-write **user** database. Your progress stays on your device.
- **No account, no tracking, no ads, no paywall.**

---

## Screenshots

> Screenshots are added with the first public release. The `assets/images/`
> directory is reserved for app artwork.

```
┌────────────────────────────┐   ┌────────────────────────────┐
│  IELTS Free   Target 7.0   │   │  analyze  /ˈænəlaɪz/   v.  │
│                            │   │  🔊                        │
│  今日进度 ▓▓▓▓▓▓░░░░ 40%   │   │  中文释义：分析；解析       │
│                            │   │  英文释义：to examine...   │
│  今日任务                   │   │  常见搭配：analyze data    │
│   ☑ 词汇复习 20 词 · 15min │   │                            │
│   ☐ 阅读 1 篇 · 20 min     │   │  [ ✓ 掌握 ]  [ ✗ 不认识 ]  │
│                            │   │                            │
│  我的能力                   │   └────────────────────────────┘
│   Vocab 52  Reading 48     │
│   List 35   Write 40       │
│   Speak 38                 │
└────────────────────────────┘
```

---

## Installation

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) with Dart **3.4+**
  (`flutter --version` should report a Flutter version `>= 3.22.0`).
- Android builds: Android SDK + JDK 17.
- Windows builds: Visual Studio 2022 with the **Desktop development with C++**
  workload.

### From source

```bash
git clone https://github.com/<your-user>/ielts-free.git
cd ielts-free

# Route B needs NO code generation. This is the entire setup step.
flutter pub get
```

### Run

```bash
# Windows desktop
flutter run -d windows

# Android device or emulator
flutter run -d android

# Android release APK
flutter build apk --release
# -> build/app/outputs/flutter-apk/app-release.apk

# Windows release bundle
flutter build windows --release
# -> build/windows/x64/runner/Release/
```

### A note on code generation (important)

This project deliberately uses **sqflite + sqflite_common_ffi** with hand-written
SQL and DAOs instead of Drift. That means:

- there is **no `build_runner`**, no `*.g.dart`, no `*.freezed.dart`;
- you never run a codegen step — `flutter pub get` is all you need;
- the data layer is plain, auditable Dart (see `docs/ARCHITECTURE-v0.1.md` §2.1).

CI (`.github/workflows/tests.yml`) reflects this: it runs `flutter pub get`,
`flutter analyze` and `flutter test`, and nothing else.

### If `flutter analyze` exits with code 255

```
Analyzing ielts_free...
analysis server exited with code 255 and output:
[stderr] #7  LspByteStreamServerChannel.listen.<anonymous closure> ...
```

This is a **Dart analysis-server defect with non-ASCII characters in the project
path**. It is not caused by your code: a minimal 10-line Flutter project crashes
the same way when placed under a path containing e.g. Chinese characters, while
the identical project at an ASCII path reports `No issues found!`.

`flutter test` is unaffected — only `flutter analyze` (and IDE analysis) break.

**Fix: keep the project on a path made of ASCII characters only.** For example
`D:\workbuddyai\ielts_free` instead of `D:\雅思\workbuddyai\ielts_free`. No code
changes are required; just re-run `flutter pub get` after moving.

### If `flutter test` fails to download SQLite

`sqflite_common_ffi` pulls in `package:sqlite3`, whose build hook downloads a
pre-compiled `sqlite3.x64.windows.dll` **from GitHub Releases** on first use. On
networks where github.com is unreachable you will see:

```
By default, this package downloads a pre-compiled SQLite library.
This failed ... https://github.com/simolus3/sqlite3.dart/releases/download/...
Original cause: SocketException: connection timed out
Building native assets failed.
```

`pubspec.yaml` already contains a `hooks:` section that redirects this download
through a GitHub mirror (`url_pattern`). The artifact is still validated against
the sha256 recorded inside `package:sqlite3`, so a mirror cannot silently
substitute a different binary.

- **If github.com is reachable from your network**, delete the `hooks:` section
  from `pubspec.yaml` — it is only a fallback.
- **Other supported escape hatches** (see the
  [upstream hook docs](https://pub.dev/documentation/sqlite3/latest/topics/hook-topic.html)):
  `source: system` to use the OS-provided SQLite (`winsqlite3.dll` on Windows),
  or `source: source` to compile from `sqlite3.c` with a local C toolchain.

### Restoring platform scaffolding

The `android/` and `windows/` folders are committed. If they are ever missing or
corrupted, regenerate the scaffolding **without touching your code**:

```bash
# Recreates android/ and windows/ from the current Flutter template.
# Your lib/ directory is NOT overwritten.
flutter create --platforms=android,windows .
```

iOS / macOS / Linux are not part of the V0.1 delivery. Add them later with:

```bash
flutter create --platforms=ios,macos,linux .
```

---

## Offline verification

Offline operation is a **hard requirement**, not a nice-to-have. Here is how to
prove it.

### 1. The release APK must not declare `INTERNET`

`android/app/src/main/AndroidManifest.xml` intentionally has **no** `INTERNET`
permission. Only the `debug` and `profile` manifests declare it (Flutter hot
reload needs it). Verify a built release APK with the Android build tools:

```bash
aapt dump permissions build/app/outputs/flutter-apk/app-release.apk
# Expected output: no android.permission.INTERNET line.

# Alternative, with aapt2:
aapt2 dump permissions build/app/outputs/flutter-apk/app-release.apk
```

### 2. Manual airplane-mode acceptance checklist

Turn on **Airplane Mode** (or disable Wi-Fi and mobile data), then confirm every
core screen opens and works with no crash and no spinner that never resolves:

- [ ] Cold start → Onboarding completes (5 steps)
- [ ] Dashboard renders target / countdown / progress / tasks / skills / streak
- [ ] Vocabulary: browse, open a word, practice all question types
- [ ] Reading: open a passage, answer, submit, read explanations
- [ ] Mistakes: list, filter, open detail, re-do a question
- [ ] Study Plan: pick a plan, see the weekly schedule
- [ ] Settings / About: disclaimer text is present
- [ ] Kill the app and reopen → all progress is still there

Nothing in the core path performs an HTTP request, loads a remote font, or talks
to any server. If any of the above fails offline, it is a bug — please file it.

---

## Verifying without a Flutter toolchain

The data layer can be verified with **plain Python 3 (standard library only)** —
no Flutter, Dart, Android SDK or Visual Studio required. This is useful on
build machines or in CI containers where the Flutter toolchain is not installed.

```bash
python tool/verify/verify_content.py        # content DB integrity + checksum + read-only enforcement
python tool/verify/verify_migration.py      # replays DB v1 -> v2 and proves no user data is lost
python tool/verify/verify_daily_plan_floor.py  # exhaustively checks the daily-plan invariants
python tool/verify/colcheck.py              # cross-checks SQL column names against the real schema
python tool/verify/schema_diff.py           # compares the two sources of the content schema
```

These scripts are development-time helpers only — they are never compiled into
the app. See `tool/verify/README.md` for the full list and what each one proves.

> **Note — do not add a nested Dart package to this repository.**
> `flutter analyze` starts an analysis server that loads `package:analyzer`
> internally. A nested package that declares its own `analyzer` dependency
> (e.g. a helper tool with its own `pubspec.yaml` and `.dart_tool/`) makes the
> server create a second analysis context with a conflicting analyzer version,
> and it exits with code 255 before reporting any diagnostics. If you need such
> a helper, keep it **outside** the project directory.

---

## Architecture

IELTS Free is a layered, offline-first Flutter app:

```
                    IELTS Free
          ┌──────────────┴──────────────┐
      Local Content                 Local User Data
   (Vocabulary / Reading)        (Progress / Mistakes /
          │                        Statistics / Plan)
          └──────────────┬──────────────┘
                  Adaptive Engine
                         ↓
                   Daily Planner
                         ↓
                      User
```

Layers (dependencies point strictly downward):

| Layer | Directory | Responsibility |
| --- | --- | --- |
| Presentation | `lib/features/*/presentation`, `lib/shared/widgets` | UI only, no business rules |
| Application | `lib/features/*/application`, `lib/core/providers` | Use-case orchestration (Riverpod) |
| Domain | `lib/core/services`, `lib/core/models` | Pure Dart algorithms, unit-testable |
| Data | `lib/core/database`, `lib/core/storage` | SQLite, DAOs, repositories |

Directory tree:

```
ielts_free/
├── android/ windows/          # committed platform scaffolding
├── assets/                    # seed/ images/ icons/ audio/
├── content_pipeline/          # offline content build & validation scripts
├── docs/                      # architecture & design documents
├── lib/
│   ├── main.dart
│   ├── app/                   # app.dart router.dart theme.dart constants.dart strings.dart
│   ├── core/                  # database/ storage/ services/ utils/ errors/ models/ providers/
│   ├── features/              # onboarding dashboard vocabulary reading mistakes study_plan settings ...
│   └── shared/                # widgets/ extensions/
├── test/  integration_test/
├── README.md  LICENSE  LICENSE-CONTENT  pubspec.yaml
```

Full design (data model, algorithms, file list, task breakdown) lives in
[`docs/ARCHITECTURE-v0.1.md`](docs/ARCHITECTURE-v0.1.md).

---

## Content

- **Original, IELTS-style material only.** Passages and vocabulary are written for
  this project. We do **not** copy official IELTS test papers, answers or other
  copyrighted material.
- Content is produced offline by scripts in `content_pipeline/` (validate →
  build content database → emit `ielts_content_v1.db` + `manifest.json` with a
  SHA256 checksum).
- The app ships a read-only **content database** (assets/seed) and keeps all user
  data in a separate, read-write **user database**.
- The code is MIT-licensed; the educational content is licensed separately. See
  [`LICENSE`](LICENSE) and [`LICENSE-CONTENT`](LICENSE-CONTENT).

**Independence statement:** IELTS Free is an independent educational project and
is not affiliated with IELTS, British Council, IDP Education, or Cambridge
Assessment English.

### License summary

| What | License |
| --- | --- |
| Source code | MIT (see `LICENSE`) |
| Original educational content | Separate content license (see `LICENSE-CONTENT`) |

---

## Roadmap

| Version | Scope |
| --- | --- |
| **v0.1 (MVP)** | Dashboard, Vocabulary, Reading, Mistakes, Adaptive Engine, Daily Plan, Onboarding, local databases, seed content |
| v0.2 | Listening (pre-generated audio), Writing, Speaking, Statistics |
| v0.3 | Achievements, Favorites, Notes, Backup & Import, Content Pack import |
| v1.0 | Complete four-skill coverage, polished adaptive engine, Android + Windows releases |

Out of scope for v0.1 (by design): real-time AI, servers, ads, accounts, cloud
sync, charts, local notifications.

---

## Contributing

Contributions are welcome — code, content, translations, UI polish and bug fixes.
Please read [`CONTRIBUTING.md`](CONTRIBUTING.md) first. Content contributions go
through a review step before they reach the shipped database.

---

## License

MIT for the code, a separate license for the content. See [`LICENSE`](LICENSE)
and [`LICENSE-CONTENT`](LICENSE-CONTENT).

> IELTS Free is an independent educational project and is not affiliated with
> IELTS, British Council, IDP Education, or Cambridge Assessment English.
