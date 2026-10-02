# -*- coding: utf-8 -*-
import sqlite3, json, os
import os
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
con = sqlite3.connect('file:%s?mode=ro' % os.path.join(ROOT, 'assets', 'seed', 'ielts_content_v1.db').replace('\\','/'), uri=True)
cur = con.cursor()
print('rq cols:', [r[1] for r in cur.execute('PRAGMA table_info(reading_questions)')])
print('vocab cols:', [r[1] for r in cur.execute('PRAGMA table_info(vocabulary)')])
man = json.load(open(os.path.join(ROOT, 'assets', 'seed', 'manifest.json'), encoding='utf-8'))
keys = ['contentVersion','vocabularyCount','readingCount','readingQuestionCount','listeningCount','speakingCount','writingCount','checksum','contentDigest']
print('manifest:', {k: man.get(k) for k in keys})
