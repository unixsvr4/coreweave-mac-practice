# Problem 05 — Retry with Exponential Backoff

## Scenario

A CloudAPI endpoint `/flaky` fails intermittently with 500/503.
Real-world cloud APIs (CoreWeave included) can return transient errors under load.
Your automation must handle this gracefully.

## Task

Write a `retry_with_backoff` decorator (or context manager) that:

1. Retries a failed function call up to `max_retries` times
2. Waits `base_delay * (2 ** attempt)` seconds between attempts (exponential backoff)
3. Adds `random.uniform(0, 1)` jitter to avoid thundering herd
4. Only retries on `requests.HTTPError` with status 500, 502, 503, 504
5. Does **not** retry on 400 or 401 (client errors — retrying won't help)
6. Logs each retry with the attempt number, status code, and wait time

Then write `call_flaky(base_url: str) -> dict` using the decorator.

## Expected behavior

```
Attempt 1 failed: 503 — waiting 2.3s before retry
Attempt 2 failed: 500 — waiting 4.6s before retry
Attempt 3 failed: 503 — waiting 9.1s before retry
Attempt 4 succeeded.
{'data': 'success', 'attempt': 4}
```

## Bonus

Implement the same logic as a `tenacity` library call (3 lines):
```python
from tenacity import retry, stop_after_attempt, wait_exponential
```
