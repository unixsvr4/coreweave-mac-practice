#!/usr/bin/env python3
"""
c01 — Async HTTP: Fetch Multiple URLs Concurrently

Problem: Fetch N URLs concurrently and return their results.
With sequential requests: total time = sum of each request latency.
With asyncio.gather: total time ≈ max(latencies).

Run: python python-async/c01-async-http/solution.py
"""

import asyncio
import time
import urllib.request
from typing import NamedTuple


class FetchResult(NamedTuple):
    url: str
    status: int | None
    body_len: int
    elapsed: float
    error: str | None


# ── Version A: stdlib asyncio + run_in_executor ───────────────────────────────
# No dependencies. run_in_executor runs blocking code in a thread pool
# while yielding control to the event loop between requests.

async def fetch_one_stdlib(session_executor, url: str) -> FetchResult:
    start = time.monotonic()
    loop = asyncio.get_running_loop()
    try:
        def _get():
            with urllib.request.urlopen(url, timeout=5) as resp:
                return resp.status, len(resp.read())
        status, body_len = await loop.run_in_executor(session_executor, _get)
        return FetchResult(url, status, body_len, time.monotonic() - start, None)
    except Exception as e:
        return FetchResult(url, None, 0, time.monotonic() - start, str(e))


async def fetch_all_stdlib(urls: list[str]) -> list[FetchResult]:
    # None → uses default ThreadPoolExecutor
    tasks = [fetch_one_stdlib(None, url) for url in urls]
    return await asyncio.gather(*tasks)


# ── Version B: aiohttp (install: pip install aiohttp) ─────────────────────────
# True async I/O — no thread pool needed. Better for high concurrency.

async def fetch_all_aiohttp(urls: list[str]) -> list[FetchResult]:
    try:
        import aiohttp
    except ImportError:
        print("aiohttp not installed — using stdlib fallback")
        return await fetch_all_stdlib(urls)

    async def _fetch(session, url):
        start = time.monotonic()
        try:
            async with session.get(url, timeout=aiohttp.ClientTimeout(total=5)) as resp:
                body = await resp.read()
                return FetchResult(url, resp.status, len(body), time.monotonic() - start, None)
        except Exception as e:
            return FetchResult(url, None, 0, time.monotonic() - start, str(e))

    async with aiohttp.ClientSession() as session:
        return await asyncio.gather(*[_fetch(session, url) for url in urls])


# ── Main ───────────────────────────────────────────────────────────────────────

URLS = [
    "http://httpbin.org/delay/1",    # sleeps 1s
    "http://httpbin.org/delay/2",    # sleeps 2s
    "http://httpbin.org/delay/1",    # sleeps 1s
    "http://httpbin.org/status/200",
    "http://httpbin.org/status/404",
]

# Local test URLs (use these if httpbin is slow)
LOCAL_URLS = [
    "http://localhost:8080/health",
    "http://localhost:8080/items?page=1&limit=5",
    "http://localhost:8080/items?page=2&limit=5",
    "http://localhost:8080/items?page=3&limit=5",
    "http://localhost:8080/health",
]


async def main():
    urls = LOCAL_URLS
    print(f"Fetching {len(urls)} URLs concurrently...\n")

    # Sequential baseline
    t0 = time.monotonic()
    seq_results = []
    for url in urls:
        r = await fetch_one_stdlib(None, url)
        seq_results.append(r)
    seq_time = time.monotonic() - t0
    print(f"Sequential: {seq_time:.2f}s")

    # Concurrent
    t0 = time.monotonic()
    results = await fetch_all_stdlib(urls)
    conc_time = time.monotonic() - t0
    print(f"Concurrent: {conc_time:.2f}s  ({seq_time/conc_time:.1f}× speedup)\n")

    print(f"{'URL':<45} {'STATUS':>6} {'BYTES':>8} {'TIME':>7} ERROR")
    print("-" * 80)
    for r in results:
        short_url = r.url.replace("http://localhost:8080", "")[:44]
        status = str(r.status) if r.status else "ERR"
        error = r.error[:20] if r.error else ""
        print(f"{short_url:<45} {status:>6} {r.body_len:>8} {r.elapsed:>6.2f}s {error}")


if __name__ == "__main__":
    asyncio.run(main())
