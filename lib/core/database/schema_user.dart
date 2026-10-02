/// User database DDL (read-write: profile, progress, mistakes, stats, plan).
///
/// The statements below are the authoritative user-library schema. They are
/// applied by `migrations.dart` (version 1). Every change must go through a new
/// migration step — never `DROP` a table and never lose user data
/// (docs/ARCHITECTURE-v0.1.md §2.1 / §4.3).
library;

/// Full user-database schema (version 1) as a single SQL script.
const String kUserSchemaSql = '''

CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  created_at TEXT NOT NULL,
  updated_at TEXT
);

CREATE TABLE IF NOT EXISTS user_profile (
  user_id TEXT PRIMARY KEY,
  display_name TEXT,
  weakest_skill TEXT,
  onboarding_completed INTEGER NOT NULL DEFAULT 0,
  created_at TEXT,
  updated_at TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS study_goal (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL,
  target_band REAL NOT NULL DEFAULT 7.0,
  exam_date TEXT,
  daily_study_minutes INTEGER NOT NULL DEFAULT 60,
  plan_type TEXT,
  plan_start_date TEXT,
  plan_end_date TEXT,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT,
  updated_at TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_sg_user ON study_goal(user_id);
CREATE INDEX IF NOT EXISTS idx_sg_active ON study_goal(user_id, is_active);

CREATE TABLE IF NOT EXISTS study_plan (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT,
  goal_id INTEGER,
  day_index INTEGER,
  plan_date TEXT,
  phase TEXT,
  summary TEXT,
  created_at TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (goal_id) REFERENCES study_goal(id)
);

CREATE INDEX IF NOT EXISTS idx_sp_user_date ON study_plan(user_id, plan_date);

CREATE TABLE IF NOT EXISTS daily_tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT,
  plan_date TEXT NOT NULL,
  task_type TEXT,
  skill TEXT,
  title TEXT,
  target_minutes INTEGER,
  item_count INTEGER,
  completed_count INTEGER NOT NULL DEFAULT 0,
  status TEXT,
  sort_order INTEGER,
  payload TEXT,
  created_at TEXT,
  updated_at TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_dt_user_date ON daily_tasks(user_id, plan_date);
CREATE INDEX IF NOT EXISTS idx_dt_status ON daily_tasks(user_id, status);

CREATE TABLE IF NOT EXISTS vocabulary_reviews (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT,
  vocabulary_id INTEGER NOT NULL,
  memory_level INTEGER NOT NULL DEFAULT 0 CHECK (memory_level BETWEEN 0 AND 6),
  correct_count INTEGER NOT NULL DEFAULT 0,
  wrong_count INTEGER NOT NULL DEFAULT 0,
  streak INTEGER NOT NULL DEFAULT 0,
  last_reviewed_at TEXT,
  next_review_at TEXT,
  is_mastered INTEGER NOT NULL DEFAULT 0,
  is_favorite INTEGER NOT NULL DEFAULT 0,
  created_at TEXT,
  updated_at TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_vr_user_vocab ON vocabulary_reviews(user_id, vocabulary_id);
CREATE INDEX IF NOT EXISTS idx_vr_due ON vocabulary_reviews(user_id, next_review_at);

CREATE TABLE IF NOT EXISTS skill_scores (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT,
  skill TEXT NOT NULL,
  score REAL NOT NULL DEFAULT 0,
  current_difficulty INTEGER NOT NULL DEFAULT 2 CHECK (current_difficulty BETWEEN 1 AND 5),
  sample_count INTEGER NOT NULL DEFAULT 0,
  last_practiced_at TEXT,
  updated_at TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_ss_user_skill ON skill_scores(user_id, skill);

CREATE TABLE IF NOT EXISTS user_answers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT,
  ref_type TEXT,
  ref_id INTEGER,
  skill TEXT,
  user_answer TEXT,
  is_correct INTEGER NOT NULL DEFAULT 0,
  difficulty INTEGER,
  time_spent_ms INTEGER,
  session_id TEXT,
  answered_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_ua_user_time ON user_answers(user_id, answered_at);
CREATE INDEX IF NOT EXISTS idx_ua_skill ON user_answers(user_id, skill);

CREATE TABLE IF NOT EXISTS mistakes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT,
  ref_type TEXT,
  ref_id INTEGER,
  question_type TEXT,
  skill TEXT,
  user_answer TEXT,
  correct_answer TEXT,
  error_type TEXT,
  difficulty INTEGER,
  wrong_count INTEGER NOT NULL DEFAULT 1,
  last_wrong_at TEXT,
  mastery REAL NOT NULL DEFAULT 0.0,
  created_at TEXT,
  updated_at TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_mk_user ON mistakes(user_id);
CREATE INDEX IF NOT EXISTS idx_mk_type ON mistakes(user_id, ref_type);
CREATE INDEX IF NOT EXISTS idx_mk_error ON mistakes(error_type);
CREATE UNIQUE INDEX IF NOT EXISTS idx_mk_unique ON mistakes(user_id, ref_type, ref_id);

CREATE TABLE IF NOT EXISTS learning_sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT,
  session_type TEXT,
  started_at TEXT,
  ended_at TEXT,
  duration_sec INTEGER,
  items_completed INTEGER,
  checkpoint TEXT,
  status TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_ls_user_start ON learning_sessions(user_id, started_at);

CREATE TABLE IF NOT EXISTS learning_statistics (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT,
  stat_date TEXT,
  study_minutes INTEGER NOT NULL DEFAULT 0,
  questions_answered INTEGER NOT NULL DEFAULT 0,
  correct_count INTEGER NOT NULL DEFAULT 0,
  words_reviewed INTEGER NOT NULL DEFAULT 0,
  words_mastered INTEGER NOT NULL DEFAULT 0,
  current_streak INTEGER NOT NULL DEFAULT 0,
  last_study_date TEXT,
  total_study_minutes INTEGER NOT NULL DEFAULT 0,
  total_days INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_st_user_date ON learning_statistics(user_id, stat_date);

CREATE TABLE IF NOT EXISTS favorites (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT,
  ref_type TEXT,
  ref_id INTEGER,
  created_at TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_fav_unique ON favorites(user_id, ref_type, ref_id);

CREATE TABLE IF NOT EXISTS notes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT,
  ref_type TEXT,
  ref_id INTEGER,
  content TEXT,
  created_at TEXT,
  updated_at TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_note_user_ref ON notes(user_id, ref_type, ref_id);

CREATE TABLE IF NOT EXISTS app_settings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT,
  key TEXT NOT NULL,
  value TEXT,
  updated_at TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_settings_user_key ON app_settings(user_id, key);

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

/// The user schema split into individual executable statements.
List<String> userSchemaStatements() => kUserSchemaSql
    .split(';')
    .map((String s) => s.trim())
    .where((String s) => s.isNotEmpty)
    .toList(growable: false);
