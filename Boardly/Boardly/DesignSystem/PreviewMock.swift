#if DEBUG
import Foundation
import SwiftUI
import BoardlyKit

// DEBUG-only mock backend so design screens can be rendered (and screenshotted)
// without a live PLANKA server. Activated via the `-mockBoard` launch argument.
// Never compiled into release builds.

private final class MockHTTPClient: HTTPClient, @unchecked Sendable {
    let json: String
    init(json: String) { self.json = json }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let path = request.url?.path ?? ""
        let body: String
        if path.hasSuffix("/comments"), request.httpMethod == "GET" {
            body = PreviewMock.commentsJSON
        } else {
            body = json
        }
        let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (Data(body.utf8), resp)
    }
}

private final class MockKeychain: KeychainStoring, @unchecked Sendable {
    func save(_ value: String, for key: String) throws {}
    func load(for key: String) throws -> String? { mockJWT }
    func delete(for key: String) throws {}

    // A JWT-shaped token whose payload subject is "u1" (Marie Dupont), so the
    // header avatar resolves in the mock harness.
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

    private static func client(json: String) -> PlankaClient {
        let profile = ServerProfile(name: "Mock", baseURL: URL(string: "https://mock.local")!)
        return PlankaClient(
            profile: profile,
            tokenStore: TokenStore(profileID: profile.id, keychainStore: MockKeychain()),
            httpClient: MockHTTPClient(json: json)
        )
    }

    nonisolated static let commentsJSON = """
    {
      "items": [
        { "id": "cm1", "cardId": "c1", "userId": "u2", "text": "La direction « hero produit » me parle bien, on part là-dessus pour le sprint ?", "createdAt": "2026-06-29T09:00:00.000Z" },
        { "id": "cm2", "cardId": "c1", "userId": "u1", "text": "Oui — je prépare les specs et je partage la maquette hero dès demain.", "createdAt": "2026-06-29T11:00:00.000Z" }
      ],
      "included": { "users": [] }
    }
    """

    static let projectsJSON = """
    {
      "items": [
        { "id": "p1", "name": "Refonte 2026", "isHidden": false, "isFavorite": true, "description": "Refonte complète de l’app mobile et du back-office. Cible : livraison T2." },
        { "id": "p2", "name": "Marketing", "isHidden": false, "isFavorite": true },
        { "id": "p3", "name": "Infra", "isHidden": false, "isFavorite": false }
      ],
      "included": {
        "boards": [
          { "id": "b1", "projectId": "p1", "name": "Sprint Produit", "position": 1 },
          { "id": "b2", "projectId": "p1", "name": "Recherche & specs", "position": 2 },
          { "id": "b3", "projectId": "p2", "name": "Campagne Été", "position": 1 },
          { "id": "b4", "projectId": "p3", "name": "Todo", "position": 1 }
        ],
        "users": [
          { "id": "u1", "role": "admin", "name": "Marie Dupont", "isDeactivated": false },
          { "id": "u2", "role": "member", "name": "Paul Lefevre", "isDeactivated": false },
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
        ]
      }
    }
    """

