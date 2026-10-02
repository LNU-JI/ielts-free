# Security Policy

## Our privacy and security model

IELTS Free is designed so that there is very little to secure in the first place:

- **No server.** The app never contacts a backend. There is no account system and
  no cloud storage.
- **No tracking.** No analytics, no telemetry, no crash reporting SDK.
- **No behavior upload.** Your answers, mistakes, notes and progress never leave
  your device.
- **Local data only.** Everything is stored in two SQLite files on your device:
  a read-only *content* database and a read-write *user* database.
- **No network permission in release builds.** The Android release manifest does
  not request `INTERNET`. Only debug/profile builds do, so Flutter hot reload and
  the VM service can work.

If you ever find that the app makes a network request on a core path, that is a
security bug — please report it.

## Supported versions

Security fixes are applied to the latest release on the `main` branch.

| Version | Supported |
| --- | --- |
| 0.1.x | ✅ |

## Reporting a vulnerability

Please **do not** open a public issue for security problems.

Instead, report it privately using GitHub's
[private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)
feature ("Security" tab → "Report a vulnerability"), or contact the maintainers
directly.

Please include:

- A description of the issue and its impact.
- Steps to reproduce.
- Affected platform(s) and app version.
- Any proof-of-concept you can share.

We will acknowledge your report as quickly as we can and keep you informed of the
resolution. Thank you for helping keep learners safe.
