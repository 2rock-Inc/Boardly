import Foundation
import Testing
@testable import BoardlyKit

@Suite("BoardPayload — rich card content")
struct RichCardPayloadTests {
    private let json = """
    {
      "item": { "id": "b1", "projectId": "p1", "name": "Board" },
      "included": {
        "lists": [{ "id": "l1", "boardId": "b1", "type": "active", "name": "L", "position": 1 }],
        "cards": [{ "id": "c1", "boardId": "b1", "listId": "l1", "name": "Card", "position": 1 }],
        "taskLists": [], "tasks": [],
        "labels": [
          { "id": "lb1", "boardId": "b1", "name": "Design", "color": "berry-red", "position": 1 },
          { "id": "lb2", "boardId": "b1", "name": "Priority", "color": "pumpkin-orange", "position": 2 }
        ],
        "cardLabels": [{ "id": "cl1", "cardId": "c1", "labelId": "lb1" }],
        "users": [
          { "id": "u1", "role": "admin", "name": "Alice Johnson", "isDeactivated": false },
          { "id": "u2", "role": "member", "name": "Bob Williams", "isDeactivated": false }
        ],
        "cardMemberships": [{ "id": "cm1", "cardId": "c1", "userId": "u1", "role": "editor" }],
        "attachments": [{ "id": "a1", "cardId": "c1", "type": "file", "data": { "url": "x" }, "name": "mockup.png" }],
        "boardMemberships": [
          { "id": "bm1", "projectId": "p1", "boardId": "b1", "userId": "u1", "role": "editor" },
          { "id": "bm2", "projectId": "p1", "boardId": "b1", "userId": "u2", "role": "editor" }
        ]
      }
    }
    """

    private func decoded() throws -> (BoardPayload, Card) {
        let payload = try BoardPayload.decode(from: Data(json.utf8))
        let card = try #require(payload.card(id: "c1"))
        return (payload, card)
    }

    @Test("decode sideloads attachments, memberships and labels")
    func decodeSideloads() throws {
        let (payload, _) = try decoded()
        #expect(payload.attachments.count == 1)
        #expect(payload.boardMemberships.count == 2)
        #expect(payload.labels.count == 2)
    }

    @Test("labels(for:) resolves assigned labels only")
    func labelsForCard() throws {
        let (payload, card) = try decoded()
        #expect(payload.labels(for: card).map(\.id) == ["lb1"])
    }

    @Test("members(for:) resolves assigned users")
    func membersForCard() throws {
        let (payload, card) = try decoded()
        #expect(payload.members(for: card).map(\.id) == ["u1"])
    }

    @Test("attachments(for:) filters by card")
    func attachmentsForCard() throws {
        let (payload, card) = try decoded()
        #expect(payload.attachments(for: card).map(\.id) == ["a1"])
    }

    @Test("boardMembers() lists board-member users")
    func boardMembers() throws {
        let (payload, _) = try decoded()
        #expect(Set(payload.boardMembers().map(\.id)) == ["u1", "u2"])
    }
}
