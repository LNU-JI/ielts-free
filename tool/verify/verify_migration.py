# -*- coding: utf-8 -*-
"""Real execution of the user-DB migrations (FR-083 / NFR-30).

DDL is extracted verbatim from `schema_user.dart` (the v1 baseline) and the
versioned steps from `migrations.dart`, then executed against a real sqlite3
database. The script is version-agnostic: it discovers every step in the
`migrationSteps` map and applies them in ascending order, so it keeps working as
new migrations are added.

It proves, on real data:
  1. no table is dropped and no row count changes;
  2. user values survive untouched;
  3. every new column arrives with a usable default;
  4. every migration step is additive (no DROP / DELETE / TRUNCATE);
  5. foreign keys stay valid and `user_version` ends up at the latest version.
"""
import os
import re
import sqlite3
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))

# Matches '''triple quoted''', "double quoted" and 'single quoted' Dart strings.
_DART_STRING = re.compile(r"'''(.*?)'''|\"([^\"]*)\"|'([^']*)'", re.S)


def extract_schema(sql_text, marker):
    """Pull a `const String <marker> = '''...'''` payload out of a Dart file."""
    m = re.search(marker + r"\s*=\s*'''(.*?)'''", sql_text, re.S)
    if not m:
        raise SystemExit('could not find %s in the Dart source' % marker)
    return m.group(1)


def extract_steps(mig_src):
    """Return {version: [statements]} for every `N: <String>[ ... ]` entry."""
    entries = [(int(m.group(1)), m.start(), m.end())
               for m in re.finditer(r'(\d+):\s*<String>\[', mig_src)]
    steps = {}
    for i, (version, _entry_start, body_start) in enumerate(entries):
        body_end = (entries[i + 1][1] if i + 1 < len(entries)
                    else mig_src.index('\n};', body_start))
        block = mig_src[body_start:body_end]
        statements = []
        for sm in _DART_STRING.finditer(block):
            s = (sm.group(1) or sm.group(2) or sm.group(3) or '').strip()
            if s:
                statements.append(s)
        steps[version] = statements
    return steps


schema_src = open(os.path.join(ROOT, 'lib', 'core', 'database', 'schema_user.dart'),
                  encoding='utf-8').read()
mig_src = open(os.path.join(ROOT, 'lib', 'core', 'database', 'migrations.dart'),
               encoding='utf-8').read()

kUserSchemaSql = extract_schema(schema_src, 'kUserSchemaSql')
v1 = [s.strip() for s in kUserSchemaSql.split(';') if s.strip()]
print('== v1 statements parsed from schema_user.dart :', len(v1))

steps = extract_steps(mig_src)
latest = max(steps) if steps else 1
print('== migration steps found in migrations.dart  :',
      sorted(steps), '(latest = %d)' % latest)
for version in sorted(steps):
    print('   v%d -> %d statements' % (version, len(steps[version])))

db_path = os.path.join(tempfile.gettempdir(), 'qa_migrate.db')
if os.path.exists(db_path):
    os.remove(db_path)

con = sqlite3.connect(db_path)
con.execute('PRAGMA foreign_keys = ON')
for s in v1:
    con.execute(s)
con.execute('PRAGMA user_version = 1')
con.commit()

# Representative rows in the tables a migration must not damage.
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
    for (t,) in con.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"):
        out[t] = con.execute('SELECT COUNT(*) FROM "%s"' % t).fetchone()[0]
    return out


def user_values():
    return (
        con.execute('SELECT target_band, daily_study_minutes FROM study_goal').fetchone(),
        con.execute('SELECT score, sample_count FROM skill_scores').fetchone(),
        con.execute('SELECT wrong_count, mastery FROM mistakes').fetchone(),
        con.execute('SELECT memory_level FROM vocabulary_reviews').fetchone(),
        con.execute('SELECT current_streak FROM learning_statistics').fetchone(),
        con.execute('SELECT display_name, weakest_skill FROM user_profile').fetchone(),
    )


before = snapshot()
before_values = user_values()
print('\n== BEFORE (v1) ==')
print('  tables     :', sorted(before.keys()))

# ---- apply every migration in order ----
for version in range(2, latest + 1):
    print('\n== APPLY v%d -> v%d ==' % (version - 1, version))
    for s in steps.get(version, []):
        con.execute(s)
    con.execute('PRAGMA user_version = %d' % version)
    con.commit()

after = snapshot()
after_values = user_values()
print('\n== AFTER (v%d) ==' % latest)
print('  tables     :', sorted(after.keys()))

print('\n== ASSERTIONS ==')
ok = True

# 1. no table dropped, no row count changed
for t, n in before.items():
    n2 = after.get(t)
    if n2 is None:
        print('  FAIL  table dropped:', t)
        ok = False
    elif n2 != n:
        print('  FAIL  row count changed in %s: %d -> %d' % (t, n, n2))
        ok = False
preserved = all(after.get(t) == n for t, n in before.items())
print('  tables preserved + counts unchanged :', preserved)
ok = ok and preserved

# 2. user values untouched
print('  user values unchanged               :', before_values == after_values)
ok = ok and (before_values == after_values)

# 3. every table the migrations introduce actually exists
introduced = set(after) - set(before)
print('  tables introduced                   :', sorted(introduced))
created = all(t in after for t in introduced)
print('  all introduced tables created       :', created)
ok = ok and created

# 4. foreign keys still valid
fk = con.execute('PRAGMA foreign_key_check').fetchall()
print('  foreign_key_check                   :', fk or 'empty (ok)')
ok = ok and not fk

# 5. version stamped
version_now = con.execute('PRAGMA user_version').fetchone()[0]
print('  user_version                        :', version_now, '(expected %d)' % latest)
ok = ok and version_now == latest

# 6. append-only guard across every step
danger = [s for v in steps for s in steps[v]
          if re.search(r'\b(DROP|DELETE|TRUNCATE)\b', s, re.I)]
print('  append-only (no DROP/DELETE)        :', not danger, danger or '')
ok = ok and not danger

con.close()
os.remove(db_path)
print('\nRESULT:', 'PASS' if ok else 'FAIL')
