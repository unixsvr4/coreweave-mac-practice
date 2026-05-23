# Problem 04 — Fetch All Pages

## Scenario

You need to audit all GPU resources in a customer's namespace. The inventory API
is paginated — each response returns one page and tells you if there's a next page.

## Task

Write `fetch_all_items(base_url, limit=10) -> list[dict]` that:

1. GET `{base_url}/items?page=1&limit={limit}`
2. Parse the response:
   ```json
   {
     "items": [...],
     "page": 1,
     "limit": 10,
     "total_items": 52,
     "total_pages": 6,
     "has_next": true
   }
   ```
3. Keep fetching until `has_next` is `false`
4. Return a flat list of **all** items across all pages

## Expected output (52 items total, limit=10 → 6 pages)

```
Fetching page 1... got 10 items
Fetching page 2... got 10 items
...
Fetching page 6... got 2 items
Total items fetched: 52
First item: {'id': 1, 'name': 'item-1', 'category': 'gpu'}
```

## Bonus

Filter by category — add a `category` parameter and return only matching items.
