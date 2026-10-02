# -*- coding: utf-8 -*-
"""Real verification of the read-only Content DB + schema parity. No Flutter needed."""
import hashlib, json, os, re, sqlite3, sys

import os
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
DB = os.path.join(ROOT, 'assets', 'seed', 'ielts_content_v1.db')
MANIFEST = os.path.join(ROOT, 'assets', 'seed', 'manifest.json')

print('== 1. Content DB file vs manifest SHA256 ==')
raw = open(DB, 'rb').read()
file_sha = hashlib.sha256(raw).hexdigest()
man = json.load(open(MANIFEST, encoding='utf-8'))
man_sha = man.get('checksum')
print('  file sha256    :', file_sha)
print('  manifest sha256:', man_sha)
print('  MATCH          :', file_sha == man_sha)
print('  manifest keys  :', sorted(man.keys()))

print('\n== 2. Open read-only + integrity_check ==')
uri = 'file:%s?mode=ro' % DB.replace('\\', '/')
con = sqlite3.connect(uri, uri=True)
cur = con.cursor()
print('  integrity_check:', cur.execute('PRAGMA integrity_check').fetchone()[0])
print('  user_version   :', cur.execute('PRAGMA user_version').fetchone()[0])
print('  foreign_key_chk:', cur.execute('PRAGMA foreign_key_check').fetchall() or 'empty (ok)')
tables = [r[0] for r in cur.execute(
    "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name").fetchall()]
print('  tables         :', tables)

print('\n== 3. Row counts vs manifest ==')
counts = {}
for t in tables:
    counts[t] = cur.execute('SELECT COUNT(*) FROM "%s"' % t).fetchone()[0]
    print('  %-20s = %d' % (t, counts[t]))
print('  manifest counts: vocab=%s reading=%s questions=%s' % (
    man.get('vocabularyCount'), man.get('readingCount'), man.get('readingQuestionCount')))
print('  vocab 300?      :', counts.get('vocabulary') == man.get('vocabularyCount'))
print('  passages 8?     :', counts.get('reading_passages') == man.get('readingCount'))
print('  questions 80?   :', counts.get('reading_questions') == man.get('readingQuestionCount'))

print('\n== 4. Reading question type distribution ==')
for r in cur.execute(
    'SELECT question_type, COUNT(*) FROM reading_questions GROUP BY question_type ORDER BY question_type').fetchall():
    print('  %-22s = %d' % (r[0], r[1]))

print('\n== 5. Write attempt must fail (read-only) ==')
try:
    con.execute("INSERT INTO vocabulary(id, word) VALUES (99999,'x')")
    print('  WRITE SUCCEEDED  -> FAIL (db not read-only!)')
except sqlite3.OperationalError as e:
    print('  write blocked    -> OK:', e)
con.close()

print('\n== 6. kContentSchemaSql == content_pipeline/schema.sql ? ==')
def stmts(sql):
    out = []
    for chunk in sql.split(';'):
        c = re.sub(r'--[^\n]*', '', chunk).strip()
        if c:
            out.append(re.sub(r'\s+', ' ', c))
    return out

schema_dart = open(os.path.join(ROOT, 'lib', 'core', 'database', 'schema_content.dart'),
                   encoding='utf-8').read()
m = re.search(r"kContentSchemaSql\s*=\s*'''(.*?)'''", schema_dart, re.S)
dart_sql = m.group(1)
pipeline_sql = open(os.path.join(ROOT, 'content_pipeline', 'schema.sql'), encoding='utf-8').read()
d = stmts(dart_sql)
p = stmts(pipeline_sql)
print('  dart stmt count    :', len(d))
print('  pipeline stmt count:', len(p))
print('  IDENTICAL          :', d == p)
if d != p:
    for i in range(max(len(d), len(p))):
        a = d[i] if i < len(d) else '<none>'
        b = p[i] if i < len(p) else '<none>'
        if a != b:
            print('   DIFF[%d]\n     dart    : %s\n     pipeline: %s' % (i, a, b))
