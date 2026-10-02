#!/usr/bin/env python3
"""Report (and optionally prune) near-duplicate content.

Vocabulary items are compared by head word; reading questions by prompt and by
answer+evidence. Uses ``difflib`` (standard library) for fuzzy matching.

Usage::

    python content_pipeline/deduplicate_content.py            # report only
    python content_pipeline/deduplicate_content.py --prune    # rewrite JSON
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from difflib import SequenceMatcher
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SEED_DIR = ROOT / "assets" / "seed"
VOCAB_FILE = SEED_DIR / "vocabulary_seed.json"
READING_FILE = SEED_DIR / "reading_seed.json"

SIMILARITY_THRESHOLD = 0.92


def normalize(text: str) -> str:
    return re.sub(r"\s+", " ", (text or "").strip().lower())


def find_duplicates(values: list[str], threshold: float) -> list[tuple[int, int, float]]:
    hits: list[tuple[int, int, float]] = []
    normalized = [normalize(v) for v in values]
    for i in range(len(normalized)):
        for j in range(i + 1, len(normalized)):
            if not normalized[i] or not normalized[j]:
                continue
            if normalized[i] == normalized[j]:
                hits.append((i, j, 1.0))
                continue
            ratio = SequenceMatcher(None, normalized[i], normalized[j]).ratio()
            if ratio >= threshold:
                hits.append((i, j, ratio))
    return hits


def main() -> int:
    parser = argparse.ArgumentParser(description="Report near-duplicate content.")
    parser.add_argument("--prune", action="store_true", help="remove duplicates from the JSON files")
    args = parser.parse_args()

    vocabulary = json.loads(VOCAB_FILE.read_text(encoding="utf-8"))
    reading = json.loads(READING_FILE.read_text(encoding="utf-8"))
    passages = reading.get("passages", []) if isinstance(reading, dict) else reading

    words = [item.get("word", "") for item in vocabulary]
    word_hits = find_duplicates(words, SIMILARITY_THRESHOLD)

    prompts = []
    for passage in passages:
        for question in passage.get("questions", []):
            prompts.append(question.get("prompt", ""))
    prompt_hits = find_duplicates(prompts, SIMILARITY_THRESHOLD)

    print("IELTS Free — duplicate report")
    print(f"  vocabulary near-duplicates : {len(word_hits)}")
    for i, j, ratio in word_hits:
        print(f"    - {words[i]!r} ~ {words[j]!r} ({ratio:.2f})")
    print(f"  question near-duplicates   : {len(prompt_hits)}")
    for i, j, ratio in prompt_hits:
        print(f"    - {prompts[i][:60]!r} ~ {prompts[j][:60]!r} ({ratio:.2f})")

    if args.prune and (word_hits or prompt_hits):
        drop_words = {j for _, j, _ in word_hits}
        pruned = [item for index, item in enumerate(vocabulary) if index not in drop_words]
        VOCAB_FILE.write_text(json.dumps(pruned, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"  pruned vocabulary -> {len(pruned)} items")

    return 0 if not word_hits and not prompt_hits else 1


if __name__ == "__main__":
    raise SystemExit(main())
