#!/usr/bin/env python3
"""
c07 — Rate Limiting with asyncio.Semaphore

Problem: You have 50 API calls to make but the server allows only 5 concurrent requests.
Without rate limiting: all 50 fire at once → 429 Too Many Requests / server overload.
With Semaphore(5): max 5 in flight at any time.

Also covers:
  - BoundedSemaphore (prevents over-release bugs)
  - Rate limiting with a token bucket (calls/second limit)
  - asyncio.Event (one-shot signaling between coroutines)

Run: python python-async/c07-semaphore/solution.py
"""

import asyncio
import time
import urllib.request
from dataclasses import dataclass, field


# ── Basic Semaphore ────────────────────────────────────────────────────────────

async def fetch_with_semaphore(sem: asyncio.Semaphore, url: str, i: int) -> str:
    async with sem:   # acquires (blocks if 0 permits) → releases on exit
        # Simulate I/O
        await asyncio.sleep(0.2)
        return f"req-{i}: ok"


async def demo_basic_semaphore():
    print("=== asyncio.Semaphore — limit concurrency to 3 ===")
    N = 10
    sem = asyncio.Semaphore(3)   # max 3 concurrent

    t0 = time.monotonic()
    results = await asyncio.gather(*[
        fetch_with_semaphore(sem, "http://localhost:8080/health", i)
        for i in range(N)
    ])
    elapsed = time.monotonic() - t0

    # Expected: ceil(10/3) * 0.2s ≈ 0.8s (4 batches of 3, 2, 3, 2)
    # Without semaphore: 0.2s flat (all concurrent)
    print(f"  {N} requests with sem(3) finished in {elapsed:.2f}s")
    print(f"  (without semaphore: ~0.2s, showing throttling works)\n")


# ── Real rate limiting against the practice server ────────────────────────────

async def fetch_real(sem: asyncio.Semaphore, i: int) -> tuple[int, int]:
    """Fetch /health with semaphore, return (index, bytes)."""
    loop = asyncio.get_running_loop()
    async with sem:
        def _fetch():
            try:
                with urllib.request.urlopen("http://localhost:8080/health", timeout=3) as r:
                    return len(r.read())
            except Exception:
                return -1
        size = await loop.run_in_executor(None, _fetch)
        return i, size


async def demo_real_rate_limit():
    print("=== Real rate-limited fetch against practice server ===")
    N = 15
    CONCURRENCY = 4
    sem = asyncio.Semaphore(CONCURRENCY)

    t0 = time.monotonic()
    results = await asyncio.gather(*[fetch_real(sem, i) for i in range(N)])
    elapsed = time.monotonic() - t0

    ok = sum(1 for _, s in results if s > 0)
    print(f"  {N} requests, max {CONCURRENCY} concurrent → {ok} succeeded in {elapsed:.2f}s\n")


# ── Token bucket: requests-per-second limit ────────────────────────────────────

class TokenBucket:
    """
    Allows `rate` operations per second with a burst capacity of `capacity`.
    Uses asyncio.Lock to serialize token refills.
    """
    def __init__(self, rate: float, capacity: float) -> None:
        self.rate = rate           # tokens per second
        self.capacity = capacity   # max tokens
        self._tokens = capacity
        self._last = time.monotonic()
        self._lock = asyncio.Lock()

    async def acquire(self) -> None:
        async with self._lock:
            now = time.monotonic()
            elapsed = now - self._last
            self._tokens = min(self.capacity, self._tokens + elapsed * self.rate)
            self._last = now
            if self._tokens < 1:
                wait = (1 - self._tokens) / self.rate
                await asyncio.sleep(wait)
                self._tokens = 0
            else:
                self._tokens -= 1


async def demo_token_bucket():
    print("=== Token bucket: 5 requests/second ===")
    bucket = TokenBucket(rate=5.0, capacity=5.0)
    timestamps = []

    async def call(i):
        await bucket.acquire()
        timestamps.append(time.monotonic())

    t0 = time.monotonic()
    await asyncio.gather(*[call(i) for i in range(12)])
    total = time.monotonic() - t0

    # Show when each request was dispatched
    for i, ts in enumerate(timestamps):
        print(f"  req-{i:02d} dispatched at t={ts - t0:.2f}s")
    print(f"  Total: {total:.2f}s for 12 requests at 5/s (expected ~2.2s)\n")


# ── asyncio.Event — one-shot signal ───────────────────────────────────────────

async def demo_event():
    print("=== asyncio.Event — signal between coroutines ===")
    ready = asyncio.Event()

    async def waiter(name: str):
        print(f"  [{name}] waiting for ready signal...")
        await ready.wait()   # blocks until event is set
        print(f"  [{name}] proceeding!")

    async def setter():
        await asyncio.sleep(0.3)
        print("  [setter] setting ready event")
        ready.set()   # unblocks all waiters simultaneously

    await asyncio.gather(
        waiter("worker-1"),
        waiter("worker-2"),
        waiter("worker-3"),
        setter(),
    )
    print()


async def main():
    await demo_basic_semaphore()
    await demo_real_rate_limit()
    await demo_token_bucket()
    await demo_event()

    print("=== Semaphore vs Lock summary ===")
    print("  asyncio.Lock()          → mutual exclusion (1 holder at a time)")
    print("  asyncio.Semaphore(N)    → concurrency limit (N holders at a time)")
    print("  asyncio.BoundedSemaphore(N) → same + error if released too many times")
    print("  asyncio.Event()         → one-shot broadcast signal")
    print("  asyncio.Condition()     → Lock + wait/notify (like threading.Condition)")


if __name__ == "__main__":
    asyncio.run(main())
