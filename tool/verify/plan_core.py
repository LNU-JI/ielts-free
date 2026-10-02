import math
def dart_round(x): return math.floor(x + 0.5) if x >= 0 else math.ceil(x - 0.5)
baseWeights = {
  'foundation':   {'vocabulary':0.40,'reading':0.25,'mistakes':0.15},
  'focus':        {'vocabulary':0.30,'reading':0.35,'mistakes':0.20},
  'comprehensive':{'vocabulary':0.20,'reading':0.30,'mistakes':0.35},
}
BUCKETS = ['vocabulary','reading','mistakes']; MIN_TASK=5; ROUND_TO=5
def phaseOf(days):
    if days is None: return 'foundation'
    if days > 90: return 'foundation'
    if days >= 30: return 'focus'
    return 'comprehensive'
def renormalised(phase):
    raw=baseWeights[phase]; total=sum(raw.values()) or 1
    return {k:v/total for k,v in raw.items()}
def targetScoreForBand(band): return max(0.0,min(9.0,band))/9.0*100.0
def mistakesCurrentScore(scores):
    vals=[scores[s] for s in ['vocabulary','reading','listening','writing','speaking'] if s in scores]
    return sum(vals)/len(vals) if vals else 0
def currentScoreOf(b,scores,ms): return scores.get(b,0) if b!='mistakes' else ms
def priorityOf(b,priorities,weakest):
    if b=='vocabulary': return priorities.get('vocabulary',1.0)
    if b=='reading': return priorities.get('reading',1.0)
    if weakest and weakest in priorities: return priorities[weakest]
    mx=max([v for v in priorities.values()], default=0)
    return mx if mx>0 else 1.0
def weakestBucket(weakest):
    if weakest is None: return None
    if weakest=='vocabulary': return 'vocabulary'
    if weakest=='reading': return 'reading'
    if weakest in ('listening','writing','speaking'): return 'mistakes'
    return None
def roundTo(v): return dart_round(v/ROUND_TO)*ROUND_TO
def fixSum(minutes,target,weights):
    if not minutes: return
    s=sum(minutes.values()); largest=next(iter(minutes))
    for b in minutes:
        if minutes[b]>minutes[largest] or (minutes[b]==minutes[largest] and weights[b]>weights[largest]): largest=b
    minutes[largest]=minutes[largest]+(target-s)
    for b in minutes:
        if minutes[b]<MIN_TASK: minutes[b]=MIN_TASK
    newSum=sum(minutes.values())
    if newSum!=target: minutes[largest]=minutes[largest]+(target-newSum)
def buildPlan(targetBand,scores,days,dailyMinutes,priorities=None,weakest=None):
    priorities=priorities or {}
    if dailyMinutes<=0: return {}
    phase=phaseOf(days); base=renormalised(phase)
    targetScore=targetScoreForBand(targetBand); ms=mistakesCurrentScore(scores)
    maxPriority=max([priorityOf(b,priorities,weakest) for b in BUCKETS]); wb=weakestBucket(weakest)
    weights={}
    for b in BUCKETS:
        cs=currentScoreOf(b,scores,ms)
        gap=1+0.5*max(0.0,(targetScore-cs)/100)
        pr=priorityOf(b,priorities,weakest)
        prio=1+0.3*(pr/maxPriority) if maxPriority>0 else 1.0
        weak=1.2 if b==wb else 1.0
        weights[b]=base[b]*gap*prio*weak
    targetMinutes=dailyMinutes if dailyMinutes>=MIN_TASK else MIN_TASK
    maxBuckets=(dailyMinutes//MIN_TASK) if dailyMinutes>=MIN_TASK else 1
    ordered=sorted(BUCKETS,key=lambda b:(-weights[b],BUCKETS.index(b)))
    keep=max(1,min(maxBuckets,len(ordered))); kept=ordered[:keep]
    keptTotal=sum(weights[b] for b in kept) or float(len(kept))
    minutes={}
    for b in kept:
        r=roundTo(weights[b]/keptTotal*targetMinutes); minutes[b]=r if r>=MIN_TASK else MIN_TASK
    fixSum(minutes,targetMinutes,weights)
    return minutes
