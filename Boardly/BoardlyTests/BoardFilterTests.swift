//
//  BoardFilterTests.swift
//  BoardlyTests
//
//  Client-side board filter (members / labels / due) applied to visible cards.
//

import BoardlyKit
import Foundation
import Testing
@testable import Boardly

/// b1 with two members (u1/u2), two labels (L1/L2) and three cards:
/// - c1: member u1, label L1, overdue
/// - c2: member u2, label L2, no due date
/// - c3: no member, no label, due in the far future
private let boardJSON = """
{
  "item": { "id": "b1", "projectId": "p1", "name": "Board" },
  "included": {
    "users": [
      { "id": "u1", "name": "Alice", "role": "member", "isDeactivated": false },
      { "id": "u2", "name": "Bob", "role": "member", "isDeactivated": false }
    ],
    "boardMemberships": [
      { "id": "bm1", "projectId": "p1", "boardId": "b1", "userId": "u1", "role": "editor" },
      { "id": "bm2", "projectId": "p1", "boardId": "b1", "userId": "u2", "role": "editor" }
    ],
    "labels": [
      { "id": "L1", "boardId": "b1", "name": "Red", "color": "berry-red", "position": 1 },
      { "id": "L2", "boardId": "b1", "name": "Blue", "color": "lagoon-blue", "position": 2 }
    ],
    "lists": [{ "id": "l1", "boardId": "b1", "type": "active", "name": "To Do", "position": 1 }],
    "cards": [
      { "id": "c1", "boardId": "b1", "listId": "l1", "name": "Overdue", "position": 1,
        "dueDate": "2020-01-01T00:00:00.000Z", "isDueCompleted": false },
      { "id": "c2", "boardId": "b1", "listId": "l1", "name": "No due", "position": 2 },
      { "id": "c3", "boardId": "b1", "listId": "l1", "name": "Future", "position": 3,
        "dueDate": "2099-01-01T00:00:00.000Z", "isDueCompleted": false }
    ],
    "cardMemberships": [
      { "id": "cm1", "cardId": "c1", "userId": "u1" },
      { "id": "cm2", "cardId": "c2", "userId": "u2" }
    ],
    "cardLabels": [
      { "id": "cl1", "cardId": "c1", "labelId": "L1" },
      { "id": "cl2", "cardId": "c2", "labelId": "L2" }
    ]
  }
}
"""

private final class StubHTTP: HTTPClient, @unchecked Sendable {
    let json: String
    init(_ json: String) { self.json = json }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (Data(json.utf8), resp)
    }
}

private final class NoKeychain: KeychainStoring, @unchecked Sendable {
    func save(_: String, for _: String) throws {}
    func load(for _: String) throws -> String? { nil }
    func delete(for _: String) throws {}
}

/// Loads the fixture through the real client path (`BoardPayload.decode` is
/// BoardlyKit-internal, so the app can only obtain a payload via `getBoard`).
private func loadPayload() async throws -> BoardPayload {
    let profile = ServerProfile(id: UUID(), name: "T", baseURL: URL(string: "https://planka.example.com")!)
    let tokenStore = TokenStore(profileID: profile.id, keychainStore: NoKeychain())
    let client = PlankaClient(profile: profile, tokenStore: tokenStore, httpClient: StubHTTP(boardJSON))
    return try await client.getBoard(id: "b1")
}

private func matchingIDs(_ filter: BoardFilter, _ p: BoardPayload) -> [String] {
    p.cards.filter { filter.matches($0, in: p) }.map(\.id).sorted()
}

@Suite("BoardFilter — client-side card filtering")
struct BoardFilterTests {
    @Test("an empty filter matches every card")
    func emptyMatchesAll() async throws {
        let p = try await loadPayload()
        #expect(BoardFilter().isActive == false)
        #expect(matchingIDs(BoardFilter(), p) == ["c1", "c2", "c3"])
    }

    @Test("member filter keeps only that member's cards")
    func byMember() async throws {
        let p = try await loadPayload()
        var f = BoardFilter(); f.memberIds = ["u1"]
        #expect(f.isActive)
        #expect(matchingIDs(f, p) == ["c1"])
    }

    @Test("label filter keeps only cards with that label")
    func byLabel() async throws {
        let p = try await loadPayload()
        var f = BoardFilter(); f.labelIds = ["L2"]
        #expect(matchingIDs(f, p) == ["c2"])
    }

    @Test("due filters: overdue / withDue / noDue")
    func byDue() async throws {
        let p = try await loadPayload()
        var overdue = BoardFilter(); overdue.due = .overdue
        #expect(matchingIDs(overdue, p) == ["c1"])
        var hasDue = BoardFilter(); hasDue.due = .hasDue
        #expect(matchingIDs(hasDue, p) == ["c1", "c3"])
        var noDue = BoardFilter(); noDue.due = .noDue
        #expect(matchingIDs(noDue, p) == ["c2"])
    }

    @Test("facets combine with AND")
    func facetsAND() async throws {
        let p = try await loadPayload()
        var f = BoardFilter(); f.memberIds = ["u1"]; f.labelIds = ["L1"]
        #expect(matchingIDs(f, p) == ["c1"])
        // u1 has label L1, not L2 → empty.
        var none = BoardFilter(); none.memberIds = ["u1"]; none.labelIds = ["L2"]
        #expect(matchingIDs(none, p).isEmpty)
    }
}
