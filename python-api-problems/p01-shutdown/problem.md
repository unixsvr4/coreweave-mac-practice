# Problem 01 — Shutdown the Server

## Scenario

You are a support engineer at CoreWeave. A customer's inference server is in an unrecoverable state and needs a clean shutdown via its management API.

## Task

Write a function `shutdown_server(base_url: str) -> dict` that:

1. Sends a `POST` request to `{base_url}/shutdown`
2. Parses the JSON response body
3. Returns the parsed dict
4. **Handles the edge case** where the server closes the connection before sending
   a complete response — treat this as a successful shutdown and return
   `{"status": "shutdown_complete", "message": "Connection closed by server"}`

## Expected server response (when it arrives)

```json
{
  "status": "ok",
  "message": "Server is shutting down",
  "timestamp": 1716000000.0
}
```

## Requirements

- Print the status and message to stdout
- Exit cleanly whether the server responds or drops the connection
- Do **not** crash on `ConnectionError` / `RemoteDisconnected`

## Run

```bash
# Terminal 1:
python server/server.py

# Terminal 2:
python p01-shutdown/starter.py
```

## Hint

`requests` raises `requests.exceptions.ConnectionError` when the server closes
mid-response. Catch it and treat it as success.
