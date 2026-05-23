# Problem 03 — Authenticate and Make Authorized Requests

## Scenario

CoreWeave's management API requires a Bearer token. You must authenticate first,
then use the token for all subsequent calls.

## Task

Write two functions:

### `authenticate(base_url, username, password) -> str`
- POST to `{base_url}/auth` with JSON body `{"username": ..., "password": ...}`
- Parse response: `{"token": "...", "expires_in": 3600, ...}`
- Return the token string
- Raise `ValueError` if credentials are wrong (401 response)

### `get_profile(base_url, token) -> dict`
- GET `{base_url}/user/profile`
- Set header: `Authorization: Bearer {token}`
- Return the parsed profile dict

## Credentials (for testing)

| username | password   |
|----------|-----------|
| `admin`  | `admin123` |
| `user`   | `userpass` |

## Bonus: `requests.Session`

Refactor to use a `requests.Session` so the token is attached to all requests
automatically via `session.headers.update({"Authorization": f"Bearer {token}"})`.

## Expected output

```
Token    : AbCdEfGhIjKlMnOpQrStUvWxYzAb1234
Username : admin
Role     : admin
Email    : admin@coreweave.com
```
