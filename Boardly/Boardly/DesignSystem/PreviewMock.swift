#if DEBUG
    import BoardlyKit
    import Foundation
    import SwiftUI

    // DEBUG-only mock backend so design screens can be rendered (and screenshotted)
    // without a live PLANKA server. Activated via the `-mockBoard` launch argument.
    // Never compiled into release builds.

    private final class MockHTTPClient: HTTPClient, @unchecked Sendable {
        let json: String
        init(json: String) { self.json = json }
        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            // External URLs (e.g. cover images) → hit the real network so previews render them.
            if let host = request.url?.host, host != "mock.local" {
                return try await URLSession.shared.data(for: request)
            }
            let path = request.url?.path ?? ""
            let body: String = if path.hasSuffix("/bootstrap") {
                #"{"item":{"version":"2.0","oidc":null}}"#
            } else if path.hasSuffix("/comments"), request.httpMethod == "GET" {
                PreviewMock.commentsJSON
            } else if path.hasSuffix("/actions"), request.httpMethod == "GET" {
                PreviewMock.actionsJSON
            } else if path.contains("/boards/"), request.httpMethod == "GET", json == PreviewMock.projectsJSON {
                PreviewMock.boardJSON // per-board fetch from the projects list
            } else {
                json
            }
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(body.utf8), resp)
        }
    }

    private final class MockKeychain: KeychainStoring, @unchecked Sendable {
        func save(_: String, for _: String) throws {}
        func load(for _: String) throws -> String? { mockJWT }
        func delete(for _: String) throws {}

        /// A JWT-shaped token whose payload subject is "u1" (Alice Johnson), so the
        /// header avatar resolves in the mock harness.
        private var mockJWT: String {
            let payload = Data(#"{"subject":"u1"}"#.utf8).base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
            return "eyJhbGciOiJIUzI1NiJ9.\(payload).signature"
        }
    }

    enum PreviewMock {
        static func boardClient() -> PlankaClient {
            client(json: boardJSON)
        }

        static func projectsClient() -> PlankaClient {
            client(json: projectsJSON)
        }

        static func notificationsClient() -> PlankaClient {
            client(json: notificationsJSON)
        }

        static func profileClient() -> PlankaClient {
            client(json: currentUserJSON)
        }

        nonisolated static let currentUserJSON = """
        {
          "item": { "id": "u1", "role": "admin", "name": "Alice Johnson", "username": "alice.johnson", "organization": "Acme Corp", "isDeactivated": false, "isDefaultAdmin": true },
          "included": {
            "notificationServices": [
              { "id": "ns1", "userId": "u1", "boardId": null, "url": "https://hooks.slack.com/services/T000/B000/xyz", "format": "markdown", "createdAt": null, "updatedAt": null },
              { "id": "ns2", "userId": "u1", "boardId": null, "url": "tgram://bottoken/chatid", "format": "text", "createdAt": null, "updatedAt": null }
            ]
          }
        }
        """

        private static func client(json: String) -> PlankaClient {
            let profile = ServerProfile(name: "Mock", baseURL: URL(string: "https://mock.local")!)
            return PlankaClient(
                profile: profile,
                tokenStore: TokenStore(profileID: profile.id, keychainStore: MockKeychain()),
                httpClient: MockHTTPClient(json: json))
        }

        nonisolated static let notificationsJSON = """
        {
          "items": [
            { "id": "n1", "userId": "u1", "creatorUserId": "u2", "boardId": "b1", "cardId": "c1", "commentId": "cm1", "actionId": null, "type": "mentionInComment", "data": { "card": { "name": "Color system" }, "text": "shall we go with this?" }, "isRead": false, "createdAt": "2026-07-02T07:30:00.000Z", "updatedAt": "2026-07-02T07:30:00.000Z" },
            { "id": "n2", "userId": "u1", "creatorUserId": "u3", "boardId": "b1", "cardId": "c2", "commentId": null, "actionId": "a2", "type": "moveCard", "data": { "card": { "name": "Tab navigation" } }, "isRead": false, "createdAt": "2026-07-02T05:30:00.000Z", "updatedAt": "2026-07-02T05:30:00.000Z" },
            { "id": "n3", "userId": "u1", "creatorUserId": "u4", "boardId": "b1", "cardId": "c3", "commentId": null, "actionId": null, "type": "addMemberToCard", "data": { "card": { "name": "VoiceOver testing" } }, "isRead": false, "createdAt": "2026-07-02T03:30:00.000Z", "updatedAt": "2026-07-02T03:30:00.000Z" },
            { "id": "n4", "userId": "u1", "creatorUserId": "u5", "boardId": "b1", "cardId": "c4", "commentId": "cm4", "actionId": null, "type": "commentCard", "data": { "card": { "name": "New home page" }, "text": "Great direction, I'm on board." }, "isRead": false, "createdAt": "2026-06-30T09:00:00.000Z", "updatedAt": "2026-06-30T09:00:00.000Z" }
          ],
          "included": {
            "users": [
              { "id": "u2", "role": "boardUser", "name": "Bob Williams", "isDeactivated": false },
              { "id": "u3", "role": "boardUser", "name": "Jules Kern", "isDeactivated": false },
              { "id": "u4", "role": "boardUser", "name": "Emma Martin", "isDeactivated": false },
              { "id": "u5", "role": "boardUser", "name": "Alice Johnson", "isDeactivated": false }
            ]
          }
        }
        """

        nonisolated static let actionsJSON = """
        {
          "items": [
            { "id": "ac1", "cardId": "c1", "userId": "u1", "type": "createCard", "data": {}, "createdAt": "2026-06-28T09:00:00.000Z" },
            { "id": "ac2", "cardId": "c1", "userId": "u2", "type": "completeTask", "data": {}, "createdAt": "2026-06-29T10:00:00.000Z" }
          ],
          "included": { "users": [] }
        }
        """

        nonisolated static let commentsJSON = """
        {
          "items": [
            { "id": "cm1", "cardId": "c1", "userId": "u2", "text": "I really like the “product hero” direction — shall we go with it for the sprint?", "createdAt": "2026-06-29T09:00:00.000Z" },
            { "id": "cm2", "cardId": "c1", "userId": "u1", "text": "Yes — I'll prep the specs and share the hero mockup first thing tomorrow.", "createdAt": "2026-06-29T11:00:00.000Z" }
          ],
          "included": { "users": [] }
        }
        """

        nonisolated static let projectsJSON = """
        {
          "items": [
            { "id": "p1", "name": "Redesign 2026", "isHidden": false, "isFavorite": true, "description": "Complete redesign of the mobile app and back office. Target: Q2 delivery." },
            { "id": "p2", "name": "Marketing", "isHidden": false, "isFavorite": true },
            { "id": "p3", "name": "Infra", "isHidden": false, "isFavorite": false }
          ],
          "included": {
            "boards": [
              { "id": "b1", "projectId": "p1", "name": "Product Sprint", "position": 1, "updatedAt": "2026-07-02T04:30:00.000Z" },
              { "id": "b2", "projectId": "p1", "name": "Research & specs", "position": 2, "updatedAt": "2026-07-01T09:00:00.000Z" },
              { "id": "b3", "projectId": "p2", "name": "Summer Campaign", "position": 1, "updatedAt": "2026-07-02T02:00:00.000Z" },
              { "id": "b4", "projectId": "p3", "name": "Todo", "position": 1, "updatedAt": "2026-06-30T12:00:00.000Z" }
            ],
            "users": [
              { "id": "u1", "role": "admin", "name": "Alice Johnson", "isDeactivated": false },
              { "id": "u2", "role": "member", "name": "Chris Miller", "isDeactivated": false },
              { "id": "u3", "role": "member", "name": "Julie Klein", "isDeactivated": false },
              { "id": "u4", "role": "member", "name": "Hugo Bernard", "isDeactivated": false }
            ],
            "boardMemberships": [
              { "id": "m1", "projectId": "p1", "boardId": "b1", "userId": "u1", "role": "editor" },
              { "id": "m2", "projectId": "p1", "boardId": "b1", "userId": "u2", "role": "editor" },
              { "id": "m3", "projectId": "p1", "boardId": "b2", "userId": "u3", "role": "editor" },
              { "id": "m4", "projectId": "p1", "boardId": "b2", "userId": "u4", "role": "editor" },
              { "id": "m5", "projectId": "p2", "boardId": "b3", "userId": "u3", "role": "editor" },
              { "id": "m6", "projectId": "p2", "boardId": "b3", "userId": "u1", "role": "editor" }
            ],
            "projectManagers": [
              { "id": "pm1", "projectId": "p1", "userId": "u1" },
              { "id": "pm2", "projectId": "p1", "userId": "u2" },
              { "id": "pm3", "projectId": "p1", "userId": "u3" }
            ],
            "baseCustomFieldGroups": [
              { "id": "g1", "projectId": "p1", "name": "Product tracking" },
              { "id": "g2", "projectId": "p1", "name": "Client" }
            ],
            "customFields": [
              { "id": "cf1", "baseCustomFieldGroupId": "g1", "name": "Priority", "position": 1 },
              { "id": "cf2", "baseCustomFieldGroupId": "g1", "name": "Estimate", "position": 2 },
              { "id": "cf3", "baseCustomFieldGroupId": "g1", "name": "Due date", "position": 3 },
              { "id": "cf4", "baseCustomFieldGroupId": "g2", "name": "Account", "position": 1 },
              { "id": "cf5", "baseCustomFieldGroupId": "g2", "name": "Segment", "position": 2 }
            ]
          }
        }
        """

        nonisolated static let boardJSON = """
        {
          "item": { "id": "b1", "projectId": "p1", "name": "Product Sprint" },
          "included": {
            "lists": [
              { "id": "l1", "boardId": "b1", "type": "active", "name": "To Do", "position": 1 },
              { "id": "l2", "boardId": "b1", "type": "active", "name": "In Progress", "position": 2 },
              { "id": "l3", "boardId": "b1", "type": "active", "name": "Done", "position": 3 }
            ],
            "cards": [
              { "id": "c1", "boardId": "b1", "listId": "l1", "name": "New home page — visual exploration", "position": 1, "dueDate": "2026-10-12T09:00:00.000Z", "commentsTotal": 2, "creatorUserId": "u1", "createdAt": "2026-06-29T09:00:00.000Z", "coverAttachmentId": "at1", "stopwatch": { "total": 5040, "startedAt": null } },
              { "id": "c2", "boardId": "b1", "listId": "l1", "name": "Reusable card component in SwiftUI", "position": 2 },
              { "id": "c3", "boardId": "b1", "listId": "l1", "name": "List the screens to redesign", "position": 3 },
              { "id": "c7", "boardId": "b1", "listId": "l1", "name": "Audit spacing & typography scale", "position": 4, "commentsTotal": 1 },
              { "id": "c8", "boardId": "b1", "listId": "l1", "name": "Dark mode color ramp", "position": 5, "dueDate": "2026-07-20T09:00:00.000Z" },
              { "id": "c9", "boardId": "b1", "listId": "l1", "name": "Empty states illustrations", "position": 6 },
              { "id": "c10", "boardId": "b1", "listId": "l1", "name": "Accessibility pass — VoiceOver labels", "position": 7 },
              { "id": "c11", "boardId": "b1", "listId": "l1", "name": "Onboarding hero + copy", "position": 8, "commentsTotal": 3 },
              { "id": "c12", "boardId": "b1", "listId": "l1", "name": "Icon set — SF Symbols mapping", "position": 9 },
              { "id": "c4", "boardId": "b1", "listId": "l2", "name": "Color system & Pine Teal tokens", "position": 1, "dueDate": "2026-06-29T09:00:00.000Z" },
              { "id": "c5", "boardId": "b1", "listId": "l2", "name": "Tab navigation + deep links", "position": 2, "dueDate": "2026-06-29T09:00:00.000Z" },
              { "id": "c6", "boardId": "b1", "listId": "l3", "name": "Login screen", "position": 1, "dueDate": "2026-06-20T09:00:00.000Z", "isDueCompleted": true }
            ],
            "taskLists": [
              { "id": "tl1", "cardId": "c1", "name": "Subtasks", "position": 1 },
              { "id": "tl2", "cardId": "c2", "name": "Subtasks", "position": 1 },
              { "id": "tl4", "cardId": "c4", "name": "Subtasks", "position": 1 }
            ],
            "tasks": [
              { "id": "t1", "taskListId": "tl1", "name": "Mockup", "isCompleted": true, "position": 1 },
              { "id": "t2", "taskListId": "tl1", "name": "Tokens", "isCompleted": true, "position": 2 },
              { "id": "t3", "taskListId": "tl1", "name": "Review", "isCompleted": true, "position": 3 },
              { "id": "t4", "taskListId": "tl1", "name": "Integration", "isCompleted": false, "position": 4 },
              { "id": "t5", "taskListId": "tl1", "name": "QA", "isCompleted": false, "position": 5 },
              { "id": "t6", "taskListId": "tl2", "name": "API", "isCompleted": false, "position": 1 },
              { "id": "t7", "taskListId": "tl2", "name": "View", "isCompleted": false, "position": 2 },
              { "id": "t8", "taskListId": "tl2", "name": "Tests", "isCompleted": false, "position": 3 },
              { "id": "t9", "taskListId": "tl4", "name": "Light", "isCompleted": true, "position": 1 },
              { "id": "t10", "taskListId": "tl4", "name": "Dark", "isCompleted": true, "position": 2 },
              { "id": "t11", "taskListId": "tl4", "name": "Contrast", "isCompleted": true, "position": 3 },
              { "id": "t12", "taskListId": "tl4", "name": "Doc", "isCompleted": true, "position": 4 }
            ],
            "labels": [
              { "id": "lb1", "boardId": "b1", "name": "Design", "color": "lagoon-blue", "position": 1 },
              { "id": "lb2", "boardId": "b1", "name": "Priority", "color": "berry-red", "position": 2 }
            ],
            "cardMemberships": [
              { "id": "cm1", "cardId": "c1", "userId": "u1", "role": "editor" }
            ],
            "attachments": [
              { "id": "at1", "cardId": "c1", "type": "file", "data": { "url": "https://picsum.photos/id/1062/900/500" }, "name": "home-mockup.png" }
            ],
            "customFieldGroups": [
              { "id": "g1", "boardId": "b1", "cardId": null, "baseCustomFieldGroupId": "bg1", "position": 1, "name": "Product tracking" }
            ],
            "customFields": [
              { "id": "f1", "customFieldGroupId": "g1", "position": 1, "name": "Priority", "showOnFrontOfCard": false },
              { "id": "f2", "customFieldGroupId": "g1", "position": 2, "name": "Estimate", "showOnFrontOfCard": false },
              { "id": "f3", "customFieldGroupId": "g1", "position": 3, "name": "Due window", "showOnFrontOfCard": false }
            ],
            "customFieldValues": [
              { "id": "v1", "cardId": "c1", "customFieldGroupId": "g1", "customFieldId": "f1", "content": "High" },
              { "id": "v2", "cardId": "c1", "customFieldGroupId": "g1", "customFieldId": "f2", "content": "5" }
            ],
            "cardLabels": [
              { "id": "cl1", "cardId": "c1", "labelId": "lb1" },
              { "id": "cl2", "cardId": "c1", "labelId": "lb2" }
            ],
            "users": [
              { "id": "u1", "role": "admin", "name": "Alice Johnson", "username": "alice.johnson", "isDeactivated": false },
              { "id": "u2", "role": "member", "name": "Bob Williams", "username": "bob.williams", "isDeactivated": false },
              { "id": "u3", "role": "member", "name": "Emma Morel", "username": "emma.m", "isDeactivated": false }
            ],
            "boardMemberships": [
              { "id": "bm1", "projectId": "p1", "boardId": "b1", "userId": "u1", "role": "editor" },
              { "id": "bm2", "projectId": "p1", "boardId": "b1", "userId": "u2", "role": "editor" },
              { "id": "bm3", "projectId": "p1", "boardId": "b1", "userId": "u3", "role": "editor" }
            ]
          }
        }
        """
    }

    struct MockBoardHarness: View {
        var body: some View {
            NavigationStack {
                BoardView(client: PreviewMock.boardClient(), boardId: "b1", boardName: "Product Sprint", projectName: "Redesign 2026")
            }
            .environment(BoardSessionStore())
        }
    }

    struct MockMembersSheetHarness: View {
        @State private var vm = BoardViewModel(client: PreviewMock.boardClient(), boardId: "b1")
        @State private var show = false
        var body: some View {
            Color.boardlyBackground.ignoresSafeArea()
                .task { await vm.load(); show = true }
                .sheet(isPresented: $show) { CardMembersSheet(cardId: "c1", boardVM: vm) }
        }
    }

    struct MockProjectDetailHarness: View {
        @State private var path: [AppRoute] = []
        var body: some View {
            NavigationStack(path: $path) {
                ProjectDetailView(client: PreviewMock.projectsClient(), projectId: "p1", projectName: "Redesign 2026", path: $path)
            }
        }
    }

    struct MockLoginHarness: View {
        @State private var path: [OnboardingRoute] = []
        private let profile = ServerProfile(name: "Team", baseURL: URL(string: "https://planka.example.com")!)
        var body: some View {
            NavigationStack(path: $path) {
                LoginView(profile: profile, path: $path)
            }
            .environment(ProfileStore())
        }
    }

    struct MockActivityHarness: View {
        @State private var vm = NotificationsViewModel(client: PreviewMock.notificationsClient())
        var body: some View {
            ActivityView(viewModel: vm)
        }
    }

    struct MockEditProjectHarness: View {
        @State private var vm = ProjectDetailViewModel()
        private let client = PreviewMock.projectsClient()
        private var initialTab: EditProjectSheet.EditTab {
            let args = CommandLine.arguments
            if args.contains("-tab2") { return .managers }
            if args.contains("-tab3") { return .background }
            if args.contains("-tab4") { return .customFields }
            return .general
        }

        var body: some View {
            EditProjectSheet(viewModel: vm, client: client, initialTab: initialTab, onDeleted: {})
                .task { await vm.load(projectId: "p1", using: client) }
        }
    }

    struct MockSearchHarness: View {
        var body: some View {
            SearchView(client: PreviewMock.projectsClient(), initialQuery: "home")
                .environment(BoardSessionStore())
        }
    }

    struct MockProfileHarness: View {
        var body: some View {
            ProfileView(
                profile: ServerProfile(name: "Team", baseURL: URL(string: "https://todo.2rock.fr")!),
                client: PreviewMock.profileClient())
                .environment(ProfileStore())
        }
    }

    struct MockProjectsHarness: View {
        @State private var path: [AppRoute] = []
        var body: some View {
            TabView {
                NavigationStack(path: $path) {
                    ProjectListView(client: PreviewMock.projectsClient(), path: $path)
                        .navigationDestination(for: AppRoute.self) { route in
                            switch route {
                            case let .project(id, name):
                                ProjectDetailView(client: PreviewMock.projectsClient(), projectId: id, projectName: name, path: $path)
                            case let .board(id, name, projectName, focusCardId):
                                BoardView(
                                    client: PreviewMock.boardClient(),
                                    boardId: id,
                                    boardName: name,
                                    projectName: projectName,
                                    focusCardId: focusCardId)
                            }
                        }
                }
                .tabItem { Label("Projects", systemImage: "house") }
                ComingSoonView(title: "Search", systemImage: "magnifyingglass")
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }
                ComingSoonView(title: "Activity", systemImage: "bell")
                    .tabItem { Label("Activity", systemImage: "bell") }
                ComingSoonView(title: "Profile", systemImage: "person")
                    .tabItem { Label("Profile", systemImage: "person") }
            }
            .tint(.accentColor)
            .environment(BoardSessionStore())
        }
    }

    struct MockCardHarness: View {
        @State private var vm = BoardViewModel(client: PreviewMock.boardClient(), boardId: "b1")
        var body: some View {
            NavigationStack {
                Group {
                    if vm.payload != nil {
                        CardDetailView(cardId: "c1", boardVM: vm)
                    } else {
                        ProgressView().tint(.accentColor)
                    }
                }
            }
            .task { await vm.load() }
        }
    }
#endif
