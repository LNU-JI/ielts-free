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
LISTENING_FILE = SEED_DIR / "listening_seed.json"
SPEAKING_FILE = SEED_DIR / "speaking_seed.json"
WRITING_FILE = SEED_DIR / "writing_seed.json"

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

VALID_LISTENING_TYPES = {
    "FORM_COMPLETION", "MC", "MATCHING", "SENTENCE_COMPLETION",
}
MIN_LISTENING_CUES = 12
MAX_LISTENING_CUES = 25
MIN_LISTENING_QUESTIONS = 4
MAX_LISTENING_QUESTIONS = 6

VALID_SPEAKING_PARTS = {1, 2, 3}
REQUIRED_PHRASE_CATEGORIES = {
    "开头", "结尾", "让步", "因果", "举例",
    "对比", "趋势描述", "数据描述", "观点表达",
}
MIN_WRITING_PHRASES = 40


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


def check_listening(sections: list) -> tuple[int, int, int, list[str]]:
    valid = 0
    review = 0
    duplicate = 0
    issues: list[str] = []
    seen_prompts: dict[str, int] = {}

    for index, section in enumerate(sections):
        if not isinstance(section, dict):
            review += 1
            issues.append(f"[listening] section #{index}: not an object")
            continue
        label = section.get("title") or f"#{index}"

        if section.get("part") not in (1, 2, 3, 4):
            review += 1
            issues.append(f"[listening] {label}: invalid part {section.get('part')!r}")
        if not isinstance(section.get("title"), str) or not section.get("title", "").strip():
            review += 1
            issues.append(f"[listening] {label}: missing title")

        cues = section.get("cues", [])
        if not isinstance(cues, list) or not (MIN_LISTENING_CUES <= len(cues) <= MAX_LISTENING_CUES):
            review += 1
            issues.append(
                f"[listening] {label}: cues must be a list of "
                f"{MIN_LISTENING_CUES}-{MAX_LISTENING_CUES} items"
            )
            cues = cues if isinstance(cues, list) else []
        cue_ids = set()
        for cue_index, cue in enumerate(cues):
            if not isinstance(cue, dict):
                review += 1
                issues.append(f"[listening] {label} cue #{cue_index}: not an object")
                continue
            cue_ids.add(cue.get("id"))
            if not isinstance(cue.get("text"), str) or not cue.get("text", "").strip():
                review += 1
                issues.append(f"[listening] {label} cue {cue.get('id')}: empty text")
            if not isinstance(cue.get("phonetic_notes", []), list):
                review += 1
                issues.append(f"[listening] {label} cue {cue.get('id')}: phonetic_notes must be a list")

        questions = section.get("questions", [])
        if not isinstance(questions, list) or not (
            MIN_LISTENING_QUESTIONS <= len(questions) <= MAX_LISTENING_QUESTIONS
        ):
            review += 1
            issues.append(
                f"[listening] {label}: questions must be a list of "
                f"{MIN_LISTENING_QUESTIONS}-{MAX_LISTENING_QUESTIONS} items"
            )
            continue

        for question_index, question in enumerate(questions):
            qlabel = f"{label} Q{question_index + 1}"
            if not isinstance(question, dict):
                review += 1
                issues.append(f"[listening] {qlabel}: not an object")
                continue

            problems: list[str] = []
            if question.get("type") not in VALID_LISTENING_TYPES:
                problems.append(f"invalid type: {question.get('type')!r}")
            if not isinstance(question.get("prompt"), str) or not question.get("prompt", "").strip():
                problems.append("empty prompt")
            if not isinstance(question.get("answer"), str) or not question.get("answer", "").strip():
                problems.append("empty answer")
            if question.get("evidence_cue_id") not in cue_ids:
                problems.append(
                    f"evidence_cue_id {question.get('evidence_cue_id')!r} does not match any cue id"
                )
            if not isinstance(question.get("explanation"), str) or not question.get("explanation", "").strip():
                problems.append("empty explanation")
            if not isinstance(question.get("distractors"), list):
                problems.append("distractors must be a list")
            if not isinstance(question.get("options", []), list):
                problems.append("options must be a list")
            if question.get("type") == "MC":
                options = question.get("options", [])
                if not isinstance(options, list) or len(options) < 2:
                    problems.append("MC question needs at least two options")
                else:
                    labels = {o.get("label") for o in options if isinstance(o, dict)}
                    if question.get("answer") not in labels:
                        problems.append("MC answer must match one of the option labels")

            key = normalize(question.get("prompt", ""))
            if key:
                if key in seen_prompts:
                    duplicate += 1
                    issues.append(f"[listening] duplicate prompt in {qlabel}")
                else:
                    seen_prompts[key] = question_index

            if problems:
                review += 1
                issues.append(f"[listening] {qlabel}: " + "; ".join(problems))
            else:
                valid += 1

    return valid, review, duplicate, issues


