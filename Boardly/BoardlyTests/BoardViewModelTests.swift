//
//  BoardViewModelTests.swift
//  BoardlyTests
//
//  View-model-level tests for the Phase 2 kanban CRUD loop. The PlankaClient is
//  real (struct, no protocol to mock) and driven by a routed stub HTTPClient, so
//  these exercise optimistic local-state updates AND the request the client emits,
//  with no real network.
//

import Foundation
import Testing
import BoardlyKit
@testable import Boardly

// MARK: - Test doubles

/// Routes responses by `"METHOD /path"` and records every request it receives.
private final class StubHTTPClient: HTTPClient, @unchecked Sendable {
    /// status code + JSON body, keyed by `"METHOD /api/path"`.
    var routes: [String: (Int, String)] = [:]
    private(set) var requests: [URLRequest] = []

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let method = request.httpMethod ?? "?"
        let path = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.path ?? "?"
        let key = "\(method) \(path)"
        guard let (status, json) = routes[key] else {
            Issue.record("Unstubbed request: \(key)")
            throw URLError(.unsupportedURL)
        }
        let resp = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (Data(json.utf8), resp)
    }

    /// Most recent request matching `"METHOD /path"`, for body/header assertions.
    func lastRequest(_ key: String) -> URLRequest? {
        requests.last {
            let method = $0.httpMethod ?? "?"
            let path = URLComponents(url: $0.url!, resolvingAgainstBaseURL: false)?.path ?? "?"
            return "\(method) \(path)" == key
        }
    }
}

private final class InMemoryKeychain: KeychainStoring, @unchecked Sendable {
    func save(_ value: String, for key: String) throws {}
    func load(for key: String) throws -> String? { nil }
    func delete(for key: String) throws {}
}

// MARK: - Fixtures & helpers

@MainActor
private func makeViewModel(_ stub: StubHTTPClient, boardId: String = "b1") -> BoardViewModel {
    let profile = ServerProfile(id: UUID(), name: "Test", baseURL: URL(string: "https://planka.example.com")!)
    let tokenStore = TokenStore(profileID: profile.id, keychainStore: InMemoryKeychain())
    let client = PlankaClient(profile: profile, tokenStore: tokenStore, httpClient: stub)
    return BoardViewModel(client: client, boardId: boardId)
}

/// A board with two active lists (`l1`, `l2`), one card (`c1` in `l1`),
/// one task list (`tl1` on `c1`) and one open task (`t1`).
private let boardJSON = """
{
  "item": { "id": "b1", "projectId": "p1", "name": "Board" },
  "included": {
    "lists": [
      { "id": "l1", "boardId": "b1", "type": "active", "name": "To Do", "position": 1 },
      { "id": "l2", "boardId": "b1", "type": "active", "name": "Doing", "position": 2 }
    ],
    "cards": [
      { "id": "c1", "boardId": "b1", "listId": "l1", "name": "Card A", "position": 1 }
    ],
    "taskLists": [
      { "id": "tl1", "cardId": "c1", "name": "Checklist", "position": 1 }
    ],
    "tasks": [
      { "id": "t1", "taskListId": "tl1", "name": "Step 1", "isCompleted": false, "position": 1 }
    ]
  }
}
"""

private func card(id: String, listId: String, name: String = "Card A") -> String {
    #"{ "item": { "id": "\#(id)", "boardId": "b1", "listId": "\#(listId)", "name": "\#(name)" } }"#
}

private func bodyJSON(_ request: URLRequest?) -> [String: Any] {
    guard let data = request?.httpBody,
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return [:] }
    return obj
}

// MARK: - Tests

@MainActor
@Suite("BoardViewModel — Phase 2 CRUD")
struct BoardViewModelTests {

    @Test("load() populates the payload from getBoard")
    func loadPopulatesPayload() async {
        let stub = StubHTTPClient()
        stub.routes["GET /api/boards/b1"] = (200, boardJSON)
        let vm = makeViewModel(stub)

        await vm.load()

        #expect(vm.error == nil)
        #expect(vm.payload?.cards.count == 1)
        #expect(vm.payload?.sortedLists().count == 2)
    }

    @Test("createCard appends the returned card to the payload")
    func createCardAppends() async {
        let stub = StubHTTPClient()
        stub.routes["GET /api/boards/b1"] = (200, boardJSON)
        stub.routes["POST /api/lists/l2/cards"] = (200, card(id: "c2", listId: "l2", name: "New"))
        let vm = makeViewModel(stub)
        await vm.load()
        let list2 = vm.payload!.sortedLists().first { $0.id == "l2" }!

        await vm.createCard(in: list2, name: "New")

        #expect(vm.error == nil)
        #expect(vm.payload?.cards.count == 2)
        #expect(vm.payload?.cards.contains { $0.id == "c2" } == true)
        // Position is computed as last-in-list + 65536; l2 was empty → 65536.
        let body = bodyJSON(stub.lastRequest("POST /api/lists/l2/cards"))
        #expect(body["name"] as? String == "New")
        #expect(body["position"] as? Double == 65536)
    }

    @Test("moveCard updates the card's listId locally and PATCHes listId")
    func moveCardUpdatesListId() async {
        let stub = StubHTTPClient()
        stub.routes["GET /api/boards/b1"] = (200, boardJSON)
        stub.routes["PATCH /api/cards/c1"] = (200, card(id: "c1", listId: "l2"))
        let vm = makeViewModel(stub)
        await vm.load()
        let cardC1 = vm.payload!.cards.first { $0.id == "c1" }!
        let list2 = vm.payload!.sortedLists().first { $0.id == "l2" }!

        await vm.moveCard(cardC1, to: list2)

        #expect(vm.error == nil)
        #expect(vm.payload?.card(id: "c1")?.listId == "l2")
        let body = bodyJSON(stub.lastRequest("PATCH /api/cards/c1"))
        #expect(body["listId"] as? String == "l2")
        #expect(body["position"] != nil)
    }

