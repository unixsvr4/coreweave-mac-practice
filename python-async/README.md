# Python Async & Concurrency Practice

Covers every concurrency model you need for a Senior SRE/Cloud Support Engineer role:
- `asyncio` (event loop, coroutines, tasks, queues, semaphores)
- `threading` (threads, locks, race conditions)
- `concurrent.futures` (thread pools, process pools)

## Run any exercise

```bash
python python-async/c01-async-http/solution.py
```

No extra dependencies by default. Optional: `pip install aiohttp` for c01 (stdlib fallback included).

## Exercises

| File | Topic | Key concept |
|------|-------|-------------|
| [c01](c01-async-http/) | Async HTTP | `asyncio.gather`, `aiohttp` |
| [c02](c02-gather-vs-wait/) | gather vs wait | exception propagation |
| [c03](c03-producer-consumer/) | Producer-consumer | `asyncio.Queue` |
| [c04](c04-timeout-cancel/) | Timeout & cancel | `asyncio.wait_for`, `asyncio.shield` |
| [c05](c05-race-condition/) | Race conditions | `threading.Lock`, `asyncio.Lock` |
| [c06](c06-executors/) | Thread/Process pools | `concurrent.futures.ThreadPoolExecutor` |
| [c07](c07-semaphore/) | Rate limiting | `asyncio.Semaphore` |

## Mental model: which tool when?

```
I/O-bound work (network, disk):
  → asyncio + aiohttp   if you control the code (best efficiency)
  → ThreadPoolExecutor  if using blocking library (requests, boto3)

CPU-bound work (ML inference, data processing):
  → ProcessPoolExecutor  (bypasses the GIL)
  → multiprocessing.Pool

Mixed (I/O + some CPU):
  → asyncio for I/O coordination
  → run_in_executor for CPU chunks

Simple fire-and-forget tasks:
  → threading.Thread (quick, no result needed)
  → asyncio.create_task (within async context)
```
