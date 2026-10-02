import re, os, glob, collections

import os
root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
# 1. Parse schema_user.dart DDL -> {table: set(columns)}
src = open(os.path.join(root,"lib/core/database/schema_user.dart"),encoding="utf-8").read()
ddl = re.search(r"kUserSchemaSql = '''(.*?)'''", src, re.S).group(1)
tables = {}
for m in re.finditer(r"CREATE TABLE IF NOT EXISTS (\w+)\s*\((.*?)\n\)", ddl, re.S):
    tname = m.group(1); body = m.group(2)
    cols = []
    for line in body.split("\n"):
        line=line.strip()
        if not line or line.startswith("FOREIGN KEY") or line.startswith("PRIMARY KEY"): continue
        cm = re.match(r"(\w+)\s+", line)
        if cm: cols.append(cm.group(1))
    tables[tname]=set(cols)
allcols = set().union(*tables.values())
print("USER TABLES:", {t:sorted(c) for t,c in tables.items()})
print()

# 2. content schema
csrc = open(os.path.join(root,"lib/core/database/schema_content.dart"),encoding="utf-8").read()
cddl = re.search(r"kContentSchemaSql = '''(.*?)'''", csrc, re.S).group(1)
ctables={}
for m in re.finditer(r"CREATE TABLE IF NOT EXISTS (\w+)\s*\((.*?)\n\)", cddl, re.S):
    tname=m.group(1); body=m.group(2); cols=[]
    for line in body.split("\n"):
        line=line.strip()
        if not line or line.startswith("FOREIGN KEY") or line.startswith("PRIMARY KEY"): continue
        cm=re.match(r"(\w+)\s+",line)
        if cm: cols.append(cm.group(1))
    ctables[tname]=set(cols)
allcols |= set().union(*ctables.values())

# 3. scan dart files for snake_case string literals that look like DB columns
snake = re.compile(r"'([a-z][a-z0-9]*(?:_[a-z0-9]+)+)'")
hits = collections.defaultdict(set)
for path in glob.glob(os.path.join(root,"lib/**/*.dart"), recursive=True):
    txt = open(path,encoding="utf-8").read()
    for m in snake.finditer(txt):
        tok=m.group(1)
        if tok not in allcols:
            hits[tok].add(os.path.relpath(path, root))

# Filter out obvious non-columns
noise = {'app_compatibility','is_correct','idx_','yyy','placeholder'}
unknown = {k:v for k,v in hits.items() if not k.startswith('idx_')}
print("=== snake_case string literals NOT matching any schema column ===")
for k in sorted(unknown):
    print(f"  {k!r:38s} <- {sorted(unknown[k])[:4]}")
