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
        let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (Data(json.utf8), resp)
    }
}

private final class MockKeychain: KeychainStoring, @unchecked Sendable {
    func save(_ value: String, for key: String) throws {}
    func load(for key: String) throws -> String? { "mock-token" }
    func delete(for key: String) throws {}
}

enum PreviewMock {
    static func boardClient() -> PlankaClient {
        let profile = ServerProfile(name: "Mock", baseURL: URL(string: "https://mock.local")!)
        return PlankaClient(
            profile: profile,
            tokenStore: TokenStore(profileID: profile.id, keychainStore: MockKeychain()),
            httpClient: MockHTTPClient(json: boardJSON)
        )
    }

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
        "labels": [], "cardMemberships": [], "cardLabels": [], "users": []
      }
    }
    """
}

struct MockBoardHarness: View {
    var body: some View {
        NavigationStack {
            BoardView(client: PreviewMock.boardClient(), boardId: "b1", boardName: "Sprint Produit")
        }
    }
}
#endif
