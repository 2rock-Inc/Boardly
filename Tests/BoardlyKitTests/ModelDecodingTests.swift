import Foundation
import Testing
@testable import BoardlyKit

@Suite("Model Decoding")
struct ModelDecodingTests {
    @Test("Decode User from fixture")
    func decodeUser() throws {
        let data = loadFixture("user")
        struct Wrapper: Decodable { let item: User }
        let wrapper = try JSONDecoder.planka.decode(Wrapper.self, from: data)
        let user = wrapper.item

        #expect(user.id == "user-abc-123")
        #expect(user.email == "alice@example.com")
        #expect(user.role == "admin")
        #expect(user.name == "Alice Smith")
        #expect(user.username == "alice")
        #expect(user.isDeactivated == false)
        #expect(user.isDefaultAdmin == true)
        #expect(user.organization == "Acme Corp")
    }

    @Test("Decode Project from fixture")
    func decodeProject() throws {
        let data = loadFixture("project")
        struct Wrapper: Decodable { let item: Project }
        let wrapper = try JSONDecoder.planka.decode(Wrapper.self, from: data)
        let project = wrapper.item

        #expect(project.id == "project-xyz-456")
        #expect(project.name == "My Project")
        #expect(project.backgroundImageId == nil)
        #expect(project.isHidden == false)
    }

    @Test("Decode Board from fixture")
    func decodeBoard() throws {
        let data = loadFixture("board")
        struct Wrapper: Decodable { let item: Board }
        let wrapper = try JSONDecoder.planka.decode(Wrapper.self, from: data)
        let board = wrapper.item

        #expect(board.id == "board-abc-789")
        #expect(board.name == "Sprint 1")
        #expect(board.projectId == "project-xyz-456")
    }

    @Test("Decode List from board fixture")
    func decodeList() throws {
        let data = loadFixture("board")
        struct Included: Decodable { let lists: [PlankaList] }
        struct Wrapper: Decodable { let included: Included }
        let wrapper = try JSONDecoder.planka.decode(Wrapper.self, from: data)

        #expect(wrapper.included.lists.count == 1)
        let list = wrapper.included.lists[0]
        #expect(list.id == "list-001")
        #expect(list.name == "To Do")
        #expect(list.color == nil)
    }

    @Test("Decode Card from board fixture with nullable fields")
    func decodeCard() throws {
        let data = loadFixture("board")
        struct Included: Decodable { let cards: [Card] }
        struct Wrapper: Decodable { let included: Included }
        let wrapper = try JSONDecoder.planka.decode(Wrapper.self, from: data)

        #expect(wrapper.included.cards.count == 1)
        let card = wrapper.included.cards[0]
        #expect(card.id == "card-001")
        #expect(card.name == "Implement login")
        #expect(card.description == nil)
        #expect(card.dueDate == nil)
        #expect(card.prevListId == nil)
        #expect(card.isClosed == false)
    }

    @Test("Decode Bootstrap from fixture")
    func decodeBootstrap() throws {
        let data = loadFixture("bootstrap")
        struct Response: Decodable { let item: Bootstrap }
        let bootstrap = try JSONDecoder.planka.decode(Response.self, from: data).item

        #expect(bootstrap.version == "2.0.1")
        #expect(bootstrap.oidc == nil)
    }

    @Test("Date decoding handles ISO8601 with fractional seconds")
    func decodeFractionalDate() throws {
        let json = """
        {
          "id": "u1", "email": null, "role": "member", "name": "Bob", "username": "bob",
          "avatar": null, "gravatarUrl": null, "phone": "", "organization": "",
          "isDeactivated": false,
          "createdAt": "2024-03-15T14:22:33.456Z",
          "updatedAt": "2024-03-15T14:22:33.456Z"
        }
        """.data(using: .utf8)!
        let user = try JSONDecoder.planka.decode(User.self, from: json)
        #expect(user.name == "Bob")
        // Verify the date was parsed (not nil/epoch)
        #expect((user.createdAt?.timeIntervalSince1970 ?? 0) > 0)
    }
}
