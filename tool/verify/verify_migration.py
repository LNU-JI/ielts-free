# -*- coding: utf-8 -*-
"""Real execution of the v1 -> v2 user-DB migration (FR-083 / NFR-30).

DDL is extracted verbatim from schema_user.dart and the v2 steps from
migrations.dart, then executed against a real sqlite3 database.
"""
import os, re, sqlite3, tempfile

import os
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
def extract(sql_text, marker):
    m = re.search(marker + r"\s*=\s*'''(.*?)'''", sql_text, re.S)
    return m.group(1)


schema_src = open(os.path.join(ROOT, 'lib', 'core', 'database', 'schema_user.dart'), encoding='utf-8').read()
mig_src = open(os.path.join(ROOT, 'lib', 'core', 'database', 'migrations.dart'), encoding='utf-8').read()

kUserSchemaSql = extract(schema_src, r"kUserSchemaSql")
v1 = [s.strip() for s in kUserSchemaSql.split(';') if s.strip()]
print('== v1 statements parsed from schema_user.dart :', len(v1))

# v2 steps: capture the string literals inside the "2: <String>[...]" block
m = re.search(r"2:\s*<String>\[(.*?)\],\s*\};", mig_src, re.S)
block = m.group(1)
v2 = re.findall(r'"([^"]+)"|\'([^\']+)\'', block)
v2 = [a or b for a, b in v2]
print('== v2 statements parsed from migrations.dart  :', len(v2))
for s in v2:
    print('     -', s)

db_path = os.path.join(tempfile.gettempdir(), 'qa_migrate_v1.db')
if os.path.exists(db_path):
    os.remove(db_path)

con = sqlite3.connect(db_path)
con.execute('PRAGMA foreign_keys = ON')
for s in v1:
    con.execute(s)
con.execute('PRAGMA user_version = 1')
con.commit()

# seed representative rows in the tables touched by v2 + a few others
con.execute("INSERT INTO users(id, created_at) VALUES ('local_user', '2024-01-01T00:00:00Z')")
con.execute("INSERT INTO user_profile(user_id, display_name, weakest_skill, onboarding_completed) "
            "VALUES ('local_user', 'Alice', 'reading', 1)")
con.execute("INSERT INTO study_goal(user_id, target_band, daily_study_minutes) "
            "VALUES ('local_user', 7.5, 90)")
con.execute("INSERT INTO skill_scores(id, user_id, skill, score, sample_count) "
            "VALUES (1, 'local_user', 'vocabulary', 62.0, 12)")
con.execute("INSERT INTO mistakes(id, user_id, ref_type, ref_id, error_type, wrong_count, mastery) "
            "VALUES (1, 'local_user', 'vocabulary', 5, 'meaning', 3, 0.4)")
con.execute("INSERT INTO vocabulary_reviews(id, user_id, vocabulary_id, memory_level, next_review_at) "
            "VALUES (1, 'local_user', 5, 2, '2024-02-01T00:00:00Z')")
con.execute("INSERT INTO daily_tasks(id, user_id, plan_date, task_type, status) "
            "VALUES (1, 'local_user', '2024-01-15', 'vocabulary', 'pending')")
con.execute("INSERT INTO user_answers(id, user_id, skill, is_correct, answered_at) "
            "VALUES (1, 'local_user', 'vocabulary', 1, '2024-01-15T10:00:00Z')")
con.execute("INSERT INTO learning_statistics(user_id, questions_answered, correct_count, current_streak) "
            "VALUES ('local_user', 40, 28, 6)")
con.commit()

def snapshot():
    out = {}
    for (t,) in con.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"):
        out[t] = con.execute('SELECT COUNT(*) FROM "%s"' % t).fetchone()[0]
    return out

before = snapshot()
before_profile = con.execute('SELECT target_band, daily_study_minutes FROM study_goal').fetchone()
before_score = con.execute('SELECT score, sample_count FROM skill_scores').fetchone()
before_mk = con.execute('SELECT wrong_count, mastery FROM mistakes').fetchone()
before_vr = con.execute('SELECT memory_level FROM vocabulary_reviews').fetchone()
before_streak = con.execute('SELECT current_streak FROM learning_statistics').fetchone()
print('\n== BEFORE (v1) ==')
print('  tables     :', sorted(before.keys()))
print('  row counts :', before)

# ---- apply v2 ----
print('\n== APPLY v1 -> v2 ==')
for s in v2:
    con.execute(s)
con.execute('PRAGMA user_version = 2')
con.commit()

after = snapshot()
print('\n== AFTER (v2) ==')
print('  row counts :', after)

# assertions
print('\n== ASSERTIONS ==')
ok = True

# 1. every v1 table still exists, same row count
for t, n in before.items():
    n2 = after.get(t)
    if n2 is None:
        print('  FAIL  table dropped:', t); ok = False
    elif n2 != n:
        print('  FAIL  row count changed in %s: %d -> %d' % (t, n, n2)); ok = False
print('  tables preserved + counts unchanged :', all(after.get(t) == n for t, n in before.items()))

# 2. values unchanged
after_profile = con.execute('SELECT target_band, daily_study_minutes FROM study_goal').fetchone()
after_score = con.execute('SELECT score, sample_count FROM skill_scores').fetchone()
after_mk = con.execute('SELECT wrong_count, mastery FROM mistakes').fetchone()
after_vr = con.execute('SELECT memory_level FROM vocabulary_reviews').fetchone()
after_streak = con.execute('SELECT current_streak FROM learning_statistics').fetchone()
print('  profile  unchanged :', before_profile == after_profile, before_profile, '->', after_profile)
print('  score    unchanged :', before_score == after_score, before_score, '->', after_score)
print('  mistake  unchanged :', before_mk == after_mk, before_mk, '->', after_mk)
print('  review   unchanged :', before_vr == after_vr, before_vr, '->', after_vr)
print('  streak   unchanged :', before_streak == after_streak, before_streak, '->', after_streak)

# 3. new columns present with default
cols = [r[1] for r in con.execute('PRAGMA table_info(user_profile)')]
print('  font_scale/theme_mode present :', 'font_scale' in cols and 'theme_mode' in cols)
row = con.execute('SELECT font_scale, theme_mode FROM user_profile').fetchone()
print('  defaults applied to existing row :', row)

# 4. new index present
idx = [r[0] for r in con.execute("SELECT name FROM sqlite_master WHERE type='index'")]
print('  idx_ua_user_correct present :', 'idx_ua_user_correct' in idx)

# 5. FK integrity
print('  foreign_key_check :', con.execute('PRAGMA foreign_key_check').fetchall() or 'empty (ok)')
print('  user_version      :', con.execute('PRAGMA user_version').fetchone()[0])

# 6. append-only guard: no DROP/DELETE in any step
danger = [s for s in v1 + v2 if re.search(r'\b(DROP|DELETE|TRUNCATE)\b', s, re.I)]
print('  append-only (no DROP/DELETE in DDL) :', not danger, danger or '')

con.close()
os.remove(db_path)
print('\nRESULT:', 'PASS' if ok else 'FAIL')
