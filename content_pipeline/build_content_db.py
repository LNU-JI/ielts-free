#!/usr/bin/env python3
"""Compile the seed JSON into the read-only content database.

Reads ``assets/seed/vocabulary_seed.json`` and ``assets/seed/reading_seed.json``
and produces ``assets/seed/ielts_content_v1.db`` using ``content_pipeline/schema.sql``.

Also writes ``assets/seed/manifest.json`` and records a row in
``content_metadata`` (version, per-table counts, generation time, SHA256), then
runs ``PRAGMA integrity_check``.

Standard library only (see requirements.txt).
"""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SEED_DIR = ROOT / "assets" / "seed"
SCHEMA_FILE = Path(__file__).resolve().parent / "schema.sql"
VOCAB_FILE = SEED_DIR / "vocabulary_seed.json"
READING_FILE = SEED_DIR / "reading_seed.json"
DB_FILE = SEED_DIR / "ielts_content_v1.db"
MANIFEST_FILE = SEED_DIR / "manifest.json"

CONTENT_VERSION = "1.0.0"
APP_COMPATIBILITY = ">=0.1.0 <0.2.0"

SKILL_BY_TYPE = {
    "TFNG": "READING_TFNG",
    "YNNG": "READING_TFNG",
    "MC": "READING_MC",
    "MATCH_HEADINGS": "MATCH_HEADINGS",
    "MATCH_INFO": "READING_INFERENCE",
    "SENTENCE_COMPLETION": "READING_DETAIL",
    "SUMMARY_COMPLETION": "READING_SUMMARY",
    "TABLE_COMPLETION": "READING_DETAIL",
    "NOTE_COMPLETION": "READING_DETAIL",
}


def load_json(path: Path):
    if not path.exists():
        print(f"ERROR: missing seed file: {path}", file=sys.stderr)
        sys.exit(2)
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def json_text(value) -> str:
    """Serialise a list/dict to a compact JSON string."""
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


# Content tables hashed for the deterministic *content digest* stored inside
# ``content_metadata.checksum``. ``content_metadata`` itself is deliberately
# excluded: a row cannot contain the hash of the file that contains it.
_CONTENT_DIGEST_TABLES = (
    ("vocabulary", "id"),
    ("vocabulary_topics", "vocabulary_id, topic"),
    ("reading_passages", "id"),
    ("reading_questions", "id"),
    ("reading_options", "id"),
)


def compute_content_digest(connection: sqlite3.Connection) -> str:
    """Deterministic SHA256 over the logical content tables.

    This is a *content* digest (stable across rebuilds and independent of the
    SQLite file layout), stored in ``content_metadata.checksum``. The SHA256 of
    the compiled ``.db`` **file** is a separate value written to
    ``manifest.json`` (see [build]) and is what the app verifies at import time.
    """
    digest = hashlib.sha256()
    for table, order_by in _CONTENT_DIGEST_TABLES:
        for row in connection.execute(f"SELECT * FROM {table} ORDER BY {order_by}"):
            digest.update(table.encode("utf-8"))
            for value in row:
                digest.update(b"\x1f")
                digest.update(b"" if value is None else str(value).encode("utf-8"))
            digest.update(b"\x1e")
    return digest.hexdigest()


