#!/usr/bin/env python3
"""
p02 — Poll a Job Until Completion  [SOLUTION]

Key points:
  - Track previous status to log transitions (not every poll tick)
  - monotonic() for timing (wall clock drifts)
  - Raise TimeoutError rather than looping forever — never block a support script
  - Handle transient network errors without giving up immediately
"""

import time
import requests


TERMINAL_STATUSES = {"complete", "failed"}


def submit_and_wait(
    base_url: str,
    poll_interval: float = 1.0,
    timeout: float | None = 30.0,
) -> dict:
    start = time.monotonic()

    # ── Step 1: submit ────────────────────────────────────────────────────────
    resp = requests.post(f"{base_url}/jobs", timeout=5)
    resp.raise_for_status()
    job = resp.json()
    job_id = job["job_id"]
    elapsed = time.monotonic() - start
    print(f"[{elapsed:.1f}s] Submitted job {job_id}")

    # ── Step 2: poll ──────────────────────────────────────────────────────────
    prev_status = job["status"]

    while True:
        time.sleep(poll_interval)
        elapsed = time.monotonic() - start

        # Timeout guard
        if timeout is not None and elapsed > timeout:
            raise TimeoutError(
                f"Job {job_id} did not finish within {timeout}s "
                f"(last status: {prev_status})"
            )

        try:
            resp = requests.get(f"{base_url}/jobs/{job_id}", timeout=5)
            resp.raise_for_status()
        except requests.exceptions.RequestException as e:
            # Transient network error — log and keep polling
            print(f"[{elapsed:.1f}s] Poll error (retrying): {e}")
            continue

        job = resp.json()
        status = job["status"]

        # Log only on status change
        if status != prev_status:
            print(f"[{elapsed:.1f}s] {prev_status} → {status}")
            prev_status = status

        if status in TERMINAL_STATUSES:
            return job


def main():
    base_url = "http://localhost:8080"
    print("Starting job submission...\n")

    try:
        result = submit_and_wait(base_url, poll_interval=0.5, timeout=30.0)
    except TimeoutError as e:
        print(f"TIMEOUT: {e}")
        return

    print()
    if result["status"] == "complete":
        print(f"✓ Job complete. Result: {result['result']}")
    else:
        print(f"✗ Job failed. Error: {result.get('result')}")


if __name__ == "__main__":
    main()
