#!/usr/bin/env python3
"""Validate the IELTS Free seed content (development-time only).

Checks, for both vocabulary and reading:

* required fields are present and non-empty;
* values are in range / in the allowed set (difficulty 1..5, CEFR, T/F/NG keys);
* the reading ``evidence`` fragment actually appears in its passage;
* no duplicate head words / question prompts.

Output is the format required by docs/BRIEF.md §90::

    Valid: N / Need Review: M / Duplicate: K

Exit code is 0 when nothing needs review and there are no duplicates.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SEED_DIR = ROOT / "assets" / "seed"
VOCAB_FILE = SEED_DIR / "vocabulary_seed.json"
READING_FILE = SEED_DIR / "reading_seed.json"

REQUIRED_VOCAB_FIELDS = [
    "word", "phonetic", "partOfSpeech", "meaningCN", "meaningEN", "difficulty",
    "cefr", "ieltsLevel", "topics", "synonyms", "antonyms", "collocations",
    "examples", "writingUsage", "speakingUsage", "commonMistakes", "relatedWords",
]

REQUIRED_PASSAGE_FIELDS = [
    "title", "topic", "difficulty", "band", "readingTime", "passage", "questions",
]

REQUIRED_QUESTION_FIELDS = [
    "type", "prompt", "correctAnswer", "evidence", "keywords", "synonyms",
    "logic", "explanation",
]

VALID_CEFR = {"A1", "A2", "B1", "B2", "C1", "C2"}
VALID_TYPES = {
    "TFNG", "YNNG", "MC", "MATCH_HEADINGS", "MATCH_INFO",
    "SENTENCE_COMPLETION", "SUMMARY_COMPLETION", "TABLE_COMPLETION",
    "NOTE_COMPLETION",
}
TRUEFALSE_TYPES = {"TFNG", "YNNG"}
VALID_TRUE_FALSE = {"true", "false", "not given"}


def normalize(text: str) -> str:
    """Lower-case and collapse whitespace for comparison."""
    return re.sub(r"\s+", " ", (text or "").strip().lower())


def load_json(path: Path):
    if not path.exists():
        print(f"ERROR: missing seed file: {path}", file=sys.stderr)
        sys.exit(2)
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def check_vocabulary(items: list) -> tuple[int, int, int, list[str]]:
    valid = 0
    review = 0
    duplicate = 0
    issues: list[str] = []
    seen: dict[str, int] = {}

    for index, item in enumerate(items):
        label = item.get("word", f"#{index}") if isinstance(item, dict) else f"#{index}"
        if not isinstance(item, dict):
            review += 1
            issues.append(f"[vocab] {label}: not an object")
            continue

        problems: list[str] = []
        for field in REQUIRED_VOCAB_FIELDS:
            if field not in item:
                problems.append(f"missing field '{field}'")

        difficulty = item.get("difficulty")
        if not isinstance(difficulty, int) or not 1 <= difficulty <= 5:
            problems.append(f"difficulty out of range: {difficulty!r}")

        cefr = item.get("cefr")
        if cefr not in VALID_CEFR:
            problems.append(f"invalid cefr: {cefr!r}")

        topics = item.get("topics")
        if not isinstance(topics, list) or not topics:
            problems.append("topics must be a non-empty list")

        examples = item.get("examples")
        if not isinstance(examples, list) or not examples:
            problems.append("examples must be a non-empty list")
        else:
            for example in examples:
                if not isinstance(example, dict) or not example.get("en"):
                    problems.append("each example needs an 'en' string")
                    break

        key = normalize(item.get("word", ""))
        if key:
            if key in seen:
                duplicate += 1
                issues.append(f"[vocab] duplicate word: {item.get('word')!r}")
            else:
                seen[key] = index

        if problems:
            review += 1
            issues.append(f"[vocab] {label}: " + "; ".join(problems))
        else:
            valid += 1

    return valid, review, duplicate, issues


def check_reading(passages: list) -> tuple[int, int, int, list[str]]:
    valid = 0
    review = 0
    duplicate = 0
    issues: list[str] = []
    seen_prompts: dict[str, int] = {}

    for passage_index, passage in enumerate(passages):
        if not isinstance(passage, dict):
            review += 1
            issues.append(f"[reading] passage #{passage_index}: not an object")
            continue

        title = passage.get("title", f"#{passage_index}")
        for field in REQUIRED_PASSAGE_FIELDS:
            if field not in passage:
                review += 1
                issues.append(f"[reading] {title}: missing field '{field}'")
                break

        body = normalize(passage.get("passage", ""))
        questions = passage.get("questions", [])
        if not isinstance(questions, list) or not questions:
            review += 1
            issues.append(f"[reading] {title}: questions must be a non-empty list")
            continue

        for question_index, question in enumerate(questions):
            qlabel = f"{title} Q{question_index + 1}"
            if not isinstance(question, dict):
                review += 1
                issues.append(f"[reading] {qlabel}: not an object")
                continue

            problems: list[str] = []
            for field in REQUIRED_QUESTION_FIELDS:
                if field not in question:
                    problems.append(f"missing field '{field}'")

            qtype = question.get("type")
            if qtype not in VALID_TYPES:
                problems.append(f"invalid type: {qtype!r}")

            answer = question.get("correctAnswer", "")
            if not isinstance(answer, str) or not answer.strip():
                problems.append("empty correctAnswer")
            elif qtype in TRUEFALSE_TYPES and normalize(answer) not in VALID_TRUE_FALSE:
                problems.append(f"T/F/NG answer must be True/False/Not Given, got {answer!r}")

            evidence = question.get("evidence", "")
            if not isinstance(evidence, str) or not evidence.strip():
                problems.append("empty evidence")
            elif body and normalize(evidence) not in body:
                problems.append("evidence not found in passage")

            if qtype == "MC":
                options = question.get("options")
                if not isinstance(options, list) or len(options) < 2:
                    problems.append("MC question needs at least two options")
                else:
                    correct = [o for o in options if isinstance(o, dict) and o.get("isCorrect")]
                    if len(correct) != 1:
                        problems.append("MC question must have exactly one correct option")

            key = normalize(question.get("prompt", ""))
            if key:
                if key in seen_prompts:
                    duplicate += 1
                    issues.append(f"[reading] duplicate prompt in {qlabel}")
                else:
                    seen_prompts[key] = question_index

            if problems:
                review += 1
                issues.append(f"[reading] {qlabel}: " + "; ".join(problems))
            else:
                valid += 1

    return valid, review, duplicate, issues


def main() -> int:
    vocabulary = load_json(VOCAB_FILE)
    reading = load_json(READING_FILE)
    if not isinstance(vocabulary, list):
        print("ERROR: vocabulary_seed.json must be a JSON array", file=sys.stderr)
        return 2
    passages = reading.get("passages", []) if isinstance(reading, dict) else reading

    v_valid, v_review, v_dup, v_issues = check_vocabulary(vocabulary)
    r_valid, r_review, r_dup, r_issues = check_reading(passages)

    issues = v_issues + r_issues
    valid = v_valid + r_valid
    review = v_review + r_review
    duplicate = v_dup + r_dup

    print("IELTS Free — content validation")
    print(f"  vocabulary items : {len(vocabulary)}")
    print(f"  reading passages : {len(passages)}")
    print(f"  reading questions: {sum(len(p.get('questions', [])) for p in passages if isinstance(p, dict))}")
    print()
    if issues:
        print("Issues:")
        for line in issues:
            print(f"  - {line}")
        print()
    print(f"Valid: {valid} / Need Review: {review} / Duplicate: {duplicate}")

    return 0 if review == 0 and duplicate == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
