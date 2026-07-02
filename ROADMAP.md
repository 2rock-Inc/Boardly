# Boardly — Macro Roadmap (7 phases)

Each phase is meant to be one (or a few) separate Claude Code session(s).
Phases are ordered by dependency: each one builds on what the previous
phase shipped and tested. Don't start a phase until the previous one builds
and passes `swift test`.

Suggested branch per phase: `feat/<phase-slug>` (see Git branch conventions
in CLAUDE.md). Squash-merge to `main` before starting the next phase.

---

## Phase 1 — Foundation: BoardlyKit core + multi-instance auth

**Goal:** the bedrock every other phase depends on. No UI polish needed yet,
just a working, tested core.

- `Package.swift` + `Sources/BoardlyKit` scaffolding
- Download/commit `Reference/planka-openapi.json`, generate `Codable` models
- REST client (`URLSession` + `async/await`), scoped per server profile
- Keychain storage wrapper, scoped per profile
- Server profile management (add / switch / remove), base URL validation
  (including subpath support)
- Password login (`POST /access-tokens`) — **OIDC/SSO comes later (Phase 5)**
- 401 handling → re-route to that profile's login
- Central `PlankaAPIError` mapping (`E_UNAUTHORIZED`, `E_FORBIDDEN`, etc.)
- Minimal onboarding UI: add server, log in, switch profile

**Testing expectations:** unit tests (mocked `URLSession`) for the REST
client's request building and error mapping, the Keychain wrapper, profile
add/switch/remove logic, and model decoding against
`Reference/planka-openapi.json` fixtures. This is the highest-priority test
coverage in the whole project — it's the foundation everything else trusts.

**Suggested kickoff prompt:**
> Read CLAUDE.md. Implement Phase 1 of ROADMAP.md: BoardlyKit scaffolding,
> models from the OpenAPI spec, the REST client, Keychain-backed multi-instance
> auth (password login only), and a minimal onboarding UI. Include unit tests per
> the "Testing expectations" in ROADMAP.md. Plan first, then implement.

---

## Phase 2 — Core kanban loop (the actual app)

**Goal:** a genuinely usable kanban client, REST-only, no real-time yet.

- Projects → boards list
- Board detail: lists + cards parsed from `GET /boards/{id}` `included` payload
- Create / edit card (name, description, dueDate, move between lists)
- Tasks inside a card's task list, toggle `isCompleted`
- Pull-to-refresh
- Basic navigation (`NavigationStack`, path-based router)

**Testing expectations:** unit tests for parsing the `included` payload into
lists/cards/tasks, for the view models driving card/task CRUD (mocked
BoardlyKit client, no real network), and for the move-between-lists logic.

**Suggested kickoff prompt:**
> Read CLAUDE.md and ROADMAP.md. Implement Phase 2: the core boards/lists/cards/tasks
> screens and CRUD, on top of the Phase 1 foundation. REST + pull-to-refresh only,
> no Socket.IO yet. Include unit tests per the "Testing expectations" in ROADMAP.md.
> Plan first, then implement.

---

## Phase 3 — Real-time sync (Socket.IO)

**Goal:** layer live updates on top of the already-working Phase 2 loop.

