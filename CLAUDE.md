# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

**Boardly** is a native iOS SwiftUI client for any self-hosted [PLANKA](https://github.com/plankanban/planka) instance. It has no backend of its own — the app talks directly to the user's PLANKA server over REST. It must support multiple server profiles (one user, many PLANKA instances).

The canonical API reference is `Reference/planka-openapi.json` (OpenAPI 3.0). **Always derive models from this file**, not from Postman docs or guesswork.

---

## Commands

```bash
# Build the BoardlyKit SPM module
swift build

# Run unit tests (BoardlyKit only — no Xcode needed)
swift test

# Run a single test
swift test --filter BoardlyKitTests.<TestSuiteName>/<testMethodName>

# Build the Xcode app (simulator)
xcodebuild -project Boardly.xcodeproj -scheme Boardly -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run app tests via Xcode
xcodebuild -project Boardly.xcodeproj -scheme Boardly -destination 'platform=iOS Simulator,name=iPhone 16' test

# Format (auto-runs as a post-edit hook)
swiftformat .
```

---

## Repo layout

```
boardly/
├── Package.swift              # SPM manifest — declares BoardlyKit
├── Sources/BoardlyKit/        # PLANKA API client: models, networking, auth
├── Tests/BoardlyKitTests/     # unit tests for BoardlyKit
├── Boardly.xcodeproj          # SwiftUI app, depends on BoardlyKit locally
├── Boardly/                   # app source (Views, ViewModels, Resources)
└── Reference/planka-openapi.json
```

---

## Architecture rules

### BoardlyKit (SPM module)
- Pure Swift — no UIKit, no SwiftUI, no third-party dependencies
- Networking: `URLSession` + `async/await` only (no Alamofire)
- Token storage: **Keychain only** — never `UserDefaults`
- Tokens are scoped per server profile (keyed by the base URL or a stable profile ID)
- Tests must be possible via a mockable `URLSession` protocol; no real network in tests

### Boardly (SwiftUI app)
- Views hold **no business logic** — all logic lives in `@Observable` view models or BoardlyKit
- State pattern: **MV (Model-View)** — `@Observable` view models injected explicitly, no singletons passed through the environment unless it is a top-level app-wide store (e.g. `ProfileStore`)
- Navigation: `NavigationStack` with a path-based router; no sheet-only navigation for primary flows
- Multi-instance from day one: every API call goes through a `PlankaClient` instance bound to a specific server profile, never a global client

### Data flow
- `GET /boards/{id}` returns an `included` sideloaded payload — parse lists, cards, and tasks from there; **never** make one network call per card/task
- Pull-to-refresh is the only sync mechanism in V1 (no WebSocket / Socket.IO)

---

## Authentication

- Login: `POST /access-tokens` with `emailOrUsername` + `password` → JWT
- Store JWT in Keychain keyed to the profile's base URL
- On 401: clear the stored token and route back to that profile's login screen
- PLANKA supports subpath hosting (e.g. `https://example.com/planka`), so the base URL is user-supplied — validate the instance responds before showing the login form
- Self-signed certificates: surface an explicit "trust this certificate" warning UI; **do not disable ATS globally or silently bypass TLS errors**

---

## PLANKA error codes

PLANKA returns structured errors. Map these centrally in `BoardlyKit`:

| Code | Meaning |
|------|---------|
| `E_UNAUTHORIZED` | 401 — token expired or missing |
| `E_FORBIDDEN` | 403 — insufficient permissions |
| `E_NOT_FOUND` | 404 |
| `E_CONFLICT` | 409 |
| `E_MISSING_OR_INVALID_PARAMS` | 422 |

---

## V1 scope

**In scope:**
- Add / select server profile, login, logout, remove profile
- Projects → boards list (`GET /projects`, board list from project payload)
- Board detail: lists and cards from `GET /boards/{id}` `included` payload
- Create card, edit card (name, description, dueDate, move between lists via `listId`)
- View / create tasks inside a card's task list; toggle `isCompleted`
- Pull-to-refresh

**Explicitly out of scope — do not implement:**
- Real-time sync (Socket.IO / WebSocket)
- Labels, attachments, comments, custom fields, notifications
- OIDC / SSO
- Trello import
- Admin endpoints (webhooks, background images, config)

---

## Git branch conventions

- `main` — always releasable; no direct commits for features
- `feat/<short-slug>` — new features
- `fix/<short-slug>` — bug fixes
- `chore/<short-slug>` — tooling, CI, non-functional changes

PRs require a passing `swift test` run. Squash-merge into `main`.
