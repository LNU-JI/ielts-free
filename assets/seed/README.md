# Seed content directory.

This directory will hold the read-only content database shipped with the app
(T02):

- `ielts_content_v1.db` — compiled content database (vocabulary + reading)
- `manifest.json` — content manifest (version, counts, SHA256 checksum)
- `vocabulary_seed.json` — source vocabulary data
- `reading_seed.json` — source reading data

It is declared as an asset directory in `pubspec.yaml` so new files are picked
up automatically. Do not delete this file while the directory is still empty —
Flutter needs at least one file present in a declared asset directory.
