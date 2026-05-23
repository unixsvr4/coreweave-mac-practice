#!/usr/bin/env python3
"""
c05 — Race Condition  [BROKEN VERSION]

This script has a data race on `counter`. Run it and observe the wrong final value.
Then look at solution.py to see the fix.

The race: two threads both read counter=0, both increment to 1, both write 1.
Net result: 2 increments → counter=1 (lost update).

Run: python python-async/c05-race-condition/broken.py
Expected: counter = 10000
Actual:   counter < 10000  (non-deterministic)
"""

import threading

counter = 0
N = 10_000


def increment():
    global counter
    for _ in range(N):
        # NON-ATOMIC: read → increment → write — thread can be preempted between steps
        counter = counter + 1


t1 = threading.Thread(target=increment)
t2 = threading.Thread(target=increment)
t1.start()
t2.start()
t1.join()
t2.join()

expected = N * 2
print(f"Expected : {expected}")
print(f"Actual   : {counter}")
print(f"Lost     : {expected - counter} updates (race condition)")
print()
print("Note: GIL makes this less obvious in CPython — try larger N or use PyPy.")
print("The fix: use threading.Lock() or threading.local() — see solution.py")
