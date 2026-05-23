# Problem 02 — Poll a Job Until Completion

## Scenario

You submit a long-running GPU training job via the API. The job runs asynchronously —
you must poll for its status until it finishes (or fails).

## Task

Write `submit_and_wait(base_url: str, poll_interval: float = 1.0) -> dict` that:

1. `POST /jobs` to create a job → get back `{"job_id": "abc123", "status": "pending"}`
2. Poll `GET /jobs/{job_id}` every `poll_interval` seconds
3. Stop when `status` is `"complete"` or `"failed"`
4. Print each status transition as it happens
5. Return the final job dict (including `result`)

## Status transitions

```
pending → running → complete
                  → failed
```

## Expected output

```
[0.0s] Submitted job abc123
[1.5s] pending → running
[4.2s] running → complete
Result: {'output': 'processed-abc123', 'rows': 4231}
```

## Bonus

Add a `timeout` parameter — raise `TimeoutError` if the job doesn't finish within N seconds.
