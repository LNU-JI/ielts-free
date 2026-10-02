import re, glob, os
import os
root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
files=sorted(glob.glob(root+"/test/**/*.dart", recursive=True))
def strip_code(s):
    # remove line comments and strings to avoid false brace counts
    out=[]; i=0; n=len(s)
    while i<n:
        c=s[i]
        if c=='/' and i+1<n and s[i+1]=='/':
            while i<n and s[i]!='\n': i+=1
        elif c=='/' and i+1<n and s[i+1]=='*':
            i+=2
            while i+1<n and not (s[i]=='*' and s[i+1]=='/'): i+=1
            i+=2
        elif c=="'":
            # could be triple quote
            if s[i:i+3]=="'''":
                i+=3
                while i+2<n and s[i:i+3]!="'''": i+=1
                i+=3
            else:
                i+=1
                while i<n and s[i]!="'":
                    if s[i]=='\\': i+=1
                    i+=1
                i+=1
        elif c=='"':
            if s[i:i+3]=='"""':
                i+=3
                while i+2<n and s[i:i+3]!='"""': i+=1
                i+=3
            else:
                i+=1
                while i<n and s[i]!='"':
                    if s[i]=='\\': i+=1
                    i+=1
                i+=1
        else:
            out.append(c); i+=1
    return ''.join(out)
bad=0
for f in files:
    s=open(f,encoding="utf-8").read()
    code=strip_code(s)
    for op,cl,name in [('{','}','brace'),('(',')','paren'),('[',']','bracket')]:
        if code.count(op)!=code.count(cl):
            print(f"UNBALANCED {name} in {os.path.relpath(f,root)}: {code.count(op)} vs {code.count(cl)}")
            bad+=1
    # check file ends with newline & has main()
    if 'void main(' not in s: print("NO main() in", os.path.relpath(f,root)); bad+=1
print(f"checked {len(files)} files; issues={bad}")
