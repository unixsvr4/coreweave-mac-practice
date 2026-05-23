# Python API Problems

Practical Python scripting problems focused on HTTP API interaction — the kind of
thing you'd write as a support engineer automating tasks against a cloud API.

## Setup

No external dependencies — uses stdlib `http.client`, `urllib`, or `requests` (your choice).

```bash
# Optional: install requests (makes it easier)
pip install requests

# Start the practice server (keep this running in one terminal)
python server/server.py

# In another terminal: work on problems
python p01-shutdown/solution.py
```

## Problems

| Problem | Skill | Core concept |
|---------|-------|-------------|
| [p01 — Shutdown](p01-shutdown/) | API call + JSON parse | `requests.post`, handle connection drop |
| [p02 — Poll Job](p02-poll-job/) | Async job polling | Loop with sleep, parse status transitions |
| [p03 — Auth Token](p03-auth-token/) | Authentication | POST for token, Bearer header, session |
| [p04 — Pagination](p04-pagination/) | Iterate pages | `while has_next`, accumulate results |
| [p05 — Retry Backoff](p05-retry-backoff/) | Resilience | Exponential backoff, retry decorator |

## Server Endpoints (quick reference)

```
POST http://localhost:8080/shutdown
POST http://localhost:8080/jobs
GET  http://localhost:8080/jobs/<job_id>
POST http://localhost:8080/auth          body: {"username":"admin","password":"admin123"}
GET  http://localhost:8080/user/profile  header: Authorization: Bearer <token>
GET  http://localhost:8080/items?page=1&limit=10
GET  http://localhost:8080/flaky
GET  http://localhost:8080/health
```

## Study approach

For each problem:
1. Read the problem statement (`problem.md`)
2. Write your solution in `starter.py` **without** looking at `solution.py`
3. Test against the live server
4. Read `solution.py` and compare approaches
