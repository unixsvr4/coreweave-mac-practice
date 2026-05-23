#!/usr/bin/env python3
"""
p01 — Shutdown the Server  [SOLUTION]

Key points:
  1. POST /shutdown returns JSON before the server dies
  2. Server might close connection before response arrives → ConnectionError
  3. Both outcomes are "success" from the caller's perspective
"""

import requests


def shutdown_server(base_url: str) -> dict:
    url = f"{base_url}/shutdown"
    try:
        response = requests.post(url, timeout=5)
        response.raise_for_status()   # raises HTTPError on 4xx/5xx
        return response.json()

    except requests.exceptions.ConnectionError:
        # Server shut down before sending (or finishing) the response.
        # This is a successful shutdown — the process is gone.
        return {
            "status": "shutdown_complete",
            "message": "Connection closed by server (shutdown successful)",
        }

    except requests.exceptions.Timeout:
        raise RuntimeError(f"Timed out connecting to {url}")

    except requests.exceptions.HTTPError as e:
        raise RuntimeError(f"Server returned error: {e.response.status_code}")


def main():
    base_url = "http://localhost:8080"
    print(f"Sending shutdown to {base_url}/shutdown ...")

    result = shutdown_server(base_url)

    print(f"Status  : {result['status']}")
    print(f"Message : {result.get('message', 'N/A')}")
    if "timestamp" in result:
        import datetime
        ts = datetime.datetime.fromtimestamp(result["timestamp"])
        print(f"Time    : {ts.strftime('%Y-%m-%d %H:%M:%S')}")


if __name__ == "__main__":
    main()


# ── Stdlib-only version (no requests) ────────────────────────────────────────
#
# import http.client, json
#
# def shutdown_server_stdlib(base_url: str) -> dict:
#     from urllib.parse import urlparse
#     parsed = urlparse(base_url)
#     conn = http.client.HTTPConnection(parsed.hostname, parsed.port or 80, timeout=5)
#     try:
#         conn.request("POST", "/shutdown")
#         resp = conn.getresponse()
#         body = resp.read()
#         return json.loads(body)
#     except (ConnectionResetError, http.client.RemoteDisconnected):
#         return {"status": "shutdown_complete", "message": "Connection reset by server"}
#     finally:
#         conn.close()