def check_speaking(topics: list) -> tuple[int, int, int, list[str]]:
    valid = 0
    review = 0
    duplicate = 0
    issues: list[str] = []
    seen_questions: dict[str, int] = {}

    for index, topic in enumerate(topics):
        if not isinstance(topic, dict):
            review += 1
            issues.append(f"[speaking] topic #{index}: not an object")
            continue
        label = topic.get("title") or f"#{index}"
        part = topic.get("part")

        if part not in VALID_SPEAKING_PARTS:
            review += 1
            issues.append(f"[speaking] {label}: invalid part {part!r}")
        if not isinstance(topic.get("speak_seconds"), int) or topic.get("speak_seconds") <= 0:
            review += 1
            issues.append(f"[speaking] {label}: speak_seconds must be a positive integer")
        if part == 2:
            if not isinstance(topic.get("cue_card"), str) or not topic.get("cue_card", "").strip():
                review += 1
                issues.append(f"[speaking] {label}: part 2 needs a non-empty cue_card")
            if not isinstance(topic.get("prep_seconds"), int):
                review += 1
                issues.append(f"[speaking] {label}: part 2 needs prep_seconds")

        questions = topic.get("questions", [])
        if not isinstance(questions, list) or not questions:
            review += 1
            issues.append(f"[speaking] {label}: questions must be a non-empty list")
            continue

        for question_index, question in enumerate(questions):
            qlabel = f"{label} Q{question_index + 1}"
            if not isinstance(question, dict):
                review += 1
                issues.append(f"[speaking] {qlabel}: not an object")
                continue

            problems: list[str] = []
            if not isinstance(question.get("question"), str) or not question.get("question", "").strip():
                problems.append("empty question")
            if not isinstance(question.get("question_cn"), str) or not question.get("question_cn", "").strip():
                problems.append("empty question_cn")
            if not isinstance(question.get("sample_answer"), str) or not question.get("sample_answer", "").strip():
                problems.append("empty sample_answer")
            if not isinstance(question.get("key_phrases"), list) or not question.get("key_phrases"):
                problems.append("key_phrases must be a non-empty list")
            if part == 3 and (
                not isinstance(question.get("follow_ups"), list) or not question.get("follow_ups")
            ):
                problems.append("part 3 questions need follow_ups")

            key = normalize(question.get("question", ""))
            if key:
                if key in seen_questions:
                    duplicate += 1
                    issues.append(f"[speaking] duplicate question in {qlabel}")
                else:
                    seen_questions[key] = question_index

            if problems:
                review += 1
                issues.append(f"[speaking] {qlabel}: " + "; ".join(problems))
            else:
                valid += 1

    return valid, review, duplicate, issues


