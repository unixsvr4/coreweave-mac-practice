#!/usr/bin/env python3
"""
Practice API Server — zero external dependencies (stdlib only).

Endpoints:
  POST /shutdown                    -> {"status":"ok","message":"Server is shutting down"}
  POST /jobs                        -> {"job_id":"abc123","status":"pending"}
  GET  /jobs/<job_id>               -> {"job_id":"...","status":"pending|running|complete|failed","result":...}
  POST /auth                        -> {"token":"...","expires_in":3600}
  GET  /user/profile  (Bearer)      -> {"id":1,"username":"...","role":"admin"}
  GET  /items?page=N&limit=M        -> {"items":[...],"page":N,"total_pages":M,"total_items":X}
  GET  /flaky                       -> 200 or 500/503 randomly (for retry exercise)

Usage:
  python server/server.py              # port 8080
  python server/server.py 9000         # custom port
"""

import json
import sys
import threading
import time
import random
import uuid
import string
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs


# ── In-memory state ───────────────────────────────────────────────────────────
JOBS: dict[str, dict] = {}          # job_id → {status, result, created_at}
TOKENS: dict[str, str] = {}         # token → username
FLAKY_CALL_COUNT = [0]              # mutable counter for flaky endpoint

ITEMS = [
    {"id": i, "name": f"item-{i}", "category": random.choice(["gpu", "storage", "network"])}
    for i in range(1, 53)           # 52 items across pages
]


def _json_response(handler, code: int, payload: dict) -> None:
    body = json.dumps(payload, indent=2).encode()
    handler.send_response(code)
    handler.send_header("Content-Type", "application/json")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)


def _extract_token(handler) -> str | None:
    auth = handler.headers.get("Authorization", "")
    if auth.startswith("Bearer "):
        return auth[7:].strip()
    return None


def _require_auth(handler) -> str | None:
    """Returns username if authenticated, else sends 401 and returns None."""
    token = _extract_token(handler)
    if not token or token not in TOKENS:
        _json_response(handler, 401, {"error": "Unauthorized", "message": "Missing or invalid Bearer token"})
        return None
    return TOKENS[token]


class APIHandler(BaseHTTPRequestHandler):

    def log_message(self, fmt, *args):
        pass  # suppress default per-request stdout noise

    def _read_body(self) -> dict:
        length = int(self.headers.get("Content-Length", 0))
        if length == 0:
            return {}
        raw = self.rfile.read(length)
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            return {}

    # ── POST ──────────────────────────────────────────────────────────────────
    def do_POST(self):
        path = urlparse(self.path).path

        # POST /shutdown
        if path == "/shutdown":
            print("[server] Received /shutdown — sending response then stopping.")
            _json_response(self, 200, {
                "status": "ok",
                "message": "Server is shutting down",
                "timestamp": time.time(),
            })
            self.wfile.flush()
            threading.Thread(target=self.server.shutdown, daemon=True).start()
            return

        # POST /jobs  → create a job
        if path == "/jobs":
            job_id = uuid.uuid4().hex[:8]
            JOBS[job_id] = {
                "job_id": job_id,
                "status": "pending",
                "result": None,
                "created_at": time.time(),
            }
            # Simulate job progression in background
            def _run_job(jid):
                time.sleep(1.5)
                JOBS[jid]["status"] = "running"
                # 20% chance of failure
                outcome = "failed" if random.random() < 0.2 else "complete"
                time.sleep(random.uniform(2, 5))
                JOBS[jid]["status"] = outcome
                if outcome == "complete":
                    JOBS[jid]["result"] = {"output": f"processed-{jid}", "rows": random.randint(100, 9999)}
                else:
                    JOBS[jid]["result"] = {"error": "GPU OOM during processing"}
            threading.Thread(target=_run_job, args=(job_id,), daemon=True).start()
            _json_response(self, 202, JOBS[job_id])
            return

        # POST /auth  → authenticate
        if path == "/auth":
            body = self._read_body()
            username = body.get("username", "")
            password = body.get("password", "")
            # Accept: admin/admin123 or user/userpass
            valid = {"admin": "admin123", "user": "userpass"}
            if valid.get(username) == password:
                token = "".join(random.choices(string.ascii_letters + string.digits, k=32))
                TOKENS[token] = username
                _json_response(self, 200, {
                    "token": token,
                    "expires_in": 3600,
                    "token_type": "Bearer",
                    "username": username,
                })
            else:
                _json_response(self, 401, {"error": "Invalid credentials"})
            return

        _json_response(self, 404, {"error": "Not found", "path": path})

    # ── GET ───────────────────────────────────────────────────────────────────
    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        qs = parse_qs(parsed.query)

        # GET /health
        if path == "/health":
            _json_response(self, 200, {"status": "ok", "uptime": time.time()})
            return

        # GET /jobs/<job_id>
        if path.startswith("/jobs/"):
            job_id = path[6:]
            if job_id in JOBS:
                _json_response(self, 200, JOBS[job_id])
            else:
                _json_response(self, 404, {"error": "Job not found", "job_id": job_id})
            return

        # GET /user/profile  (requires auth)
        if path == "/user/profile":
            username = _require_auth(self)
            if username is None:
                return
            _json_response(self, 200, {
                "id": 1 if username == "admin" else 2,
                "username": username,
                "role": "admin" if username == "admin" else "viewer",
                "email": f"{username}@coreweave.com",
            })
            return

        # GET /items?page=N&limit=M
        if path == "/items":
            page = int(qs.get("page", ["1"])[0])
            limit = int(qs.get("limit", ["10"])[0])
            limit = max(1, min(limit, 50))   # clamp 1–50
            total = len(ITEMS)
            total_pages = (total + limit - 1) // limit
            page = max(1, min(page, total_pages))
            start = (page - 1) * limit
            end = start + limit
            _json_response(self, 200, {
                "items": ITEMS[start:end],
                "page": page,
                "limit": limit,
                "total_items": total,
                "total_pages": total_pages,
                "has_next": page < total_pages,
            })
            return

        # GET /flaky  → randomly fails (for retry exercise)
        if path == "/flaky":
            FLAKY_CALL_COUNT[0] += 1
            n = FLAKY_CALL_COUNT[0]
            # Fail first 3 calls, then succeed — deterministic for learning
            if n <= 3:
                code = random.choice([500, 503])
                _json_response(self, code, {
                    "error": "Service temporarily unavailable",
                    "attempt": n,
                    "retry_after": 2 ** n,
                })
            else:
                FLAKY_CALL_COUNT[0] = 0   # reset for next run
                _json_response(self, 200, {"data": "success", "attempt": n})
            return

        _json_response(self, 404, {"error": "Not found", "path": path})


def run(port: int = 8080) -> None:
    server = HTTPServer(("", port), APIHandler)
    print(f"Practice API server running on http://localhost:{port}")
    print("Endpoints:")
    print("  POST /shutdown     — p01")
    print("  POST /jobs         — p02")
    print("  GET  /jobs/<id>    — p02")
    print("  POST /auth         — p03")
    print("  GET  /user/profile — p03")
    print("  GET  /items        — p04")
    print("  GET  /flaky        — p05")
    print("")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[server] Stopped by keyboard interrupt.")


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    run(port)
