import sys; sys.path.insert(0,'.')
from plan_core import buildPlan
bands=[5.0,6.0,6.5,7.0,7.5,8.0,9.0]
score_sets=[{}, {'vocabulary':0,'reading':0}, {'vocabulary':100,'reading':100},
            {'vocabulary':50,'reading':50,'listening':50,'writing':50,'speaking':50},
            {'vocabulary':90,'reading':10}, {'vocabulary':10,'reading':90},
            {'vocabulary':0,'reading':100,'listening':100,'writing':100,'speaking':100},
            {'vocabulary':100,'reading':0}]
prio_sets=[{}, {'vocabulary':5.0},{'reading':5.0},{'vocabulary':1.0,'reading':5.0},
           {'listening':5.0},{'vocabulary':5.0,'reading':5.0}]
weaks=[None,'vocabulary','reading','listening','writing','speaking']
dayslist=[None,200,120,91,90,60,30,29,10,0,-5]
viol=0; ex=[]
for dm in range(15,181):
  for band in bands:
    for sc in score_sets:
      for pr in prio_sets:
        for wk in weaks:
          for dy in dayslist:
            m=buildPlan(band,sc,dy,dm,pr,wk); tot=sum(m.values())
            if tot!=dm or any(v<5 for v in m.values()):
                viol+=1
                if len(ex)<8: ex.append((dm,band,wk,dy,pr,sc,dict(m),tot))
print("violations for dm>=15:", viol)
for e in ex:
    dm,band,wk,dy,pr,sc,m,tot=e
    print(f"  dm={dm} band={band} weakest={wk} days={dy} prio={pr} scores={sc} -> {m} sum={tot}")
print("--- dm<15 degenerate ---")
for dm in [1,3,5,7,10,12,14]:
    m=buildPlan(7.0,{'vocabulary':50},60,dm); print(f"  dm={dm} -> {m} sum={sum(m.values())}")
print("--- normal ---")
for dm in [15,30,60,90,120]:
    m=buildPlan(7.0,{'vocabulary':50,'reading':50},60,dm); print(f"  dm={dm} -> {m} sum={sum(m.values())}")