def check_writing(tasks: list, phrases: list) -> tuple[int, int, int, list[str]]:
    valid = 0
    review = 0
    duplicate = 0
    issues: list[str] = []
    seen_prompts: dict[str, int] = {}

    for index, task in enumerate(tasks):
        if not isinstance(task, dict):
            review += 1
            issues.append(f"[writing] task #{index}: not an object")
            continue
        label = task.get("title") or f"#{index}"

        problems: list[str] = []
        if task.get("task") not in (1, 2):
            problems.append(f"invalid task number: {task.get('task')!r}")
        if not isinstance(task.get("title"), str) or not task.get("title", "").strip():
            problems.append("empty title")
        if not isinstance(task.get("prompt"), str) or not task.get("prompt", "").strip():
            problems.append("empty prompt")
        min_words = task.get("min_words")
        if not isinstance(min_words, int) or min_words <= 0:
            problems.append("min_words must be a positive integer")
        if not isinstance(task.get("time_minutes"), int) or task.get("time_minutes") <= 0:
            problems.append("time_minutes must be a positive integer")
        if task.get("task") == 1 and task.get("chart_data") is None:
            problems.append("task 1 needs chart_data")

        samples = task.get("samples", [])
        if not isinstance(samples, list) or not samples:
            problems.append("samples must be a non-empty list")
        else:
            for sample_index, sample in enumerate(samples):
                if not isinstance(sample, dict):
                    problems.append(f"sample #{sample_index} is not an object")
                    continue
                essay = sample.get("essay", "")
                if not isinstance(essay, str) or not essay.strip():
                    problems.append(f"sample #{sample_index} has an empty essay")
                elif isinstance(min_words, int) and len(essay.split()) < min_words:
                    problems.append(
                        f"sample #{sample_index} essay shorter than min_words "
                        f"({len(essay.split())} < {min_words})"
                    )
                if not isinstance(sample.get("outline"), list) or not sample.get("outline"):
                    problems.append(f"sample #{sample_index} needs a non-empty outline")
                if not isinstance(sample.get("annotations"), list) or not sample.get("annotations"):
                    problems.append(f"sample #{sample_index} needs a non-empty annotations list")

        key = normalize(task.get("prompt", ""))
        if key:
            if key in seen_prompts:
                duplicate += 1
                issues.append(f"[writing] duplicate prompt in {label}")
            else:
                seen_prompts[key] = index

        if problems:
            review += 1
            issues.append(f"[writing] {label}: " + "; ".join(problems))
        else:
            valid += 1

    if not isinstance(phrases, list):
        review += 1
        issues.append("[writing] phrases must be a list")
        phrases = []
    if len(phrases) < MIN_WRITING_PHRASES:
        review += 1
        issues.append(
            f"[writing] needs at least {MIN_WRITING_PHRASES} phrases, found {len(phrases)}"
        )
    categories: set[str] = set()
    for index, phrase in enumerate(phrases):
        if not isinstance(phrase, dict):
            review += 1
            issues.append(f"[writing] phrase #{index}: not an object")
            continue
        problems = []
        for field in ("category", "phrase", "meaning_cn"):
            if not isinstance(phrase.get(field), str) or not phrase.get(field, "").strip():
                problems.append(f"empty {field}")
        if problems:
            review += 1
            issues.append(f"[writing] phrase #{index}: " + "; ".join(problems))
        else:
            valid += 1
            categories.add(phrase["category"])
    missing = REQUIRED_PHRASE_CATEGORIES - categories
    if missing:
        review += 1
        issues.append("[writing] missing phrase categories: " + ", ".join(sorted(missing)))

    return valid, review, duplicate, issues


def main() -> int:
    vocabulary = load_json(VOCAB_FILE)
    reading = load_json(READING_FILE)
    listening = load_json(LISTENING_FILE)
    speaking = load_json(SPEAKING_FILE)
    writing = load_json(WRITING_FILE)
    if not isinstance(vocabulary, list):
        print("ERROR: vocabulary_seed.json must be a JSON array", file=sys.stderr)
        return 2
    passages = reading.get("passages", []) if isinstance(reading, dict) else reading
    sections = listening.get("sections", []) if isinstance(listening, dict) else listening
    topics = speaking.get("topics", []) if isinstance(speaking, dict) else speaking
    writing_tasks = writing.get("tasks", []) if isinstance(writing, dict) else writing
    writing_phrases = writing.get("phrases", []) if isinstance(writing, dict) else []

    v_valid, v_review, v_dup, v_issues = check_vocabulary(vocabulary)
    r_valid, r_review, r_dup, r_issues = check_reading(passages)
    l_valid, l_review, l_dup, l_issues = check_listening(sections)
    s_valid, s_review, s_dup, s_issues = check_speaking(topics)
    w_valid, w_review, w_dup, w_issues = check_writing(writing_tasks, writing_phrases)

    issues = v_issues + r_issues + l_issues + s_issues + w_issues
    valid = v_valid + r_valid + l_valid + s_valid + w_valid
    review = v_review + r_review + l_review + s_review + w_review
    duplicate = v_dup + r_dup + l_dup + s_dup + w_dup

    print("IELTS Free — content validation")
    print(f"  vocabulary items : {len(vocabulary)}")
    print(f"  reading passages : {len(passages)}")
    print(f"  reading questions: {sum(len(p.get('questions', [])) for p in passages if isinstance(p, dict))}")
    print(f"  listening sections: {len(sections)}")
    print(f"  listening questions: {sum(len(s.get('questions', [])) for s in sections if isinstance(s, dict))}")
    print(f"  speaking topics  : {len(topics)}")
    print(f"  speaking questions: {sum(len(t.get('questions', [])) for t in topics if isinstance(t, dict))}")
    print(f"  writing tasks    : {len(writing_tasks)}")
    print(f"  writing phrases  : {len(writing_phrases)}")
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
