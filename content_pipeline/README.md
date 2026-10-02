# Content pipeline (development-time only)

This directory is the **AI + Agent content production pipeline** described in
`docs/BRIEF.md` §48–§54 and §89/§90.

## It never runs inside the user app

The app ships a **compiled, read-only** SQLite database
(`assets/seed/ielts_content_v1.db`). The pipeline is a build-time tool that runs
on the developer machine / CI to produce that database from human-reviewed
source JSON. Nothing in this folder is bundled into the released app.

```
JSON drafts ──▶ validate_content.py ──▶ (reviewed) ──▶ build_content_db.py ──▶ ielts_content_v1.db
```

## Status flow

Every content item moves through the states required by `docs/BRIEF.md` §54:

```
draft ──▶ validated ──▶ reviewed ──▶ published
```

- **draft** — an Agent produced it; it has not been checked.
- **validated** — it passed `validate_content.py` (format, answer legality,
  evidence, duplicates, difficulty distribution).
- **reviewed** — a human confirmed the language quality and answer keys.
- **published** — it was compiled into `ielts_content_v1.db` by
  `build_content_db.py` and is eligible to ship.

AI-generated content **must never skip straight to published**.

## Checksums (two distinct values)

`build_content_db.py` emits **two** SHA256 values on purpose:

- `manifest.json → checksum` — SHA256 of the **final compiled `.db` file**
  (computed *after* the `content_metadata` row is written). This is the value
  the app compares against at import time (`ContentDatabase.verifyChecksum()`,
  see `docs/ARCHITECTURE-v0.1.md` §4.1 and the startup sequence diagram
  "SHA256 校验 vs manifest").
- `manifest.json → contentDigest` **and** `content_metadata.checksum` — a
  deterministic SHA256 over the *content tables only* (`vocabulary`,
  `vocabulary_topics`, `reading_passages`, `reading_questions`,
  `reading_options`). It is stable across rebuilds and independent of SQLite's
  file layout.

Why two values? A row **cannot contain the hash of the file that contains it**
(self-reference). The file hash therefore lives only in the external manifest;
the value stored *inside* the database is the content digest. Both are recorded
so a future importer can cross-check either one.

## Files

| File | Purpose |
| --- | --- |
| `schema.sql` | Content database DDL (mirrors `lib/core/database/schema_content.dart`). |
| `validate_content.py` | Checks the seed JSON; prints `Valid: N / Need Review: M / Duplicate: K`. |
| `build_content_db.py` | Compiles the seed JSON into `assets/seed/ielts_content_v1.db`. |
| `deduplicate_content.py` | Reports (and optionally prunes) near-duplicate items. |
| `export_content_pack.py` | Zips a built content DB into a distributable content pack. |
| `requirements.txt` | Declares that V0.1 needs the standard library only. |

## Commands (from the repository root)

```bash
python content_pipeline/validate_content.py
python content_pipeline/build_content_db.py
python content_pipeline/deduplicate_content.py
python content_pipeline/export_content_pack.py
```

## Originality

All seed content is **original**, written for this project. No official IELTS
past-paper text, answer key or copyrighted material is copied
(`docs/BRIEF.md` §55). See `LICENSE-CONTENT` in the repository root.