    @Test("deleteCard removes the card from the payload")
    func deleteCardRemoves() async {
        let stub = StubHTTPClient()
        stub.routes["GET /api/boards/b1"] = (200, boardJSON)
        stub.routes["DELETE /api/cards/c1"] = (200, card(id: "c1", listId: "l1"))
        let vm = makeViewModel(stub)
        await vm.load()
        let cardC1 = vm.payload!.cards.first { $0.id == "c1" }!

        await vm.deleteCard(cardC1)

        #expect(vm.error == nil)
        #expect(vm.payload?.cards.isEmpty == true)
    }

    @Test("updateCard with a due date PATCHes an ISO-8601 dueDate string")
    func updateCardDueDate() async {
        let stub = StubHTTPClient()
        stub.routes["GET /api/boards/b1"] = (200, boardJSON)
        stub.routes["PATCH /api/cards/c1"] = (200, card(id: "c1", listId: "l1"))
        let vm = makeViewModel(stub)
        await vm.load()
        let cardC1 = vm.payload!.cards.first { $0.id == "c1" }!

        let due = Date(timeIntervalSince1970: 1_700_000_000)
        await vm.updateCard(cardC1, patch: CardPatch(dueDate: due))

        #expect(vm.error == nil)
        let body = bodyJSON(stub.lastRequest("PATCH /api/cards/c1"))
        let dueString = body["dueDate"] as? String
        #expect(dueString != nil)
        // Round-trips back to the same instant.
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        #expect(formatter.date(from: dueString ?? "") == due)
    }

    @Test("updateCard clearing the due date PATCHes dueDate: null")
    func updateCardClearDueDate() async {
        let stub = StubHTTPClient()
        stub.routes["GET /api/boards/b1"] = (200, boardJSON)
        stub.routes["PATCH /api/cards/c1"] = (200, card(id: "c1", listId: "l1"))
        let vm = makeViewModel(stub)
        await vm.load()
        let cardC1 = vm.payload!.cards.first { $0.id == "c1" }!

        await vm.updateCard(cardC1, patch: CardPatch(clearDueDate: true))

        #expect(vm.error == nil)
        let body = bodyJSON(stub.lastRequest("PATCH /api/cards/c1"))
        #expect(body.keys.contains("dueDate"))
        #expect(body["dueDate"] is NSNull)
    }

    @Test("toggleTask flips isCompleted locally and PATCHes the new value")
    func toggleTaskFlips() async {
        let stub = StubHTTPClient()
        stub.routes["GET /api/boards/b1"] = (200, boardJSON)
        stub.routes["PATCH /api/tasks/t1"] = (200, """
        { "item": { "id": "t1", "taskListId": "tl1", "name": "Step 1", "isCompleted": true, "position": 1 } }
        """)
        let vm = makeViewModel(stub)
        await vm.load()
        let task = vm.payload!.tasks.first { $0.id == "t1" }!

        await vm.toggleTask(task)

        #expect(vm.error == nil)
        #expect(vm.payload?.tasks.first { $0.id == "t1" }?.isCompleted == true)
        let body = bodyJSON(stub.lastRequest("PATCH /api/tasks/t1"))
        #expect(body["isCompleted"] as? Bool == true)
    }

    @Test("createTask appends the returned task")
    func createTaskAppends() async {
        let stub = StubHTTPClient()
        stub.routes["GET /api/boards/b1"] = (200, boardJSON)
        stub.routes["POST /api/task-lists/tl1/tasks"] = (200, """
        { "item": { "id": "t2", "taskListId": "tl1", "name": "Step 2", "isCompleted": false, "position": 65537 } }
        """)
        let vm = makeViewModel(stub)
        await vm.load()
        let taskList = vm.payload!.taskLists.first { $0.id == "tl1" }!

        await vm.createTask(in: taskList, name: "Step 2")

        #expect(vm.error == nil)
        #expect(vm.payload?.tasks.count == 2)
        #expect(vm.payload?.tasks.contains { $0.id == "t2" } == true)
    }

    @Test("deleteTask removes the task from the payload")
    func deleteTaskRemoves() async {
        let stub = StubHTTPClient()
        stub.routes["GET /api/boards/b1"] = (200, boardJSON)
        stub.routes["DELETE /api/tasks/t1"] = (200, """
        { "item": { "id": "t1", "taskListId": "tl1", "name": "Step 1", "isCompleted": false, "position": 1 } }
        """)
        let vm = makeViewModel(stub)
        await vm.load()
        let task = vm.payload!.tasks.first { $0.id == "t1" }!

        await vm.deleteTask(task)

        #expect(vm.error == nil)
        #expect(vm.payload?.tasks.isEmpty == true)
    }

    @Test("a failed mutation sets error and leaves the payload unchanged")
    func failedMutationKeepsState() async {
        let stub = StubHTTPClient()
        stub.routes["GET /api/boards/b1"] = (200, boardJSON)
        stub.routes["PATCH /api/cards/c1"] = (403, #"{ "code": "E_FORBIDDEN" }"#)
        let vm = makeViewModel(stub)
        await vm.load()
        let cardC1 = vm.payload!.cards.first { $0.id == "c1" }!
        let list2 = vm.payload!.sortedLists().first { $0.id == "l2" }!

        await vm.moveCard(cardC1, to: list2)

        #expect(vm.error != nil)
        // Optimistic move was not applied — card stays in its original list.
        #expect(vm.payload?.card(id: "c1")?.listId == "l1")
    }
}
