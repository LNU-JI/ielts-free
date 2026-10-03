# Releasing IELTS Free

This project ships **prebuilt binaries through GitHub Releases**, built by
GitHub Actions. You do **not** need a local Android SDK or Visual Studio — the
CI runners provide both.

---

## 1. One-time setup

### 1.1 Create the repository

Create an **empty** repository on GitHub named `ielts-free`.
Do **not** let GitHub add a README, .gitignore or licence — the repository
already contains all of them, and a pre-populated history would conflict.

### 1.2 Point the local clone at it

The local repository is already initialised and has two commits, so you only
need to add the remote and push:

```powershell
cd D:\workbuddyai\ielts_free
git remote add origin https://github.com/<YOUR-USERNAME>/ielts-free.git
git push -u origin main
```

Git will ask for credentials. Use a **Personal Access Token** (classic) as the
password — GitHub no longer accepts account passwords over HTTPS.

Create one at <https://github.com/settings/tokens> with **two** scopes ticked:

| Scope | Why |
| --- | --- |
| `repo` | push commits |
| `workflow` | **required** — the repository contains `.github/workflows/*.yml`, and GitHub refuses to create or update those files without it |

Omitting `workflow` fails the whole push with:

```
! [remote rejected] main -> main (refusing to allow a Personal Access Token
  to create or update workflow `.github/workflows/android.yml` without
  `workflow` scope)
```

You can add the scope to an existing token later (token page → *Edit* → tick
`workflow` → *Update token*); the token string stays the same, so the credential
already stored by Git Credential Manager keeps working.

> If you prefer SSH, use
> `git remote add origin git@github.com:<YOUR-USERNAME>/ielts-free.git`
> and make sure your SSH key is registered with GitHub.

### 1.3 If the push fails

**`fatal: 'origin' does not appear to be a git repository`**
or **`The requested URL returned error: 400`**

The remote URL still contains the literal placeholder. Check what it actually
points at, then correct it:

```powershell
git remote -v
git remote set-url origin https://github.com/<YOUR-USERNAME>/ielts-free.git
```

**`Repository not found`** — the repository has not been created on GitHub yet,
or the token has no access to it. Create it first (step 1.1), and make sure the
token has the `repo` scope.

**`Authentication failed`** — GitHub rejects account passwords over HTTPS. Create
a Personal Access Token (classic, scope `repo`) at
<https://github.com/settings/tokens> and paste it when Git asks for a password.

**`refusing to allow a Personal Access Token to create or update workflow ... without 'workflow' scope`**

The token is missing the `workflow` scope. Add it (token page → *Edit* → tick
`workflow` → *Update token*) and push again — no need to re-enter credentials,
the token string is unchanged.

**`src refspec main does not match any`** — you are not on the `main` branch:

```powershell
git branch --show-current
git checkout -b main
```

### 1.4 Fix the commit author (optional)

The two existing commits were created with a placeholder identity. To rewrite
them under your own name and e-mail:

```powershell
cd D:\workbuddyai\ielts_free
git config user.name  "Your Name"
git config user.email "you@example.com"
git rebase --root --exec "git commit --amend --no-edit --reset-author"
git push -f origin main
```

Only do this **before** anyone else has cloned the repository.

---

## 2. What runs automatically

| Workflow | Trigger | Does |
| --- | --- | --- |
| `.github/workflows/tests.yml` | every push / PR to `main` | `flutter analyze` + `flutter test` on Ubuntu |
| `.github/workflows/android.yml` | tag `v*`, or manual | builds a release APK |
| `.github/workflows/windows.yml` | tag `v*`, or manual | builds the Windows bundle |
| `.github/workflows/release.yml` | tag `v*` | tests → builds both platforms → `SHA256SUMS.txt` → GitHub Release |

The first push to `main` will run **Tests** and should go green: the same
`flutter analyze` and `flutter test` pass locally with `No issues found!` and
`All tests passed!`.

---

## 3. Cutting a release

```powershell
cd D:\workbuddyai\ielts_free
git tag v0.1.0
git push origin v0.1.0
```

That single tag push triggers the whole chain. When it finishes, the Releases
page will contain:

```
IELTS-Free-Android-v0.1.0.apk
IELTS-Free-Windows-v0.1.0.zip
SHA256SUMS.txt
```

Verify a download with:

```powershell
Get-FileHash .\IELTS-Free-Android-v0.1.0.apk -Algorithm SHA256
```

and compare it against the matching line in `SHA256SUMS.txt`.

---

## 4. If a platform build fails

### Android

The scaffolding was realigned with the installed Flutter (Gradle 9.3.1,
AGP 9.1.0, Kotlin 2.4.0). If a future Flutter upgrade changes those, regenerate
the scaffolding instead of editing it by hand:

```powershell
cd D:\workbuddyai\ielts_free
flutter create --platforms=android,windows .
```

That rewrites `android/` and `windows/` from the current Flutter templates.
**Re-check afterwards** that `android/app/src/main/AndroidManifest.xml` still
declares **no** `INTERNET` permission — that is a hard product requirement
(fully offline app, see `docs/ARCHITECTURE-v0.1.md` §2.5).

### Windows

`windows/runner/resources/app_icon.ico` is intentionally absent; the `ICON`
line in `windows/runner/Runner.rc` is commented out so the build falls back to
the default Windows icon. Drop a 256×256 `.ico` in that folder and uncomment the
line to brand the executable.

### `sqlite3` native library

`pubspec.yaml` contains a `hooks:` section that redirects the `package:sqlite3`
prebuilt-library download through a GitHub mirror. It exists because the
development machine is behind a network where `github.com` is unreachable.

GitHub's own runners reach `github.com` directly, so if that step ever fails on
CI, delete the `hooks:` block — the official source works there.

---

## 5. Before publishing for real

- [ ] Replace the debug signing config in `android/app/build.gradle.kts` with a
      real keystore (`android/key.properties` is already git-ignored).
- [ ] Add screenshots to `README.md` (the section is currently a placeholder).
- [ ] Add a Windows `app_icon.ico`.
- [ ] Confirm `flutter test` and `flutter analyze` are green on CI.
- [ ] Read `docs/TEST-REPORT-v0.1.md` §"仍未闭环的项" for what has *not* been
      verified (notably: on-device offline acceptance, and the release build).
