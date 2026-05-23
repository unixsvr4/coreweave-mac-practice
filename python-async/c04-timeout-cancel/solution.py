#!/usr/bin/env python3
"""
c04 — Timeout and Cancellation

asyncio.wait_for   → raises TimeoutError after N seconds; cancels the inner task
asyncio.shield     → protects a coroutine from being cancelled (useful for cleanup)
task.cancel()      → schedules CancelledError inside the coroutine

Run: python python-async/c04-timeout-cancel/solution.py
"""

import asyncio


# ── wait_for ──────────────────────────────────────────────────────────────────

async def slow_operation(name: str, delay: float) -> str:
    print(f"  [{name}] starting (will take {delay}s)")
    try:
        await asyncio.sleep(delay)
        print(f"  [{name}] finished")
        return f"{name}: done"
    except asyncio.CancelledError:
        print(f"  [{name}] was CANCELLED — running cleanup")
        # Always re-raise CancelledError so the event loop knows the task stopped
        raise


async def demo_wait_for():
    print("=== asyncio.wait_for — timeout ===")

    # Case 1: finishes in time
    try:
        result = await asyncio.wait_for(slow_operation("fast", 0.1), timeout=1.0)
        print(f"  Result: {result}\n")
    except asyncio.TimeoutError:
        print("  Timed out\n")

    # Case 2: does NOT finish in time → TimeoutError
    try:
        result = await asyncio.wait_for(slow_operation("slow", 5.0), timeout=0.5)
        print(f"  Result: {result}\n")
    except asyncio.TimeoutError:
        print("  Timed out (expected)\n")


# ── shield: protect a coroutine from cancellation ─────────────────────────────

async def critical_cleanup(job_id: str) -> None:
    """Cannot be cancelled — simulates checkpoint save, database commit, etc."""
    print(f"  [cleanup] saving checkpoint for {job_id}...")
    await asyncio.sleep(0.3)    # shielded from cancellation
    print(f"  [cleanup] checkpoint saved ✓")


async def training_job(job_id: str) -> str:
    try:
        await asyncio.sleep(10)   # long-running work
        return f"{job_id}: complete"
    except asyncio.CancelledError:
        print(f"  [{job_id}] cancelled — protecting cleanup with shield")
        # shield prevents cleanup from being cancelled even if our task is cancelled
        await asyncio.shield(critical_cleanup(job_id))
        raise   # re-raise after cleanup


async def demo_shield():
    print("=== asyncio.shield — protect cleanup from cancellation ===")
    task = asyncio.create_task(training_job("job-abc"))

    await asyncio.sleep(0.1)   # let it start
    task.cancel()              # simulate external cancellation (Ctrl+C, timeout, etc.)

    try:
        await task
    except asyncio.CancelledError:
        print("  Task cancelled, but cleanup ran to completion\n")


# ── task.cancel() — manual cancellation ───────────────────────────────────────

async def demo_task_cancel():
    print("=== task.cancel() — cancel by name, check done/cancelled ===")

    tasks = [
        asyncio.create_task(slow_operation(f"task-{i}", i * 0.3), name=f"task-{i}")
        for i in range(1, 5)
    ]

    await asyncio.sleep(0.5)   # let some tasks start

    # Cancel all tasks
    for t in tasks:
        t.cancel()

    # Gather with return_exceptions so we get CancelledError as a value
    results = await asyncio.gather(*tasks, return_exceptions=True)
    for i, r in enumerate(results):
        status = "cancelled" if isinstance(r, asyncio.CancelledError) else f"done: {r}"
        print(f"  task-{i+1}: {status}")
    print()


# ── timeout context manager (Python 3.11+) ────────────────────────────────────

async def demo_timeout_context():
    print("=== asyncio.timeout (Python 3.11+) ===")
    try:
        async with asyncio.timeout(0.3):
            print("  Starting 2s task inside 0.3s timeout...")
            await asyncio.sleep(2.0)
    except asyncio.TimeoutError:
        print("  Timed out (expected)\n")


async def main():
    await demo_wait_for()
    await demo_shield()
    await demo_task_cancel()
    try:
        await demo_timeout_context()
    except AttributeError:
        print("asyncio.timeout requires Python 3.11+\n")


if __name__ == "__main__":
    asyncio.run(main())
