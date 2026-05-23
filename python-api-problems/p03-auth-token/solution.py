#!/usr/bin/env python3
"""
p03 — Authenticate and Make Authorized Requests  [SOLUTION]

Key points:
  - Never hardcode tokens — always authenticate programmatically
  - requests.Session lets you set headers once and reuse for all calls
  - Distinguish 401 (bad credentials) from 403 (forbidden) from 500 (server error)
"""

import requests


def authenticate(base_url: str, username: str, password: str) -> str:
    """POST /auth → returns Bearer token string."""
    resp = requests.post(
        f"{base_url}/auth",
        json={"username": username, "password": password},
        timeout=5,
    )
    if resp.status_code == 401:
        raise ValueError(f"Authentication failed for user '{username}': invalid credentials")
    resp.raise_for_status()
    return resp.json()["token"]


def get_profile(base_url: str, token: str) -> dict:
    """GET /user/profile with Bearer token → profile dict."""
    resp = requests.get(
        f"{base_url}/user/profile",
        headers={"Authorization": f"Bearer {token}"},
        timeout=5,
    )
    if resp.status_code == 401:
        raise PermissionError("Token is invalid or expired")
    resp.raise_for_status()
    return resp.json()


# ── Bonus: Session-based approach ─────────────────────────────────────────────

class APIClient:
    """Authenticated client — token is attached to all requests automatically."""

    def __init__(self, base_url: str) -> None:
        self.base_url = base_url.rstrip("/")
        self._session = requests.Session()

    def login(self, username: str, password: str) -> "APIClient":
        token = authenticate(self.base_url, username, password)
        self._session.headers.update({"Authorization": f"Bearer {token}"})
        return self

    def get(self, path: str, **kwargs) -> requests.Response:
        return self._session.get(f"{self.base_url}{path}", timeout=5, **kwargs)

    def post(self, path: str, **kwargs) -> requests.Response:
        return self._session.post(f"{self.base_url}{path}", timeout=5, **kwargs)

    def profile(self) -> dict:
        resp = self.get("/user/profile")
        resp.raise_for_status()
        return resp.json()


def main():
    base_url = "http://localhost:8080"

    # ── Simple approach ──────────────────────────────────────────────────────
    print("=== Simple approach ===")
    try:
        token = authenticate(base_url, "admin", "admin123")
        print(f"Token    : {token[:16]}...")   # never print full token in prod
        profile = get_profile(base_url, token)
        print(f"Username : {profile['username']}")
        print(f"Role     : {profile['role']}")
        print(f"Email    : {profile['email']}")
    except ValueError as e:
        print(f"Auth error: {e}")

    print()

    # ── Wrong credentials ────────────────────────────────────────────────────
    print("=== Wrong credentials ===")
    try:
        authenticate(base_url, "admin", "wrongpassword")
    except ValueError as e:
        print(f"Expected error: {e}")

    print()

    # ── Session-based approach ────────────────────────────────────────────────
    print("=== Session-based (APIClient) ===")
    client = APIClient(base_url).login("user", "userpass")
    p = client.profile()
    print(f"Username : {p['username']}")
    print(f"Role     : {p['role']}")


if __name__ == "__main__":
    main()
