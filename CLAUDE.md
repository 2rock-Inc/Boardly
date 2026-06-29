# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

**Boardly** is a native iOS SwiftUI client for any self-hosted [PLANKA](https://github.com/plankanban/planka) instance. It has no backend of its own — the app talks directly to the user's PLANKA server over REST (and Socket.IO for real-time updates). It must support multiple server profiles (one user, many PLANKA instances).

The canonical API reference is `Reference/planka-openapi.json` (OpenAPI 3.0). **Always derive models from this file**, not from Postman docs or guesswork.

The work is split into 5 phases — see `ROADMAP.md` for the execution plan and the suggested kickoff prompt for each phase.

---

## Commands

```bash
# Build the BoardlyKit SPM module
swift build

# Run unit tests (BoardlyKit only — no Xcode needed)
swift test

# Run a single test
swift test --filter BoardlyKitTests./

# Build the Xcode app (simulator)
xcodebuild -project Boardly/Boardly.xcodeproj -scheme Boardly -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run app tests via Xcode
xcodebuild -project Boardly/Boardly.xcodeproj -scheme Boardly -destination 'platform=iOS Simulator,name=iPhone 16' test

# Format (auto-runs as a post-edit hook)
swiftformat .
```

---

## Repo layout

```
boardly/
├── Package.swift              # SPM manifest — declares BoardlyKit  [Phase 1]
├── Sources/BoardlyKit/        # PLANKA API client: models, networking, auth, real-time  [Phase 1]
├── Tests/BoardlyKitTests/     # unit tests for BoardlyKit  [Phase 1]
├── Reference/planka-openapi.json  # canonical API spec  [Phase 1]
└── Boardly/                   # Xcode project folder (already exists)
    ├── Boardly.xcodeproj      # SwiftUI app, will depend on BoardlyKit locally
    └── Boardly/               # app source (Views, ViewModels, Resources)
```

Items marked `[Phase 1]` do not exist yet — they are created in the first implementation phase.

---

## Architecture rules

### BoardlyKit (SPM module)
- Pure Swift — no UIKit, no SwiftUI
- REST networking: `URLSession` + `async/await` only (no Alamofire)
- Real-time: a Socket.IO client library is the **one allowed third-party dependency**, scoped strictly to the real-time sync layer — do not introduce other third-party dependencies for REST, auth, or models
- Token storage: **Keychain only** — never `UserDefaults`
- Tokens are scoped per server profile (keyed by the base URL or a stable profile ID)
- Tests must be possible via a mockable `URLSession` protocol; no real network in tests

### Boardly (SwiftUI app)
- Views hold **no business logic** — all logic lives in `@Observable` view models or BoardlyKit
- State pattern: **MV (Model-View)** — `@Observable` view models injected explicitly, no singletons passed through the environment unless it is a top-level app-wide store (e.g. `ProfileStore`)
- Navigation: `NavigationStack` with a path-based router; no sheet-only navigation for primary flows
- Multi-instance from day one: every API call (REST and Socket.IO) goes through a `PlankaClient` instance bound to a specific server profile, never a global client

### Data flow
- `GET /boards/{id}` returns an `included` sideloaded payload — parse lists, cards, and tasks from there; **never** make one network call per card/task
- Real-time: subscribe to the board's Socket.IO event stream while it is open to keep lists/cards/tasks in sync live; pull-to-refresh remains as a manual fallback/recovery mechanism (e.g. after reconnecting)
- The Socket.IO connection is per server profile and must be torn down when leaving a board or switching profiles — never kept alive across profiles

---

## Logging

Use `BoardlyLog` (in `BoardlyKit`) for all diagnostic output. Never use `print`, `NSLog`, or raw `os_log` directly.

```swift
BoardlyLog.tag(.network).icon("📡").info("Request started", metadata: ["url": url])
BoardlyLog.tag(.auth).warning("Token expiring soon")
BoardlyLog.tag(.network).icon("⚠️").error("Request failed", error: error, metadata: ["url": url])
```

**Redaction rule (non-negotiable):** Any metadata value that could be a token, password, or API key must be wrapped in `Redacted(...)`. The wrapper discards the real value at init and emits `"<redacted>"` — making it structurally impossible for a secret to reach the log sink in plaintext.

```swift
// Correct
BoardlyLog.tag(.auth).info("Logged in", metadata: ["token": Redacted(jwt)])

// Never do this — caught by security-patterns.yaml
print("token: \(jwt)")
```

Available tags: `.auth` `.network` `.profile` `.sync` `.board` `.ui`

In tests, swap `BoardlyLog.sink` for a `TestLogSink` (defined in `BoardlyLogTests.swift`) to capture log entries without writing to `os_log`. Restore the previous sink in `tearDown`.

---

## Authentication

- Login: `POST /access-tokens` with `emailOrUsername` + `password` → JWT, **or** via OIDC/SSO using `POST /access-tokens/exchange-with-oidc`
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
- Add / select server profile, login (password or OIDC/SSO), logout, remove profile
- Projects → boards list (`GET /projects`, board list from project payload)
- Board detail: lists and cards from `GET /boards/{id}` `included` payload
- Real-time sync of boards/lists/cards/tasks via Socket.IO, with pull-to-refresh as fallback
- Create card, edit card (name, description, dueDate, move between lists via `listId`)
- View / create tasks inside a card's task list; toggle `isCompleted`
- Labels: create, assign, and remove labels on cards
- Attachments: add and view attachments (file or link) on cards
- Comments: add and view comments on cards
- Custom fields: create/manage custom field groups and fields, set values on cards
- Notifications: view in-app notifications, mark as read; manage notification services
- Board backgrounds: set/change a board's background image
- Admin config: webhooks management and instance config (SMTP, etc.) where the authenticated user has admin rights

**Explicitly out of scope — do not implement:**
- Trello import

---

## Git workflow

### Branches
- `main` — always releasable; no direct commits for features
- `feat/<short-slug>` — new features
- `fix/<short-slug>` — bug fixes
- `chore/<short-slug>` — tooling, CI, non-functional changes

### Commit messages
Format: `<emoji> <type>(<scope>): <imperative message>`

| Type | Emoji |
|------|-------|
| feat | ✨ |
| fix | 🐛 |
| docs | 📝 |
| refactor | ♻️ |
| style | 🎨 |
| test | ✅ |
| chore | 🧑‍💻 |
| wip | 🚧 |

Example: `✨ feat(auth): add OIDC token exchange flow`

PRs require a passing `swift test` run. Squash-merge into `main`.