    static let boardJSON = """
    {
      "item": { "id": "b1", "projectId": "p1", "name": "Sprint Produit" },
      "included": {
        "lists": [
          { "id": "l1", "boardId": "b1", "type": "active", "name": "À faire", "position": 1 },
          { "id": "l2", "boardId": "b1", "type": "active", "name": "En cours", "position": 2 },
          { "id": "l3", "boardId": "b1", "type": "active", "name": "Terminé", "position": 3 }
        ],
        "cards": [
          { "id": "c1", "boardId": "b1", "listId": "l1", "name": "Nouvelle page d’accueil — exploration visuelle", "position": 1, "dueDate": "2026-10-12T09:00:00.000Z" },
          { "id": "c2", "boardId": "b1", "listId": "l1", "name": "Composant carte réutilisable en SwiftUI", "position": 2 },
          { "id": "c3", "boardId": "b1", "listId": "l1", "name": "Lister les écrans à refondre", "position": 3 },
          { "id": "c4", "boardId": "b1", "listId": "l2", "name": "Système de couleurs & tokens Pine Teal", "position": 1, "dueDate": "2026-06-29T09:00:00.000Z" },
          { "id": "c5", "boardId": "b1", "listId": "l2", "name": "Navigation par onglets + deep links", "position": 2, "dueDate": "2026-06-29T09:00:00.000Z" },
          { "id": "c6", "boardId": "b1", "listId": "l3", "name": "Écran de connexion", "position": 1, "dueDate": "2026-06-20T09:00:00.000Z", "isDueCompleted": true }
        ],
        "taskLists": [
          { "id": "tl1", "cardId": "c1", "name": "Sous-tâches", "position": 1 },
          { "id": "tl2", "cardId": "c2", "name": "Sous-tâches", "position": 1 },
          { "id": "tl4", "cardId": "c4", "name": "Sous-tâches", "position": 1 }
        ],
        "tasks": [
          { "id": "t1", "taskListId": "tl1", "name": "Maquette", "isCompleted": true, "position": 1 },
          { "id": "t2", "taskListId": "tl1", "name": "Tokens", "isCompleted": true, "position": 2 },
          { "id": "t3", "taskListId": "tl1", "name": "Revue", "isCompleted": true, "position": 3 },
          { "id": "t4", "taskListId": "tl1", "name": "Intégration", "isCompleted": false, "position": 4 },
          { "id": "t5", "taskListId": "tl1", "name": "QA", "isCompleted": false, "position": 5 },
          { "id": "t6", "taskListId": "tl2", "name": "API", "isCompleted": false, "position": 1 },
          { "id": "t7", "taskListId": "tl2", "name": "Vue", "isCompleted": false, "position": 2 },
          { "id": "t8", "taskListId": "tl2", "name": "Tests", "isCompleted": false, "position": 3 },
          { "id": "t9", "taskListId": "tl4", "name": "Light", "isCompleted": true, "position": 1 },
          { "id": "t10", "taskListId": "tl4", "name": "Dark", "isCompleted": true, "position": 2 },
          { "id": "t11", "taskListId": "tl4", "name": "Contraste", "isCompleted": true, "position": 3 },
          { "id": "t12", "taskListId": "tl4", "name": "Doc", "isCompleted": true, "position": 4 }
        ],
        "labels": [
          { "id": "lb1", "boardId": "b1", "name": "Design", "color": "lagoon-blue", "position": 1 },
          { "id": "lb2", "boardId": "b1", "name": "Priorité", "color": "berry-red", "position": 2 }
        ],
        "cardMemberships": [
          { "id": "cm1", "cardId": "c1", "userId": "u1", "role": "editor" }
        ],
        "cardLabels": [
          { "id": "cl1", "cardId": "c1", "labelId": "lb1" },
          { "id": "cl2", "cardId": "c1", "labelId": "lb2" }
        ],
        "users": [
          { "id": "u1", "role": "admin", "name": "Marie Dupont", "username": "marie.dupont", "isDeactivated": false },
          { "id": "u2", "role": "member", "name": "Paul Lemaire", "username": "paul.l", "isDeactivated": false },
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
            BoardView(client: PreviewMock.boardClient(), boardId: "b1", boardName: "Sprint Produit", projectName: "Refonte 2026")
        }
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
            ProjectDetailView(client: PreviewMock.projectsClient(), projectId: "p1", projectName: "Refonte 2026", path: $path)
        }
    }
}

struct MockLoginHarness: View {
    @State private var path: [OnboardingRoute] = []
    private let profile = ServerProfile(name: "Équipe", baseURL: URL(string: "https://planka.equipe.fr")!)
    var body: some View {
        NavigationStack(path: $path) {
            LoginView(profile: profile, path: $path)
        }
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
                        case .project(let id, let name):
                            ProjectDetailView(client: PreviewMock.projectsClient(), projectId: id, projectName: name, path: $path)
                        case .board(let id, let name, let projectName):
                            BoardView(client: PreviewMock.boardClient(), boardId: id, boardName: name, projectName: projectName)
                        }
                    }
            }
            .tabItem { Label("Projets", systemImage: "house") }
            ComingSoonView(title: "Recherche", systemImage: "magnifyingglass")
                .tabItem { Label("Recherche", systemImage: "magnifyingglass") }
            ComingSoonView(title: "Activité", systemImage: "bell")
                .tabItem { Label("Activité", systemImage: "bell") }
            ComingSoonView(title: "Profil", systemImage: "person")
                .tabItem { Label("Profil", systemImage: "person") }
        }
        .tint(.accentColor)
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
