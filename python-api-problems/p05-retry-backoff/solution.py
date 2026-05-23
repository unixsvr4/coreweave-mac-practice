#!/usr/bin/env python3
"""
p05 — Retry with Exponential Backoff  [SOLUTION]

Key points:
  - Exponential backoff with jitter prevents thundering herd
  - Only retry TRANSIENT errors (5xx) — never client errors (4xx)
  - Decorator pattern keeps call sites clean
  - functools.wraps preserves docstrings and __name__
"""

import time
import random
import functools
import requests


# ── Retry decorator ───────────────────────────────────────────────────────────

RETRIABLE_STATUS = {500, 502, 503, 504}


def retry_with_backoff(max_retries: int = 5, base_delay: float = 1.0):
    """
    Decorator factory. Retries on retriable HTTP errors with exponential backoff + jitter.
    Usage: @retry_with_backoff(max_retries=4, base_delay=1.0)
    """
    def decorator(func):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            last_exc = None
            for attempt in range(1, max_retries + 2):   # +1 for final attempt
                try:
                    result = func(*args, **kwargs)
                    if attempt > 1:
                        print(f"Attempt {attempt} succeeded.")
                    return result

                except requests.exceptions.HTTPError as exc:
                    status = exc.response.status_code if exc.response is not None else 0
                    if status not in RETRIABLE_STATUS or attempt > max_retries:
                        raise   # non-retriable or exhausted retries

                    wait = base_delay * (2 ** (attempt - 1)) + random.uniform(0, 1)
                    print(f"Attempt {attempt} failed: {status} — waiting {wait:.1f}s before retry")
                    last_exc = exc
                    time.sleep(wait)

                except requests.exceptions.ConnectionError as exc:
                    if attempt > max_retries:
                        raise
                    wait = base_delay * (2 ** (attempt - 1)) + random.uniform(0, 1)
                    print(f"Attempt {attempt} failed: ConnectionError — waiting {wait:.1f}s")
                    last_exc = exc
                    time.sleep(wait)

            raise last_exc  # should not reach here

        return wrapper
    return decorator


# ── Usage ─────────────────────────────────────────────────────────────────────

@retry_with_backoff(max_retries=5, base_delay=0.5)
def call_flaky(base_url: str) -> dict:
    resp = requests.get(f"{base_url}/flaky", timeout=5)
    resp.raise_for_status()   # raises HTTPError on 4xx/5xx
    return resp.json()


# ── Standalone helper (no decorator) ─────────────────────────────────────────

def get_with_retry(url: str, max_retries: int = 4, base_delay: float = 1.0) -> dict:
    """Inline retry loop — use when you can't decorate."""
    for attempt in range(1, max_retries + 2):
        try:
            resp = requests.get(url, timeout=5)
            resp.raise_for_status()
            return resp.json()
        except requests.exceptions.HTTPError as exc:
            status = exc.response.status_code
            if status not in RETRIABLE_STATUS or attempt > max_retries:
                raise
            wait = base_delay * (2 ** (attempt - 1)) + random.uniform(0, 1)
            print(f"[standalone] Attempt {attempt} → {status}, retry in {wait:.1f}s")
            time.sleep(wait)
    raise RuntimeError("Exhausted retries")   # unreachable but satisfies type checkers


def main():
    base_url = "http://localhost:8080"

    print("=== @retry_with_backoff decorator ===")
    try:
        result = call_flaky(base_url)
        print(f"Result: {result}")
    except Exception as e:
        print(f"All retries exhausted: {e}")

    # ── Bonus: tenacity (pip install tenacity) ────────────────────────────────
    # from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type
    #
    # @retry(
    #     stop=stop_after_attempt(5),
    #     wait=wait_exponential(multiplier=1, min=1, max=30),
    #     retry=retry_if_exception_type(requests.exceptions.HTTPError),
    # )
    # def call_flaky_tenacity(base_url):
    #     resp = requests.get(f"{base_url}/flaky")
    #     resp.raise_for_status()
    #     return resp.json()


if __name__ == "__main__":
    main()
