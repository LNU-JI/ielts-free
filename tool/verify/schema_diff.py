import re
import os
root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
dart=open(root+"/lib/core/database/schema_content.dart",encoding="utf-8").read()
m=re.search(r"kContentSchemaSql = '''(.*?)'''", dart, re.S).group(1)
def norm_list(sql):
    # Strip SQL line comments from BOTH sources before comparing, otherwise a
    # comment added to one copy only (or to both, as the Dart string is not
    # pre-processed) shows up as a spurious DDL difference. Comments carry no
    # schema meaning, so ignoring them is what "identical DDL" actually means.
    stripped = "\n".join(
        l for l in sql.split("\n") if not l.strip().startswith("--"))
    return [re.sub(r'\s+',' ',s).strip() for s in stripped.split(';') if s.strip()]
from_dart=norm_list(m)
raw=open(root+"/content_pipeline/schema.sql",encoding="utf-8").read()
from_file=norm_list(raw)
print("dart stmts:", len(from_dart), "file stmts:", len(from_file))
print("IDENTICAL:", from_dart==from_file)
if from_dart!=from_file:
    for a,b in zip(from_dart,from_file):
        if a!=b:
            print("DIFF:/n  dart:",a,"\n  file:",b)
    if len(from_dart)!=len(from_file):
        print("len differs")
