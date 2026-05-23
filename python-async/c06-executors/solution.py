#!/usr/bin/env python3
"""
c06 — ThreadPoolExecutor vs ProcessPoolExecutor

ThreadPoolExecutor:
  - Use for I/O-bound blocking code (requests, boto3, file reads)
  - Threads share memory — no serialization overhead
  - GIL limits CPU usage to ~1 core for CPU-bound code

ProcessPoolExecutor:
  - Use for CPU-bound code (data processing, compression, ML inference)
  - True parallelism — each worker is a separate Python process
  - Higher overhead (fork + serialize/deserialize args via pickle)

asyncio + run_in_executor:
  - Bridge between async code and blocking libraries
  - Runs blocking call in thread pool without blocking the event loop

Run: python python-async/c06-executors/solution.py
"""

import asyncio
import time
import math
import urllib.request
from concurrent.futures import ThreadPoolExecutor, ProcessPoolExecutor, as_completed


# ── CPU-bound work ────────────────────────────────────────────────────────────

def is_prime(n: int) -> bool:
    """CPU-bound: trial division primality test."""
    if n < 2: return False
    if n == 2: return True
    if n % 2 == 0: return False
    for i in range(3, int(math.sqrt(n)) + 1, 2):
        if n % i == 0: return False
    return True


def count_primes(start: int, end: int) -> int:
    """Count primes in [start, end]."""
    return sum(1 for n in range(start, end) if is_prime(n))


def demo_cpu_bound():
    print("=== CPU-bound: ThreadPool vs ProcessPool vs sequential ===")
    ranges = [(i * 250_000, (i + 1) * 250_000) for i in range(4)]   # 4 chunks of 250k

    # Sequential
    t0 = time.monotonic()
    seq_total = sum(count_primes(s, e) for s, e in ranges)
    seq_time = time.monotonic() - t0
    print(f"  Sequential   : {seq_total} primes in {seq_time:.2f}s")

    # ThreadPoolExecutor (limited by GIL — minimal speedup for CPU work)
    t0 = time.monotonic()
    with ThreadPoolExecutor(max_workers=4) as pool:
        futures = [pool.submit(count_primes, s, e) for s, e in ranges]
        thread_total = sum(f.result() for f in futures)
    thread_time = time.monotonic() - t0
    print(f"  ThreadPool   : {thread_total} primes in {thread_time:.2f}s ({seq_time/thread_time:.1f}× — GIL limits gain)")

    # ProcessPoolExecutor (true parallelism — real speedup)
    t0 = time.monotonic()
    with ProcessPoolExecutor(max_workers=4) as pool:
        futures = [pool.submit(count_primes, s, e) for s, e in ranges]
        proc_total = sum(f.result() for f in futures)
    proc_time = time.monotonic() - t0
    print(f"  ProcessPool  : {proc_total} primes in {proc_time:.2f}s ({seq_time/proc_time:.1f}× speedup)")
    print()


# ── I/O-bound work ────────────────────────────────────────────────────────────

def fetch_url(url: str) -> tuple[str, int]:
    """Blocking HTTP GET — suitable for ThreadPool."""
    try:
        with urllib.request.urlopen(url, timeout=3) as resp:
            return url, len(resp.read())
    except Exception as e:
        return url, -1


def demo_io_bound():
    print("=== I/O-bound: ThreadPool for blocking requests ===")
    urls = [
        "http://localhost:8080/health",
        "http://localhost:8080/items?page=1",
        "http://localhost:8080/items?page=2",
        "http://localhost:8080/items?page=3",
        "http://localhost:8080/health",
    ]

    # Sequential
    t0 = time.monotonic()
    seq = [fetch_url(u) for u in urls]
    seq_time = time.monotonic() - t0

    # ThreadPool (I/O releases GIL → real concurrency)
    t0 = time.monotonic()
    with ThreadPoolExecutor(max_workers=5) as pool:
        futures = {pool.submit(fetch_url, u): u for u in urls}
        thread_results = []
        for future in as_completed(futures):   # yields as each completes
            url, size = future.result()
            thread_results.append((url, size))
    thread_time = time.monotonic() - t0

    print(f"  Sequential  : {seq_time:.2f}s")
    print(f"  ThreadPool  : {thread_time:.2f}s  ({seq_time/thread_time:.1f}× speedup)")
    for url, size in thread_results:
        print(f"    {url.replace('http://localhost:8080', '')}: {size} bytes")
    print()


# ── asyncio + run_in_executor ────────────────────────────────────────────────
# Use when you're in async code but need to call a blocking library.

async def demo_run_in_executor():
    print("=== asyncio.run_in_executor — bridge blocking code into async ===")
    loop = asyncio.get_running_loop()

    urls = ["http://localhost:8080/health"] * 4

    t0 = time.monotonic()
    results = await asyncio.gather(*[
        loop.run_in_executor(None, fetch_url, url)   # None = default ThreadPoolExecutor
        for url in urls
    ])
    elapsed = time.monotonic() - t0
    print(f"  {len(results)} requests via run_in_executor in {elapsed:.2f}s")
    print(f"  Results: {[(r[0].split('/')[-1] or 'health', r[1]) for r in results]}")
    print()


# ── as_completed — process results as they arrive ──────────────────────────────

def demo_as_completed():
    print("=== as_completed — react to results in arrival order ===")
    import random

    def slow_fetch(i):
        time.sleep(random.uniform(0.1, 0.5))
        return i, i * i

    t0 = time.monotonic()
    with ThreadPoolExecutor(max_workers=5) as pool:
        futures = {pool.submit(slow_fetch, i): i for i in range(5)}
        for fut in as_completed(futures):
            i, result = fut.result()
            print(f"  [{time.monotonic()-t0:.2f}s] task-{i} → {result}")
    print()


async def main():
    demo_cpu_bound()
    demo_io_bound()
    await demo_run_in_executor()
    demo_as_completed()

    print("=== Rule of thumb ===")
    print("  I/O-bound blocking code   → ThreadPoolExecutor or asyncio + aiohttp")
    print("  CPU-bound code            → ProcessPoolExecutor")
    print("  Async code + blocking lib → loop.run_in_executor(None, blocking_fn)")


if __name__ == "__main__":
    asyncio.run(main())