def build() -> int:
    vocabulary = load_json(VOCAB_FILE)
    reading = load_json(READING_FILE)
    passages = reading.get("passages", []) if isinstance(reading, dict) else reading

    if DB_FILE.exists():
        DB_FILE.unlink()

    schema_sql = SCHEMA_FILE.read_text(encoding="utf-8")
    generated_at = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()
    created_at = generated_at.replace("+00:00", "Z")

    connection = sqlite3.connect(DB_FILE)
    try:
        connection.executescript(schema_sql)

        # --- vocabulary + topics -------------------------------------------
        for item in vocabulary:
            cursor = connection.execute(
                """
                INSERT INTO vocabulary (
                    word, phonetic, part_of_speech, meaning_cn, meaning_en,
                    difficulty, cefr, ielts_level, synonyms, antonyms,
                    collocations, examples, writing_usage, speaking_usage,
                    common_mistakes, related_words, created_at
                ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                """,
                (
                    item["word"],
                    item.get("phonetic"),
                    item.get("partOfSpeech"),
                    item["meaningCN"],
                    item.get("meaningEN"),
                    int(item["difficulty"]),
                    item.get("cefr"),
                    item.get("ieltsLevel"),
                    json_text(item.get("synonyms", [])),
                    json_text(item.get("antonyms", [])),
                    json_text(item.get("collocations", [])),
                    json_text(item.get("examples", [])),
                    item.get("writingUsage"),
                    item.get("speakingUsage"),
                    json_text(item.get("commonMistakes", [])),
                    json_text(item.get("relatedWords", [])),
                    created_at,
                ),
            )
            vocabulary_id = cursor.lastrowid
            for topic in item.get("topics", []):
                connection.execute(
                    "INSERT INTO vocabulary_topics (vocabulary_id, topic) VALUES (?, ?)",
                    (vocabulary_id, topic),
                )

        # --- reading --------------------------------------------------------
        question_count = 0
        for passage in passages:
            connection.execute(
                """
                INSERT INTO reading_passages (
                    id, title, topic, difficulty, band, reading_time_sec,
                    passage, skills
                ) VALUES (?,?,?,?,?,?,?,?)
                """,
                (
                    int(passage["id"]),
                    passage["title"],
                    passage.get("topic"),
                    int(passage.get("difficulty", 3)),
                    passage.get("band"),
                    int(passage.get("readingTime", 1200)),
                    passage["passage"],
                    json_text(passage.get("skills", [])),
                ),
            )
            for order_index, question in enumerate(passage.get("questions", []), start=1):
                qtype = question["type"]
                connection.execute(
                    """
                    INSERT INTO reading_questions (
                        id, passage_id, order_index, question_type, prompt,
                        correct_answer, evidence, keywords, synonyms, logic,
                        explanation, skill, difficulty
                    ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)
                    """,
                    (
                        int(question["id"]),
                        int(passage["id"]),
                        order_index,
                        qtype,
                        question["prompt"],
                        question["correctAnswer"],
                        question.get("evidence"),
                        json_text(question.get("keywords", [])),
                        json_text(question.get("synonyms", [])),
                        question.get("logic"),
                        question.get("explanation"),
                        question.get("skill") or SKILL_BY_TYPE.get(qtype),
                        int(question.get("difficulty", passage.get("difficulty", 3))),
                    ),
                )
                question_count += 1
                for option_index, option in enumerate(question.get("options", []), start=1):
                    connection.execute(
                        """
                        INSERT INTO reading_options (
                            id, question_id, order_index, label, content, is_correct
                        ) VALUES (?,?,?,?,?,?)
                        """,
                        (
                            int(option["id"]) if "id" in option else None,
                            int(question["id"]),
                            option_index,
                            option.get("label"),
                            option["content"],
                            1 if option.get("isCorrect") else 0,
                        ),
                    )

        connection.execute("PRAGMA user_version = 1")
        connection.commit()

        # Deterministic digest over the content tables (excludes content_metadata
        # itself so the value is well defined). Stored as the build-provenance
        # checksum inside the database.
        content_digest = compute_content_digest(connection)

        # Record the metadata row INSIDE the database (build provenance).
        connection.execute(
            """
            INSERT INTO content_metadata (
                content_version, app_compatibility, vocabulary_count,
                reading_count, listening_count, writing_count, speaking_count,
                checksum, imported_at, is_active
            ) VALUES (?,?,?,?,?,?,?,?,?,1)
            """,
            (
                CONTENT_VERSION,
                APP_COMPATIBILITY,
                len(vocabulary),
                len(passages),
                0,
                0,
                0,
                content_digest,
                created_at,
            ),
        )
        connection.commit()

        # integrity check on the FINAL database (metadata row included)
        integrity = connection.execute("PRAGMA integrity_check").fetchone()[0]
    finally:
        connection.close()

    # --- SHA256 of the FINAL compiled file ---------------------------------
    # Computed AFTER the metadata row is written, so it matches the bytes the
    # app reads from the asset and verifies via ContentDatabase.verifyChecksum().
    file_checksum = hashlib.sha256(DB_FILE.read_bytes()).hexdigest()

    manifest = {
        "contentVersion": CONTENT_VERSION,
        "appCompatibility": APP_COMPATIBILITY,
        "vocabularyCount": len(vocabulary),
        "readingCount": len(passages),
        "readingQuestionCount": question_count,
        "listeningCount": 0,
        "writingCount": 0,
        "speakingCount": 0,
        "generatedAt": created_at,
        "checksum": file_checksum,
        "contentDigest": content_digest,
    }
    MANIFEST_FILE.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print("IELTS Free — content database build")
    print(f"  output           : {DB_FILE.relative_to(ROOT)}")
    print(f"  vocabulary rows  : {len(vocabulary)}")
    print(f"  reading passages : {len(passages)}")
    print(f"  reading questions: {question_count}")
    print(f"  integrity_check  : {integrity}")
    print(f"  file sha256      : {file_checksum}")
    print(f"  content digest   : {content_digest}")
    print(f"  manifest         : {MANIFEST_FILE.relative_to(ROOT)}")

    return 0 if integrity == "ok" else 1


if __name__ == "__main__":
    raise SystemExit(build())
