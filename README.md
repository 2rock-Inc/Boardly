<!--
  Drop marketing assets into docs/ (create the folder if missing):
    docs/banner.png        — social preview / GitHub "Open Graph" image (1280×640)
    docs/welcome.png       — Welcome / login screen
    docs/projects.png      — Projects & boards list
    docs/kanban.png        — Board (kanban) screen
    docs/card.png          — Card detail screen
  Once added, the images below will render automatically.
-->

<div align="center">

<img src="docs/banner.png" alt="Boardly" width="720" />

# Boardly

### A native iOS client for any self-hosted PLANKA instance

Bring your kanban boards to iPhone — fast, native, and real-time. No middleman backend: Boardly talks straight to *your* PLANKA server.

<br />

[![Platform](https://img.shields.io/badge/platform-iOS%2026-000000?logo=apple&logoColor=white)](https://developer.apple.com/ios/)
[![Swift 6](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white)](https://www.swift.org/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-native-0A84FF?logo=swift&logoColor=white)](https://developer.apple.com/xcode/swiftui/)
[![Tests](https://img.shields.io/badge/tests-83%20passing-30A46C)](#-testing)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

</div>

---

## Overview

**Boardly** is a native SwiftUI client for [PLANKA](https://github.com/plankanban/planka), the open-source kanban board. It has **no backend of its own** — every request goes directly to the self-hosted PLANKA server you point it at, over REST and Socket.IO. One user, many servers: Boardly is **multi-instance from day one**, so you can juggle a work instance, a personal instance, and a client's instance side by side, each with its own credentials stored securely in the Keychain.

Models are derived from PLANKA's own OpenAPI specification (`Reference/planka-openapi.json`) rather than guesswork, and the whole networking core lives in a pure-Swift package (`BoardlyKit`) that is unit-tested independently of the UI.

---

## Screenshots

> _Screenshots live in `docs/` — add the PNGs listed at the top of this file to populate the table._

| Welcome | Projects | Kanban board | Card detail |
| :-----: | :------: | :----------: | :---------: |
| <img src="docs/welcome.png" width="200" alt="Welcome" /> | <img src="docs/projects.png" width="200" alt="Projects" /> | <img src="docs/kanban.png" width="200" alt="Kanban board" /> | <img src="docs/card.png" width="200" alt="Card detail" /> |

---

## Features

### 🔐 Servers & accounts
- Add, switch, and remove multiple PLANKA **server profiles**
- Base-URL validation (including **subpath hosting**, e.g. `https://example.com/planka`)
- Password login (`POST /access-tokens`); JWT stored in the **Keychain**, scoped per profile
- Automatic 401 handling — clears the token and routes back to that profile's login

### 🗂️ Boards, lists & cards
- Projects → boards navigation
- Board detail: lists and cards parsed from a single `GET /boards/{id}` `included` payload (no per-card fan-out)
- Create and edit cards — name, description, due date, and **move between lists**
- Tasks inside a card's task list, with `isCompleted` toggling
- Pull-to-refresh as a manual fallback

### ⚡ Real-time sync
- **Socket.IO** live updates for lists, cards, and tasks while a board is open
- Per-profile connection lifecycle — connects on board open, tears down on leave / profile switch
- Reconnection handling, with pull-to-refresh as recovery

### 🃏 Rich card content
- **Labels** — create, assign, and remove
- **Members** — assign and remove
- **Comments** — threaded, with an inline composer
- **Attachments** — file, photo (multipart upload), or link
- **Due dates** — calendar picker
- **Chrono** (stopwatch) and an **activity feed**

### 🎨 Design — "Pine Teal"
- Custom design system with **Manrope** + **JetBrains Mono** typefaces
- Semantic light / dark color tokens
- App icon authored with Icon Composer

### 🗺️ Planned (Phase 5)
- OIDC / SSO login (`POST /access-tokens/exchange-with-oidc`)
- In-app notifications & notification services
- Board backgrounds
- Custom fields on cards
- Admin config — webhooks and instance settings, gated on admin rights

---

## Tech stack & architecture

Boardly is split into a UI-free Swift package and the SwiftUI app that consumes it.

```
┌─────────────────────────────────────────────────────────────┐
│  Boardly  (SwiftUI app)                                      │
│  • Views hold no business logic                             │
│  • MV pattern — @Observable view models, explicit injection │
│  • Path-based NavigationStack router                        │
│  • "Pine Teal" design system                               │
└───────────────────────────────┬─────────────────────────────┘
                                 │ depends on (local SPM)
┌───────────────────────────────▼─────────────────────────────┐
│  BoardlyKit  (pure Swift, no UIKit / SwiftUI)               │
│  • Models .............. Codable, derived from OpenAPI spec │
│  • Networking .......... URLSession + async/await REST      │
│  • Auth ................ Keychain-only tokens, per profile  │
│  • Profiles ............ multi-instance ProfileStore        │
│  • Realtime ............ Socket.IO transport + reconcile    │
│  • Errors .............. central PlankaAPIError mapping     │
│  • Logging ............. BoardlyLog with Redacted() secrets │
└──────────────────────────────────────────────────────────────┘
                                 │ REST + Socket.IO
                                 ▼
                    Your self-hosted PLANKA server
```

**Key decisions**

- **OpenAPI-driven models** — the canonical source of truth is `Reference/planka-openapi.json`.
- **One allowed third-party dependency** — [socket.io-client-swift](https://github.com/socketio/socket.io-client-swift), scoped strictly to the real-time layer. REST, auth, and models use only the standard library.
- **Keychain-only** token storage, keyed per server profile — never `UserDefaults`.
- **Redacted logging** — any secret in log metadata is wrapped in `Redacted(...)`, making it structurally impossible for a token to reach the log sink in plaintext.
- **No global client** — every call runs through a `PlankaClient` bound to a specific profile.

---

## Getting started

### Prerequisites

- **Xcode 26** (Swift 6)
- iOS **26** deployment target / simulator
- A reachable **PLANKA instance** and an account on it (Boardly ships no server)

### Clone

```bash
git clone https://github.com/2rock-Inc/boardly.git
cd boardly
```

### Build & test the core package

`BoardlyKit` builds and tests without Xcode:

```bash
swift build          # build the BoardlyKit SPM module
swift test           # run the ~83 unit tests
```

### Run the app

Open the Xcode project, select an iPhone simulator, and run:

```bash
open Boardly/Boardly.xcodeproj
```

Or from the command line:

```bash
xcodebuild -project Boardly/Boardly.xcodeproj \
  -scheme Boardly \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build
```

On first launch, add a server profile pointing at your PLANKA base URL and log in.

---

## Project structure

```
boardly/
├── Package.swift                  # SPM manifest — declares BoardlyKit
├── Reference/
│   └── planka-openapi.json        # canonical PLANKA API spec (models derive from this)
├── Sources/BoardlyKit/            # pure-Swift PLANKA client
│   ├── Models/                    # Codable models (Board, Card, List, Task, Label, …)
│   ├── Payloads/                  # sideloaded payload decoding (BoardPayload, CardPatch, …)
│   ├── Networking/                # HTTPClient, PlankaClient, JSON decoding
│   ├── Auth/                      # Keychain store, TokenStore, JWT helpers
│   ├── Profiles/                  # ServerProfile, ProfileStore (multi-instance)
│   ├── Realtime/                  # Socket.IO transport, events, reconciliation
│   ├── Errors/                    # PlankaAPIError mapping
│   └── Logging/                   # BoardlyLog, LogTag, Redacted
├── Tests/BoardlyKitTests/         # unit tests + JSON fixtures
└── Boardly/
    ├── Boardly.xcodeproj          # SwiftUI app (depends on BoardlyKit locally)
    └── Boardly/
        ├── App/                   # app routing
        ├── Onboarding/            # add server, login, profile selection
        ├── Projects/              # projects & boards lists
        ├── Board/                 # board, columns, cards, card detail + sheets
        ├── Profile/               # profile management
        ├── DesignSystem/          # Pine Teal — typography, components, logo
        └── Resources/Fonts/       # Manrope, JetBrains Mono
```

---

## Roadmap

The work is planned across five phases (see [`ROADMAP.md`](ROADMAP.md)).

- [x] **Phase 1 — Foundation:** BoardlyKit core, OpenAPI models, REST client, multi-instance Keychain auth, onboarding
- [x] **Phase 2 — Core kanban loop:** projects/boards, board detail, card & task CRUD, pull-to-refresh
- [x] **Phase 3 — Real-time sync:** Socket.IO live updates, per-profile lifecycle, reconnection
- [x] **Phase 4 — Rich card content:** labels, members, comments, attachments, due dates, chrono, activity
- [ ] **Phase 5 — Account & admin:** OIDC/SSO, notifications, board backgrounds, custom fields, admin config

---

## Testing

`BoardlyKit` carries the project's highest-priority test coverage — it's the foundation everything else trusts.

```bash
swift test                                   # run all tests
swift test --filter BoardlyKitTests          # scope to the kit
```

- **~83 unit tests** written with **Swift Testing** (`@Test` / `#expect`)
- Networking is exercised through a **mockable `URLSession`** — no real network in tests
- Real-time is tested against a **mock socket transport**, not a live connection
- Coverage spans request building, `PlankaAPIError` mapping, Keychain storage, profile add/switch/remove, `included`-payload decoding, real-time reconciliation, and JWT handling
- Model decoding is validated against JSON fixtures in `Tests/BoardlyKitTests/Fixtures/`

---

## Contributing

Contributions are welcome. A few house rules:

- Run `swift test` before opening a PR (a passing run is required).
- Feature work goes on `feat/<slug>`, fixes on `fix/<slug>`, tooling on `chore/<slug>` — never commit features directly to `main`.
- PRs are squash-merged into `main`.

**Commit convention** — emoji conventional commits: `<emoji> <type>(<scope>): <imperative message>`

| Type | Emoji | Example |
| ---- | :---: | ------- |
| feat | ✨ | `✨ feat(auth): add OIDC token exchange flow` |
| fix | 🐛 | `🐛 fix(board): pin columns to top` |
| docs | 📝 | `📝 docs(readme): document getting started` |
| refactor | ♻️ | `♻️ refactor(board): extend BoardPayload` |
| style | 🎨 | `🎨 style(card): full-bleed cover image` |
| test | ✅ | `✅ test(realtime): cover reconnection` |
| chore | 🧑‍💻 | `🧑‍💻 chore(ci): configure hooks` |

`swiftformat` runs automatically as a post-edit hook.

---

## License

Released under the [MIT License](LICENSE). © 2026 2rock Inc.

---

<div align="center">

Built with SwiftUI for the [PLANKA](https://github.com/plankanban/planka) community · made by **2rock Inc.**

</div>
