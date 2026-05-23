# Asyncio Event Loop — Mental Model

## The key insight

Python's asyncio runs on a **single thread**. There is no parallelism — only concurrency.
While one coroutine is waiting for I/O, the event loop runs another coroutine.
CPU-bound code blocks the entire event loop.

```
Thread 1 (event loop)
│
├── await aiohttp.get(url1)  ← yields control (I/O waiting)
│        └──────────────────────────────────────┐
│         meanwhile:                            │ OS handles I/O
├── await aiohttp.get(url2)  ← yields control  │
│        └──────────────────────────────────────┤
│         meanwhile:                            │
├── url1 response arrives ←──────────────────── ┤
├── url2 response arrives ←──────────────────── ┘
│
└── both done (total time ≈ max(latency1, latency2), not sum)
```

Contrast with threads:
```
Thread 1 ──── fetch url1 ────────────────────────────
Thread 2 ──── fetch url2 ──────────────────
Thread 3 ──── fetch url3 ─────────────────────────────────
                           ← parallel, but GIL limits CPU usage
```

## Three ways to run a coroutine

```python
import asyncio

async def greet(name):
    await asyncio.sleep(1)
    return f"Hello {name}"

# 1. asyncio.run() — creates event loop, runs coroutine, destroys loop
result = asyncio.run(greet("world"))

# 2. asyncio.create_task() — schedules coroutine to run concurrently (within async func)
async def main():
    task = asyncio.create_task(greet("world"))
    # ... do other work ...
    result = await task

# 3. asyncio.gather() — run multiple coroutines concurrently, wait for all
async def main():
    results = await asyncio.gather(greet("Alice"), greet("Bob"))
```

## async / await rules

```python
# async def → defines a coroutine function (calling it returns a coroutine object)
async def fetch(url):
    ...

# await → suspends current coroutine, yields to event loop, resumes when awaitable completes
result = await fetch("http://example.com")

# You can only await inside an async function
# await must precede an awaitable: coroutine, Task, Future, or object with __await__

# Common mistake: calling an async function without await
coro = fetch("http://example.com")   # returns coroutine object, doesn't run it
result = await fetch("http://example.com")   # runs it
```

## Blocking the event loop (BAD)

```python
import time, asyncio

async def bad():
    time.sleep(5)          # BLOCKS event loop — nothing else can run for 5s
    requests.get("url")    # BLOCKS event loop — use aiohttp instead

async def good():
    await asyncio.sleep(5)             # yields to event loop
    async with aiohttp.ClientSession() as s:
        await s.get("url")             # yields to event loop

# To run blocking code without blocking the event loop:
loop = asyncio.get_event_loop()
result = await loop.run_in_executor(None, time.sleep, 5)   # runs in thread pool
```
