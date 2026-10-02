"""Independent exhaustive check of the fixed `_fixSum` invariants.

Ports the new Dart algorithm 1:1 and asserts, for a large sweep of inputs that
satisfy the documented precondition (`n * min <= target`):

  1. sum(minutes) == target
  2. every bucket >= min

Also confirms the OLD algorithm violated invariant 2 on the same inputs, so the
test is demonstrably able to detect the bug class.
"""
import itertools
import random

MIN = 5
ROUND_TO = 5


def new_fix_sum(minutes, target, weights):
    """1:1 port of the new Dart `_fixSum` (+ its helpers)."""
    if not minutes:
        return minutes
    # step 1: explicit floor
    for k in minutes:
        if minutes[k] < MIN:
            minutes[k] = MIN
    total = sum(minutes.values())

    def largest(only_above_floor=False):
        best, best_minutes, best_weight = None, -1, float('-inf')
        for k in minutes:
            v = minutes[k]
            if only_above_floor and v <= MIN:
                continue
            w = weights.get(k, 0.0)
            if v > best_minutes or (v == best_minutes and w > best_weight):
                best, best_minutes, best_weight = k, v, w
        return best

    # step 2: shave overshoot
    guard = 0
    while total > target:
        donor = largest(only_above_floor=True)
        if donor is None:
            break
        reducible = minutes[donor] - MIN
        excess = total - target
        take = excess if excess < reducible else reducible
        minutes[donor] -= take
        total -= take
        guard += 1
        if guard > 100000:
            raise RuntimeError('loop guard tripped')

    # step 3: fill shortfall
    if total < target:
        recipient = largest()
        minutes[recipient] += target - total
    return minutes


def old_fix_sum(minutes, target, weights):
    """The pre-fix version, for contrast."""
    if not minutes:
        return minutes
    total = sum(minutes.values())
    largest = max(minutes, key=lambda k: (minutes[k], weights.get(k, 0.0)))
    minutes[largest] += target - total
    for k in minutes:
        if minutes[k] < MIN:
            minutes[k] = MIN
    new_sum = sum(minutes.values())
    if new_sum != target:
        minutes[largest] += target - new_sum
    return minutes


KEYS = ['vocabulary', 'reading', 'mistakes']

def sweep():
    random.seed(20261001)
    cases = 0
    new_bad, old_bad = [], []
    sample_old_bad = []

    targets = list(range(1, 131))
    for n in (1, 2, 3):
        keys = KEYS[:n]
        for target in targets:
            if n * MIN > target:
                continue  # precondition not met; algorithm not required to satisfy
            # exhaustive small allocations + randomized larger ones
            allocs = list(itertools.product(range(0, 26), repeat=n))
            allocs += [tuple(random.randint(0, 300) for _ in range(n)) for _ in range(120)]
            for alloc in allocs:
                cases += 1
                weights = {k: random.random() * 5 + 0.1 for k in keys}

                m_new = dict(zip(keys, alloc))
                new_fix_sum(m_new, target, weights)
                if sum(m_new.values()) != target or any(v < MIN for v in m_new.values()):
                    new_bad.append((keys, target, alloc, m_new))

                m_old = dict(zip(keys, alloc))
                old_fix_sum(m_old, target, weights)
                if sum(m_old.values()) != target or any(v < MIN for v in m_old.values()):
                    old_bad.append((keys, target, alloc, m_old))
                    if len(sample_old_bad) < 3 and sum(m_old.values()) == target:
                        sample_old_bad.append((keys, target, alloc, dict(m_old)))

    print(f'cases evaluated            : {cases:,}')
    print(f'NEW algorithm violations   : {len(new_bad):,}')
    print(f'OLD algorithm violations   : {len(old_bad):,}')
    if sample_old_bad:
        print('\nexamples of OLD failures (sum was still correct, floor was broken):')
        for keys, target, alloc, res in sample_old_bad:
            print(f'  target={target:3d} in={dict(zip(keys, alloc))} -> {res}')
    print('\nRESULT:', 'PASS - new algorithm upholds both invariants'
          if not new_bad else 'FAIL')
    if new_bad:
        for c in new_bad[:5]:
            print('  counterexample:', c)


if __name__ == '__main__':
    sweep()
