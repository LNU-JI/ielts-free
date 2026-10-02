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
bad=set()
for dm in range(15,181):
  for band in bands:
    for sc in score_sets:
      for pr in prio_sets:
        for wk in weaks:
          for dy in dayslist:
            m=buildPlan(band,sc,dy,dm,pr,wk)
            if any(v<5 for v in m.values()): bad.add(dm)
print("dm values (>=15) that can violate the 5-min floor:")
print(sorted(bad))
print()
print("Are the onboarding values 30/60/90/120 affected?", [d for d in (30,60,90,120) if d in bad] or "NO")
print("Multiples of 5 in bad set:", sorted(d for d in bad if d%5==0) or "NONE")
print("Non-multiples of 5 in bad set:", sorted(d for d in bad if d%5!=0))
