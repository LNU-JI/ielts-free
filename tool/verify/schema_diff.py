import re
import os
root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
dart=open(root+"/lib/core/database/schema_content.dart",encoding="utf-8").read()
m=re.search(r"kContentSchemaSql = '''(.*?)'''", dart, re.S).group(1)
def norm_list(sql):
    return [re.sub(r'\s+',' ',s).strip() for s in sql.split(';') if s.strip()]
from_dart=norm_list(m)
raw=open(root+"/content_pipeline/schema.sql",encoding="utf-8").read()
nocomment="\n".join(l for l in raw.split("\n") if not l.strip().startswith("--"))
from_file=norm_list(nocomment)
print("dart stmts:", len(from_dart), "file stmts:", len(from_file))
print("IDENTICAL:", from_dart==from_file)
if from_dart!=from_file:
    for a,b in zip(from_dart,from_file):
        if a!=b:
            print("DIFF:/n  dart:",a,"\n  file:",b)
    if len(from_dart)!=len(from_file):
        print("len differs")