- Add the Socket.IO client dependency (the one allowed exception to "no
  third-party deps" in BoardlyKit)
- Per-profile connection lifecycle: connect when a board is open, disconnect
  on leaving the board or switching profiles
- Subscribe to board events → update lists/cards/tasks live
- Reconnection handling; pull-to-refresh stays as the manual fallback

**Testing expectations:** unit tests for event handling and state
reconciliation (mocked socket transport, not a real connection), and for
the connect/disconnect lifecycle tied to profile switching and leaving a
board.

**Suggested kickoff prompt:**
> Read CLAUDE.md and ROADMAP.md. Implement Phase 3: Socket.IO real-time sync for
> the board screen built in Phase 2, including reconnection handling and correct
> per-profile connection lifecycle. Include unit tests per the "Testing expectations"
> in ROADMAP.md. Plan first, then implement.

---

## Phase 4 — Rich card content ✅ (custom fields split out → Phase 7)

**Goal:** everything that "hangs off" a card, building on Phase 2's card screen.

**Shipped** (merged in `main` via PR #5):

- Labels: create, assign, remove on cards
- Members: assign / remove board members on cards
- Comments: add, view, delete on cards
- Attachments: add (file / photo / link), view on cards (multipart upload)
- Chrono (stopwatch): start / stop, live-ticking elapsed time
- Activity: per-card action feed (author-attributed)

**Deferred out of this phase → now Phase 7:**

- Custom fields: manage custom field groups/fields, set values on cards

**Testing expectations:** unit tests for model decoding of labels,
comments, attachments (and the realtime reconciler for each), plus the view
models managing them on the card detail screen.

**Suggested kickoff prompt:**
> Read CLAUDE.md and ROADMAP.md. Implement Phase 4: labels, members, comments,
> attachments, chrono, and the activity feed on the card detail screen. Include
> unit tests per the "Testing expectations" in ROADMAP.md. Plan first, then implement.

---

## Phase 5 — Account & instance administration

**Goal:** the remaining account-level and admin-level features. Good last
phase since it touches settings/admin screens rather than the core loop.

- OIDC/SSO login (`POST /access-tokens/exchange-with-oidc`), alongside the
  existing password login from Phase 1
- Notifications: in-app list, mark as read; manage notification services
- Board backgrounds: set/change a board's background image
- Admin config: webhooks management, instance config (SMTP, etc.) — only
  exposed when the authenticated user has admin rights

**Testing expectations:** unit tests for the OIDC token-exchange flow
(mocked), notification list/mark-as-read logic, and the admin-rights gating
that decides whether admin screens are shown at all.

> The notification data/logic built here is *surfaced* by the **Activité** tab
> and the **Profil → Notifications** settings screen in Phase 6; keep the
> BoardlyKit-side model + view model reusable by both.

**Suggested kickoff prompt:**
> Read CLAUDE.md and ROADMAP.md. Implement Phase 5: OIDC/SSO login, notifications,
> board backgrounds, and admin config screens (gated on admin rights). Include unit
> tests per the "Testing expectations" in ROADMAP.md. Plan first, then implement.

---

## Phase 6 — App shell: TabBar + Recherche / Activité / Profil

**Goal:** the top-level navigation shell and the three remaining root tabs from
the design (screens 11–13). Ties together data already built in earlier phases
(notifications from Phase 5, profiles/auth from Phase 1) behind a persistent
TabBar. It's app-level chrome rather than the core loop.

- **TabBar shell:** persistent bottom tab bar — Projets · Recherche · Activité ·
  Profil — with an unread badge dot on the Activité tab. Projets is the existing
  projects→boards flow re-parented under the first tab.
- **Recherche tab** (screen 12): a search field + scope chips (Tout / Cartes /
  Boards / Projets); results grouped by type with match highlighting
  (card → project · list; board → project · N cartes; project). Drives the
  existing detail navigation. Decide REST search endpoint vs. client-side filter
  of loaded data (check `Reference/planka-openapi.json` for a search endpoint).
- **Activité tab** (screen 11): the notification/activity feed from Phase 5,
  grouped by recency (Aujourd'hui / Cette semaine), author-attributed with
  action text + context + relative time + unread dot; "Tout lire" (mark all read).
- **Profil tab** (screen 13): current-user header (avatar, name, @username,
  org · role); **Préférences** (Apparence, Vue d'accueil, Éditeur Markdown —
  backed by PLANKA user prefs like `defaultEditorMode` / `defaultHomeView`);
  **Compte & serveur** (Notifications → the Phase 5 notification-services screen,
  Serveur → active profile + switch); **Se déconnecter**; version footer
  ("Boardly x.y · Planka a.b").

**Testing expectations:** unit tests for the search view model (scope filtering
+ result grouping/ranking), the activity feed grouping (recency buckets +
read/unread), and the profile view model (preference read/write, logout, server
switch).

**Suggested kickoff prompt:**
> Read CLAUDE.md and ROADMAP.md. Implement Phase 6: the TabBar app shell and the
> Recherche, Activité, and Profil tabs (design screens 11–13), reusing the Phase 5
> notifications data and the Phase 1 profile/auth layer. Include unit tests per the
> "Testing expectations" in ROADMAP.md. Plan first, then implement.

---

## Phase 7 — Custom fields

**Goal:** the one piece of rich card content deferred out of Phase 4. Card-level
and board-level, so it slots cleanly on top of the Phase 4 card detail screen.

- BoardlyKit models: flesh out `CustomFieldGroup`, `CustomField`,
  `CustomFieldValue`, `BaseCustomFieldGroup` against `Reference/planka-openapi.json`
  (they currently exist only as Phase 1 stubs)
- `PlankaClient` endpoints: create/update/delete custom field groups and fields;
  set/clear a custom field value on a card
- `BoardPayload`: sideload `customFieldGroups` / `customFields` / `customFieldValues`
  (already present-but-ignored in the `included` payload) + a
  `customFields(for: card)` accessor
- Realtime: custom field group/field/value create-update-delete events wired into
  the pure reconciler (live sync, same pattern as labels/attachments)
- UI: a "Champs personnalisés" section on the card detail + an edit sheet
  (types: text, number, date, dropdown, checkbox — per PLANKA)
- Board-level management of custom field groups/fields

**Testing expectations:** unit tests for model decoding of custom field
groups/fields/values, the realtime reconciler for each event, and the view
model managing values on the card detail screen.

**Suggested kickoff prompt:**
> Read CLAUDE.md and ROADMAP.md. Implement Phase 7: custom fields (groups, fields,
> values) on the card detail screen and board-level management, including realtime
> reconciliation. Complete the BoardlyKit models against the OpenAPI spec first.
> Include unit tests per the "Testing expectations" in ROADMAP.md. Plan first,
> then implement.

---

## Notes for every phase

- Always start with "plan first, then implement" — review the plan before
  letting Claude Code write code (Shift+Tab for plan mode works too).
- Run `swift test` before merging; use `/code-review` and `/security-review`
  before each PR, especially for Phase 1 (auth/Keychain) and Phase 5 (OIDC,
  admin endpoints).
- Update CLAUDE.md if a phase reveals a rule that should change (e.g. a new
  architecture decision) — keep it in sync rather than letting drift
  accumulate.
