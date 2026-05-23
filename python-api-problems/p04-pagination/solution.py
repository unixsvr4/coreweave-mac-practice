#!/usr/bin/env python3
"""
p04 — Fetch All Pages  [SOLUTION]

Key points:
  - Never assume you know the page count upfront — use has_next
  - Stop at total_pages as a safety guard against infinite loops
  - Generator variant is memory-efficient for large datasets
"""

import requests


def fetch_all_items(
    base_url: str,
    limit: int = 10,
    category: str | None = None,
) -> list[dict]:
    """Fetch every page from /items and return flat list of all items."""
    all_items: list[dict] = []
    page = 1

    while True:
        resp = requests.get(
            f"{base_url}/items",
            params={"page": page, "limit": limit},
            timeout=5,
        )
        resp.raise_for_status()
        data = resp.json()

        items = data["items"]
        print(f"Fetching page {page}/{data['total_pages']}... got {len(items)} items")
        all_items.extend(items)

        if not data["has_next"]:
            break

        page += 1

    if category:
        all_items = [i for i in all_items if i.get("category") == category]

    return all_items


# ── Generator variant (memory-efficient for huge datasets) ────────────────────

def iter_items(base_url: str, limit: int = 10):
    """Yield items one by one, fetching pages lazily."""
    page = 1
    while True:
        data = requests.get(
            f"{base_url}/items",
            params={"page": page, "limit": limit},
            timeout=5,
        ).json()
        yield from data["items"]
        if not data["has_next"]:
            return
        page += 1


def main():
    base_url = "http://localhost:8080"

    print("=== fetch_all_items (limit=10) ===")
    items = fetch_all_items(base_url, limit=10)
    print(f"Total items fetched: {len(items)}")
    print(f"First item: {items[0]}")
    print(f"Last item : {items[-1]}")

    print()
    print("=== filtered by category='gpu' ===")
    gpu_items = fetch_all_items(base_url, limit=10, category="gpu")
    print(f"GPU items: {len(gpu_items)}")

    print()
    print("=== generator variant ===")
    count = sum(1 for _ in iter_items(base_url, limit=15))
    print(f"Items via generator: {count}")


if __name__ == "__main__":
    main()
