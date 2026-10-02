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
sum_viol=0; min_viol=0; ex_sum=[]; ex_min=[]
for dm in range(15,181):
  for band in bands:
    for sc in score_sets:
      for pr in prio_sets:
        for wk in weaks:
          for dy in dayslist:
            m=buildPlan(band,sc,dy,dm,pr,wk); tot=sum(m.values())
            if tot!=dm:
                sum_viol+=1
                if len(ex_sum)<5: ex_sum.append((dm,m,tot))
            if any(v<5 for v in m.values()):
                min_viol+=1
                if len(ex_min)<6: ex_min.append((dm,band,wk,dy,pr,sc,dict(m)))
print("=== dm>=15 ===")
print("sum != dailyMinutes  :", sum_viol)
for e in ex_sum: print("   ", e)
print("any bucket < 5 min   :", min_viol)
for e in ex_min:
    dm,band,wk,dy,pr,sc,m=e
    print(f"    dm={dm} band={band} weakest={wk} days={dy} prio={pr} scores={sc} -> {m}")
# minimal repro
print("\n=== minimal repro dm=18 ===")
m=buildPlan(8.0,{'vocabulary':90,'reading':10},29,18,{'reading':5.0},None)
print("  buildPlan(8.0, {vocab:90, reading:10}, 29, 18, {reading:5.0}, None) ->", m, "sum", sum(m.values()))
