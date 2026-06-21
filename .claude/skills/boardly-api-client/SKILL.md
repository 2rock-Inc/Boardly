---
name: boardly-api-client
description: Use this skill when writing or reviewing code in BoardlyKit that talks to a PLANKA server (models, networking, auth, error mapping). Covers REST conventions, multi-instance handling, and the PLANKA error code mapping.
---

# Boardly API Client Conventions

BoardlyKit is the only place that talks to a PLANKA server over HTTP. Follow
these conventions for any networking code.

## Networking
- `URLSession` + Swift `async/await` only. No third-party HTTP libraries.
- One client instance per **server profile** — never a single global client
  shared across multiple PLANKA instances.
- The base URL is user-provided and may include a subpath (PLANKA supports
  subpath hosting since v2.1). Never hardcode `/api` as the root; resolve it
  relative to the configured base URL.

## Models
- `Codable` structs matching `Reference/planka-openapi.json`. When the spec
  and observed server responses disagree, trust the spec first, then note
  the discrepancy rather than silently special-casing it.
- `GET /boards/{id}` returns a denormalized payload with an `included` block
  (lists, cards, users, labels, etc.). Decode this as a dedicated response
  type — don't force it into a flat `[Card]` array.

## Error handling
Map PLANKA's standardized error codes to a single error enum:
- `E_UNAUTHORIZED` -> token invalid/expired, trigger re-login for that profile
- `E_FORBIDDEN` -> insufficient permissions, surface a clear message
- `E_NOT_FOUND` -> resource deleted/moved, refresh local state
- `E_CONFLICT` -> optimistic update collided, refetch and retry
- `E_MISSING_OR_INVALID_PARAMS` -> client-side bug, log with request context
  (never log the auth header)

## Multi-instance
- Every request must be scoped to an explicit server profile (URL + token).
  There is no implicit "current server" global state.
- Switching profiles must not leak cached data (lists, cards, images) from
  one profile into another.
