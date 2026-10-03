/// Content database DDL (read-only, shipped with the app).
///
/// The SQL below is kept **statement-for-statement identical** to
/// `content_pipeline/schema.sql`. `content_pipeline/build_content_db.py`
/// compiles the seed JSON into a database with exactly this schema, and
/// `content_pipeline/validate_content.py` cross-checks the two copies.
///
/// Tables: `vocabulary`, `vocabulary_topics`, `reading_passages`,
/// `reading_questions`, `reading_options`, `content_metadata`.
library;

/// Full content-database schema as a single SQL script.
///
/// Statements are separated by `;`; use [contentSchemaStatements] to execute
/// them one by one (sqflite's `execute` accepts a single statement at a time).
const String kContentSchemaSql = '''

CREATE TABLE IF NOT EXISTS vocabulary (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  word TEXT NOT NULL UNIQUE,
  phonetic TEXT,
  part_of_speech TEXT,
  meaning_cn TEXT NOT NULL,
  meaning_en TEXT,
  difficulty INTEGER NOT NULL CHECK (difficulty BETWEEN 1 AND 5),
  cefr TEXT,
  ielts_level TEXT,
  synonyms TEXT,
  antonyms TEXT,
  collocations TEXT,
  examples TEXT,
  writing_usage TEXT,
  speaking_usage TEXT,
  common_mistakes TEXT,
  related_words TEXT,
  created_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_vocab_word ON vocabulary(word);
CREATE INDEX IF NOT EXISTS idx_vocab_difficulty ON vocabulary(difficulty);
CREATE INDEX IF NOT EXISTS idx_vocab_cefr ON vocabulary(cefr);

CREATE TABLE IF NOT EXISTS vocabulary_topics (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  vocabulary_id INTEGER NOT NULL,
  topic TEXT NOT NULL,
  FOREIGN KEY (vocabulary_id) REFERENCES vocabulary(id)
);

CREATE INDEX IF NOT EXISTS idx_vt_vocab ON vocabulary_topics(vocabulary_id);
CREATE INDEX IF NOT EXISTS idx_vt_topic ON vocabulary_topics(topic);

CREATE TABLE IF NOT EXISTS reading_passages (
  id INTEGER PRIMARY KEY,
  title TEXT NOT NULL,
  topic TEXT,
  difficulty INTEGER CHECK (difficulty BETWEEN 1 AND 5),
  band TEXT,
  reading_time_sec INTEGER,
  passage TEXT NOT NULL,
  skills TEXT
);

CREATE INDEX IF NOT EXISTS idx_rp_difficulty ON reading_passages(difficulty);
CREATE INDEX IF NOT EXISTS idx_rp_topic ON reading_passages(topic);

CREATE TABLE IF NOT EXISTS reading_questions (
  id INTEGER PRIMARY KEY,
  passage_id INTEGER NOT NULL,
  order_index INTEGER NOT NULL,
  question_type TEXT NOT NULL,
  prompt TEXT NOT NULL,
  correct_answer TEXT NOT NULL,
  evidence TEXT,
  keywords TEXT,
  synonyms TEXT,
  logic TEXT,
  explanation TEXT,
  skill TEXT,
  difficulty INTEGER CHECK (difficulty BETWEEN 1 AND 5),
  FOREIGN KEY (passage_id) REFERENCES reading_passages(id)
);

CREATE INDEX IF NOT EXISTS idx_rq_passage ON reading_questions(passage_id);
CREATE INDEX IF NOT EXISTS idx_rq_type ON reading_questions(question_type);

CREATE TABLE IF NOT EXISTS reading_options (
  id INTEGER PRIMARY KEY,
  question_id INTEGER NOT NULL,
  order_index INTEGER,
  label TEXT,
  content TEXT NOT NULL,
  is_correct INTEGER,
  FOREIGN KEY (question_id) REFERENCES reading_questions(id)
);

CREATE INDEX IF NOT EXISTS idx_ro_question ON reading_options(question_id);

-- ---------------------------------------------------------------------------
-- Listening (V0.2)
--
-- Audio is synthesised ON DEVICE from `listening_cues` using the platform TTS
-- engine, so the content pack ships text only: no audio files, no network, no
-- downloads. Each cue is one spoken sentence (or one short turn) and is the
-- unit of sentence-by-sentence intensive listening.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS listening_sections (
  id INTEGER PRIMARY KEY,
  part INTEGER NOT NULL CHECK (part BETWEEN 1 AND 4),
  title TEXT NOT NULL,
  scene TEXT,
  accent TEXT,
  difficulty INTEGER CHECK (difficulty BETWEEN 1 AND 5),
  overview TEXT,
  skills TEXT
);

CREATE INDEX IF NOT EXISTS idx_ls_part ON listening_sections(part);
CREATE INDEX IF NOT EXISTS idx_ls_difficulty ON listening_sections(difficulty);

CREATE TABLE IF NOT EXISTS listening_cues (
  id INTEGER PRIMARY KEY,
  section_id INTEGER NOT NULL,
  order_index INTEGER NOT NULL,
  speaker TEXT,
  text TEXT NOT NULL,
  translation TEXT,
  phonetic_notes TEXT,
  FOREIGN KEY (section_id) REFERENCES listening_sections(id)
);

CREATE INDEX IF NOT EXISTS idx_lc_section ON listening_cues(section_id);

CREATE TABLE IF NOT EXISTS listening_questions (
  id INTEGER PRIMARY KEY,
  section_id INTEGER NOT NULL,
  order_index INTEGER NOT NULL,
  question_type TEXT NOT NULL,
  prompt TEXT NOT NULL,
  options TEXT,
  answer TEXT NOT NULL,
  alternatives TEXT,
  evidence_cue_id INTEGER,
  explanation TEXT,
  distractors TEXT,
  FOREIGN KEY (section_id) REFERENCES listening_sections(id)
);

CREATE INDEX IF NOT EXISTS idx_lq_section ON listening_questions(section_id);

-- ---------------------------------------------------------------------------
-- Speaking (V0.2)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS speaking_topics (
  id INTEGER PRIMARY KEY,
  part INTEGER NOT NULL CHECK (part BETWEEN 1 AND 3),
  topic TEXT NOT NULL,
  title TEXT NOT NULL,
  cue_card TEXT,
  prep_seconds INTEGER,
  speak_seconds INTEGER NOT NULL,
  difficulty INTEGER CHECK (difficulty BETWEEN 1 AND 5)
);

CREATE INDEX IF NOT EXISTS idx_st_part ON speaking_topics(part);

CREATE TABLE IF NOT EXISTS speaking_questions (
  id INTEGER PRIMARY KEY,
  topic_id INTEGER NOT NULL,
  order_index INTEGER NOT NULL,
  question TEXT NOT NULL,
  question_cn TEXT,
  sample_answer TEXT,
  key_phrases TEXT,
  follow_ups TEXT,
  FOREIGN KEY (topic_id) REFERENCES speaking_topics(id)
);

CREATE INDEX IF NOT EXISTS idx_sq_topic ON speaking_questions(topic_id);

-- ---------------------------------------------------------------------------
-- Writing (V0.2)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS writing_tasks (
  id INTEGER PRIMARY KEY,
  task INTEGER NOT NULL CHECK (task IN (1, 2)),
  title TEXT NOT NULL,
  prompt TEXT NOT NULL,
  chart_data TEXT,
  min_words INTEGER NOT NULL,
  time_minutes INTEGER NOT NULL,
  difficulty INTEGER CHECK (difficulty BETWEEN 1 AND 5)
);

CREATE INDEX IF NOT EXISTS idx_wt_task ON writing_tasks(task);

CREATE TABLE IF NOT EXISTS writing_samples (
  id INTEGER PRIMARY KEY,
  task_id INTEGER NOT NULL,
  band TEXT,
  essay TEXT NOT NULL,
  outline TEXT,
  annotations TEXT,
  FOREIGN KEY (task_id) REFERENCES writing_tasks(id)
);

CREATE INDEX IF NOT EXISTS idx_ws_task ON writing_samples(task_id);

CREATE TABLE IF NOT EXISTS writing_phrases (
  id INTEGER PRIMARY KEY,
  category TEXT NOT NULL,
  task INTEGER,
  phrase TEXT NOT NULL,
  meaning_cn TEXT,
  example TEXT,
  band TEXT
);

CREATE INDEX IF NOT EXISTS idx_wp_category ON writing_phrases(category);
CREATE INDEX IF NOT EXISTS idx_wp_task ON writing_phrases(task);

CREATE TABLE IF NOT EXISTS content_metadata (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  content_version TEXT NOT NULL UNIQUE,
  app_compatibility TEXT,
  vocabulary_count INTEGER NOT NULL DEFAULT 0,
  reading_count INTEGER NOT NULL DEFAULT 0,
  listening_count INTEGER NOT NULL DEFAULT 0,
  writing_count INTEGER NOT NULL DEFAULT 0,
  speaking_count INTEGER NOT NULL DEFAULT 0,
  checksum TEXT,
  imported_at TEXT,
  is_active INTEGER NOT NULL DEFAULT 1
);
''';

/// The content schema split into individual executable statements.
List<String> contentSchemaStatements() => kContentSchemaSql
    .split(';')
    .map((String s) => s.trim())
    .where((String s) => s.isNotEmpty)
    .toList(growable: false);
