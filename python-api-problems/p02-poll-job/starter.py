#!/usr/bin/env python3
"""p02 — Poll a Job Until Completion"""

import time
import requests


def submit_and_wait(
    base_url: str,
    poll_interval: float = 1.0,
    timeout: float | None = 30.0,
) -> dict:
    """
    POST /jobs to create a job, then poll GET /jobs/{job_id} until done.
    """
    start = time.monotonic()

    # TODO: POST /jobs, extract job_id from response
    job_id = None

    prev_status = None

    while True:
        # TODO: GET /jobs/{job_id}, check status
        # Print transitions
        # Return final dict when status is "complete" or "failed"

        # TODO: check timeout

        time.sleep(poll_interval)


if __name__ == "__main__":
    result = submit_and_wait("http://localhost:8080")
    print("Final result:", result.get("result"))
