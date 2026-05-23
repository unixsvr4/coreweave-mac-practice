#!/usr/bin/env python3
"""
c02 — asyncio.gather vs asyncio.wait

The critical difference: exception handling.

  gather(*coros)          → raises on first exception (cancels rest by default)
  gather(*coros, return_exceptions=True)  → returns exceptions as values (no raise)
  wait(tasks, ...)        → always returns (done, pending) sets; never raises

Run: python python-async/c02-gather-vs-wait/solution.py
"""

import asyncio
import time


# ── Coroutines ────────────────────────────────────────────────────────────────

async def succeed(name: str, delay: float) -> str:
    await asyncio.sleep(delay)
    return f"{name}: ok after {delay}s"


async def fail(name: str, delay: float) -> str:
    await asyncio.sleep(delay)
    raise ValueError(f"{name}: exploded after {delay}s")


# ── gather — raises on first exception ────────────────────────────────────────

async def demo_gather_raises():
    print("=== gather (default) — first exception cancels and raises ===")
    try:
        results = await asyncio.gather(
            succeed("A", 0.1),
            fail("B", 0.2),       # this raises
            succeed("C", 0.5),    # this never finishes
        )
    except ValueError as e:
        print(f"Exception propagated: {e}")
        print("A and C results are lost\n")


async def demo_gather_return_exceptions():
    print("=== gather(return_exceptions=True) — all finish, errors as values ===")
    results = await asyncio.gather(
        succeed("A", 0.1),
        fail("B", 0.2),
        succeed("C", 0.3),
        return_exceptions=True,   # exceptions become return values, no raise
    )
    for i, r in enumerate(results):
        if isinstance(r, Exception):
            print(f"  Task {i}: ERROR — {r}")
        else:
            print(f"  Task {i}: {r}")
    print()


# ── asyncio.wait — always returns done/pending sets ───────────────────────────

async def demo_wait():
    print("=== asyncio.wait — fine-grained control ===")
    tasks = [
        asyncio.create_task(succeed("A", 0.1), name="A"),
        asyncio.create_task(fail("B", 0.2), name="B"),
        asyncio.create_task(succeed("C", 0.5), name="C"),
    ]

    # FIRST_EXCEPTION → stop waiting when any task raises
    done, pending = await asyncio.wait(tasks, return_when=asyncio.FIRST_EXCEPTION)
    print(f"Done: {[t.get_name() for t in done]}")
    print(f"Pending: {[t.get_name() for t in pending]}")

    for t in done:
        if t.exception():
            print(f"  {t.get_name()} raised: {t.exception()}")
        else:
            print(f"  {t.get_name()} returned: {t.result()}")

    # Cancel pending tasks (important — don't leak them)
    for t in pending:
        t.cancel()
    await asyncio.gather(*pending, return_exceptions=True)
    print()


async def demo_wait_with_timeout():
    print("=== asyncio.wait with timeout ===")
    tasks = [
        asyncio.create_task(succeed("fast", 0.1)),
        asyncio.create_task(succeed("slow", 5.0)),   # simulates a hanging request
    ]

    done, pending = await asyncio.wait(tasks, timeout=0.5)
    print(f"Completed within 0.5s: {len(done)}")
    print(f"Still running (timed out): {len(pending)}")

    for t in done:
        print(f"  Result: {t.result()}")

    for t in pending:
        t.cancel()
    await asyncio.gather(*pending, return_exceptions=True)
    print()


# ── Summary table ─────────────────────────────────────────────────────────────

def print_comparison():
    print("=== When to use which ===")
    rows = [
        ("gather()", "All or nothing — raises on first error", "Simple fan-out, all must succeed"),
        ("gather(return_exceptions=True)", "All complete, errors as values", "Batch ops where partial failure ok"),
        ("wait(FIRST_COMPLETED)", "Returns after first task done", "Race: first result wins"),
        ("wait(FIRST_EXCEPTION)", "Returns after first failure", "Abort-early on any error"),
        ("wait(ALL_COMPLETED)", "Returns when all done", "Same as gather, but with task handles"),
        ("wait(..., timeout=N)", "Returns after N seconds", "Deadline-bounded fan-out"),
    ]
    print(f"{'Function':<38} {'Behavior':<40} {'Use case'}")
    print("-" * 110)
    for fn, behavior, use in rows:
        print(f"{fn:<38} {behavior:<40} {use}")
    print()


async def main():
    await demo_gather_raises()
    await demo_gather_return_exceptions()
    await demo_wait()
    await demo_wait_with_timeout()
    print_comparison()


if __name__ == "__main__":
    asyncio.run(main())
