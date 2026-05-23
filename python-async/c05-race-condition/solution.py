#!/usr/bin/env python3
"""
c05 — Race Conditions: Detection and Fixes

Three scenarios:
  A. Threading race — fix with threading.Lock
  B. Asyncio race — fix with asyncio.Lock (even single-threaded code can race)
  C. Thread-safe data structures (Queue, deque)

Run: python python-async/c05-race-condition/solution.py
"""

import threading
import asyncio
import time
from collections import deque
from queue import Queue


N = 100_000


# ── A: threading.Lock ────────────────────────────────────────────────────────

def demo_threading_race():
    print("=== A: threading.Lock ===")

    # Broken (race)
    counter_bad = [0]
    def inc_bad():
        for _ in range(N):
            counter_bad[0] = counter_bad[0] + 1

    # Fixed (lock)
    counter_good = [0]
    lock = threading.Lock()
    def inc_good():
        for _ in range(N):
            with lock:
                counter_good[0] += 1

    # Run broken version
    threads = [threading.Thread(target=inc_bad) for _ in range(2)]
    for t in threads: t.start()
    for t in threads: t.join()
    print(f"  Without lock: {counter_good[0]} (expected {N*2}, lost {N*2 - counter_bad[0]})")

    # Run fixed version
    threads = [threading.Thread(target=inc_good) for _ in range(2)]
    for t in threads: t.start()
    for t in threads: t.join()
    print(f"  With lock   : {counter_good[0]} ✓\n")


# ── B: asyncio.Lock (even single-threaded code can race) ────────────────────
# asyncio races happen at await points — the event loop can switch tasks there.

async def demo_asyncio_race():
    print("=== B: asyncio.Lock (single-threaded but still racy at await) ===")

    # Broken: two coroutines read the same value, both increment, one is lost
    balance_bad = [1000]
    async def withdraw_bad(amount):
        current = balance_bad[0]      # read
        await asyncio.sleep(0)         # yield → other coroutine runs here
        balance_bad[0] = current - amount  # write old value − amount (lost update)

    await asyncio.gather(withdraw_bad(100), withdraw_bad(200))
    print(f"  Without lock: balance={balance_bad[0]} (expected 700, lost an update)")

    # Fixed: asyncio.Lock prevents interleaving at the await point
    balance_good = [1000]
    lock = asyncio.Lock()
    async def withdraw_good(amount):
        async with lock:
            current = balance_good[0]
            await asyncio.sleep(0)     # yield inside lock — safe
            balance_good[0] = current - amount

    await asyncio.gather(withdraw_good(100), withdraw_good(200))
    print(f"  With lock   : balance={balance_good[0]} ✓\n")


# ── C: Thread-safe data structures ───────────────────────────────────────────

def demo_thread_safe_structures():
    print("=== C: Thread-safe data structures (no explicit Lock needed) ===")

    # queue.Queue — thread-safe FIFO (ideal for producer/consumer)
    q: Queue[int] = Queue()
    results = []

    def producer():
        for i in range(5):
            q.put(i)
            time.sleep(0.01)
        q.put(None)  # sentinel

    def consumer():
        while True:
            item = q.get()
            if item is None:
                break
            results.append(item * 2)

    p = threading.Thread(target=producer)
    c = threading.Thread(target=consumer)
    p.start(); c.start()
    p.join(); c.join()
    print(f"  Queue results: {results}")

    # collections.deque with maxlen — thread-safe for append/pop from opposite ends
    # (NOT safe for arbitrary operations — only appendleft/append/pop/popleft)
    log = deque(maxlen=100)
    def log_event(msg):
        log.append(msg)   # thread-safe

    threads = [threading.Thread(target=log_event, args=(f"event-{i}",)) for i in range(10)]
    for t in threads: t.start()
    for t in threads: t.join()
    print(f"  deque log: {len(log)} events (all captured)\n")


# ── Summary ───────────────────────────────────────────────────────────────────

def print_summary():
    print("=== When races occur and how to fix ===")
    rows = [
        ("threading.Thread", "Preemption between read+write", "threading.Lock / RLock"),
        ("asyncio coroutines", "await between read+write", "asyncio.Lock"),
        ("Shared list", "concurrent append/slice", "queue.Queue or asyncio.Queue"),
        ("Shared dict", "concurrent setitem/getitem", "threading.Lock or use immutable"),
        ("File writes", "interleaved writes", "threading.Lock + open with 'a'"),
    ]
    print(f"{'Context':<25} {'Race point':<35} {'Fix'}")
    print("-" * 80)
    for ctx, race, fix in rows:
        print(f"{ctx:<25} {race:<35} {fix}")
    print()


async def main():
    demo_threading_race()
    await demo_asyncio_race()
    demo_thread_safe_structures()
    print_summary()


if __name__ == "__main__":
    asyncio.run(main())
