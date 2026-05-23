#!/usr/bin/env python3
"""
c03 — Producer-Consumer with asyncio.Queue

Classic pattern for decoupling work generation from work processing.
In cloud support: producer generates jobs/alerts/events; consumers process them.

Variants:
  A. Single producer, multiple consumers (fan-out)
  B. Multiple producers, single consumer (aggregation)
  C. Bounded queue (backpressure) — prevents producer from overwhelming consumers

Run: python python-async/c03-producer-consumer/solution.py
"""

import asyncio
import random
import time


# ── Variant A: 1 producer, N consumers ────────────────────────────────────────

async def producer_a(queue: asyncio.Queue, n_items: int) -> None:
    """Generates N work items and puts them on the queue."""
    for i in range(n_items):
        item = {"id": i, "payload": f"job-{i}", "created": time.monotonic()}
        await queue.put(item)
        print(f"  [producer] put {item['payload']}")
        await asyncio.sleep(random.uniform(0.05, 0.15))

    # Send sentinel values to signal consumers to stop
    # One sentinel per consumer
    print("  [producer] done — sending sentinels")


async def consumer_a(worker_id: int, queue: asyncio.Queue, results: list) -> None:
    """Pulls items from the queue and processes them until sentinel."""
    while True:
        item = await queue.get()   # blocks if queue is empty
        if item is None:           # sentinel — time to stop
            queue.task_done()
            break
        # Simulate processing
        await asyncio.sleep(random.uniform(0.1, 0.3))
        result = {**item, "processed_by": worker_id, "done": time.monotonic()}
        results.append(result)
        print(f"  [worker-{worker_id}] processed {item['payload']}")
        queue.task_done()


async def demo_fan_out():
    print("=== Variant A: 1 producer → 3 consumers (fan-out) ===")
    N_ITEMS = 10
    N_WORKERS = 3
    queue: asyncio.Queue = asyncio.Queue(maxsize=5)   # bounded: backpressure at 5
    results = []

    # Start consumers
    consumers = [
        asyncio.create_task(consumer_a(i, queue, results))
        for i in range(N_WORKERS)
    ]

    # Run producer to completion
    await producer_a(queue, N_ITEMS)

    # Send one sentinel per consumer
    for _ in range(N_WORKERS):
        await queue.put(None)

    # Wait for all consumers to drain the queue
    await queue.join()
    await asyncio.gather(*consumers)

    print(f"\n  Total processed: {len(results)} items by {N_WORKERS} workers\n")


# ── Variant B: Multiple producers + single consumer ────────────────────────────

async def producer_b(pid: int, queue: asyncio.Queue, n: int) -> None:
    for i in range(n):
        await queue.put(f"P{pid}-item{i}")
        await asyncio.sleep(random.uniform(0.05, 0.2))
    print(f"  [producer-{pid}] done")


async def consumer_b(queue: asyncio.Queue, stop_event: asyncio.Event) -> None:
    while not stop_event.is_set() or not queue.empty():
        try:
            item = await asyncio.wait_for(queue.get(), timeout=0.3)
            print(f"  [consumer] got: {item}")
            queue.task_done()
        except asyncio.TimeoutError:
            pass   # no item yet, loop and check stop_event again


async def demo_aggregation():
    print("=== Variant B: 3 producers → 1 consumer (aggregation) ===")
    queue: asyncio.Queue = asyncio.Queue()
    stop = asyncio.Event()

    producers = [
        asyncio.create_task(producer_b(i, queue, 3))
        for i in range(3)
    ]
    consumer = asyncio.create_task(consumer_b(queue, stop))

    # Wait for all producers to finish
    await asyncio.gather(*producers)

    # Let consumer drain remaining items
    await queue.join()
    stop.set()
    await consumer
    print()


# ── Variant C: Pipeline (producer → stage1 → stage2 → sink) ──────────────────

async def stage(name: str, in_q: asyncio.Queue, out_q: asyncio.Queue, transform) -> None:
    while True:
        item = await in_q.get()
        if item is None:
            await out_q.put(None)   # pass sentinel downstream
            in_q.task_done()
            break
        result = await transform(item)
        await out_q.put(result)
        in_q.task_done()


async def demo_pipeline():
    print("=== Variant C: 3-stage pipeline ===")
    raw_q: asyncio.Queue = asyncio.Queue()
    parsed_q: asyncio.Queue = asyncio.Queue()
    enriched_q: asyncio.Queue = asyncio.Queue()
    results = []

    async def parse(x): await asyncio.sleep(0.05); return x * 2
    async def enrich(x): await asyncio.sleep(0.05); return f"result({x})"
    async def sink(q):
        while True:
            item = await q.get()
            if item is None: q.task_done(); break
            results.append(item)
            print(f"  [sink] {item}")
            q.task_done()

    stages = [
        asyncio.create_task(stage("parse",  raw_q,    parsed_q,  parse)),
        asyncio.create_task(stage("enrich", parsed_q, enriched_q, enrich)),
        asyncio.create_task(sink(enriched_q)),
    ]

    for i in range(5):
        await raw_q.put(i)
    await raw_q.put(None)   # sentinel triggers pipeline shutdown cascade

    await asyncio.gather(*stages)
    print(f"  Pipeline output: {results}\n")


async def main():
    await demo_fan_out()
    await demo_aggregation()
    await demo_pipeline()


if __name__ == "__main__":
    asyncio.run(main())
