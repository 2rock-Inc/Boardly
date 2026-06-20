# Boardly — Project Brief for Claude Code

## Context
**Boardly** is a native iOS client (SwiftUI) for **PLANKA**, the open source /
self-hosted collaborative kanban app (https://github.com/plankanban/planka).
The app must work with **any self-hosted PLANKA instance** belonging to any
user — this is not an app for a single personal instance. Boardly has no
backend of its own: the app talks directly over REST to the user's PLANKA
instance.

Reference API spec (OpenAPI 3.0): `https://plankanban.github.io/planka/swagger-ui/swagger.json`
→ Download it and commit it to the repo under `Reference/planka-openapi.json`
(source of truth for the models — do not infer them from the Postman docs).

## Repo
**Mono-repo** named `boardly`, containing both the API client module and the
SwiftUI app:

```
boardly/
├── Package.swift          # declares the BoardlyKit module
├── Sources/
│   └── BoardlyKit/         # PLANKA API client (models + networking + auth)
├── Boardly.xcodeproj       # SwiftUI app, depends on BoardlyKit locally
├── Boardly/                # app code (Views, etc.)
├── Reference/
│   └── planka-openapi.json
└── CLAUDE.md
```

## Module architecture
1. **`BoardlyKit`** (Swift module, under `Sources/`)
   - PLANKA API client: `Codable` models, networking layer, token management
   - Must be testable and usable independently of the UI
   - No third-party networking dependency: `URLSession` + `async/await`

2. **`Boardly`** (SwiftUI app target)
   - Consumes `BoardlyKit` as a local dependency (same repo)
   - No business logic directly inside Views

## Tech stack
- Recent Swift (6.x), SwiftUI
- `URLSession` + `async/await`, no Alamofire
- Token storage: **Keychain** (never `UserDefaults`)
- No CloudKit (unlike CyberScan) — this is a genuine third-party REST API
- No Socket.IO / real-time in V1 (see Out of scope)

## Authentication
- Primary login: `POST /access-tokens` (`emailOrUsername` + `password`) → JWT
- Store the JWT in Keychain, **scoped per server profile** (see multi-instance)
- Handle the 401 case (expired token) → route back to that profile's login
- OIDC/SSO: out of scope for V1

## Core requirement: multi-instance (not a V2 option)
Since the app targets every self-hosted PLANKA user, from V1 onward:
- **Onboarding screen**: the user enters their server URL
  - Validate that the instance responds before offering login (don't blindly
    assume `/api` — PLANKA supports subpath hosting since v2.1)
- **Multiple stored server profiles**, with a profile switcher (a single user
  may have a personal PLANKA, a club/association PLANKA, etc.)
- **Self-signed certificates / private networks**: do not disable ATS
  globally. Provide an explicit "trust this certificate" flow with a visible
  warning to the user, not a silent bypass.

## V1 functional scope (minimal — do not over-build)
- Onboarding: add/select server profile + login
- List of projects → boards (`GET /projects`, `GET /boards/{id}`)
- Display lists and cards of a board (from the `included` payload returned
  by `GET /boards/{id}` — don't make one call per card)
- Create a card within a list, edit it (name, description, dueDate, move
  between lists via `listId`)
- View/create a task within a card's task list, toggle completion
  (`PATCH` on `isCompleted`)
- Manual pull-to-refresh to resync
- Logout / remove a profile

## Explicitly out of scope for V1 (to avoid over-building)
- Real-time sync via Socket.IO/WebSocket
- Custom fields, labels, attachments, comments, notifications
- OIDC/SSO login
- Trello import
- Admin endpoints (Config, Webhooks, Background Images)

## Expected deliverables
- `Package.swift` declaring `BoardlyKit` with models aligned to the OpenAPI
  schemas (`Board`, `List`, `Card`, `Task`, `TaskList`, `User`, `Project`...)
- Centralized error handling on PLANKA's standardized error codes
  (`E_UNAUTHORIZED`, `E_FORBIDDEN`, `E_NOT_FOUND`, `E_CONFLICT`,
  `E_MISSING_OR_INVALID_PARAMS`)
- Unit tests for the API client (mockable URLSession)
- `Boardly.xcodeproj` referencing `BoardlyKit` locally
- A `CLAUDE.md` at the repo root documenting Git branch conventions, the
  SwiftUI state patterns in use, and architecture rules (same spirit as the
  one already in place on CyberScan)

## First task for Claude Code
Set up the repo structure above (`Sources/BoardlyKit`, the initial
`Package.swift`, an empty `Boardly` Xcode project wired to the module),
download and commit the reference OpenAPI spec, then propose the `Codable`
models for `Board`, `List`, `Card`, `Task`, and `TaskList` before starting on
the networking layer.
