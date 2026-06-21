import Testing
import Foundation
@testable import BoardlyKit

@Suite("PlankaClient — Phase 2 endpoints")
struct PlankaClientPhase2Tests {
    let profile: ServerProfile
    let mockHTTP: MockHTTPClient
    let client: PlankaClient

    init() {
        profile = makeProfile(baseURL: URL(string: "https://planka.example.com")!)
        mockHTTP = MockHTTPClient()
        let tokenStore = TokenStore(profileID: profile.id, keychainStore: MockKeychainStore())
        client = PlankaClient(profile: profile, tokenStore: tokenStore, httpClient: mockHTTP)
    }

    // MARK: - getProjects

    @Test("getProjects sends GET /api/projects")
    func getProjectsSendsCorrectRequest() async throws {
        mockHTTP.stub(data: loadFixture("projects"))
        _ = try await client.getProjects()
        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "GET")
        #expect(req.url?.path.hasSuffix("/api/projects") == true)
    }

    @Test("getProjects returns parsed projects and boards")
    func getProjectsParsesPayload() async throws {
        mockHTTP.stub(data: loadFixture("projects"))
        let payload = try await client.getProjects()
        #expect(payload.projects.count == 1)
        #expect(payload.projects[0].name == "My Project")
        #expect(payload.boards.count == 1)
        #expect(payload.boards[0].name == "Sprint 1")
    }

    // MARK: - getBoard

    @Test("getBoard sends GET /api/boards/{id}")
    func getBoardSendsCorrectRequest() async throws {
        mockHTTP.stub(data: loadFixture("board_detail"))
        _ = try await client.getBoard(id: "board-001")
        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "GET")
        #expect(req.url?.path.hasSuffix("/api/boards/board-001") == true)
    }

    @Test("getBoard returns parsed BoardPayload")
    func getBoardParsesIncluded() async throws {
        mockHTTP.stub(data: loadFixture("board_detail"))
        let payload = try await client.getBoard(id: "board-001")
        #expect(payload.board.name == "Sprint 1")
        #expect(payload.lists.count == 4)  // raw: 2 active + 1 archive + 1 trash
        #expect(payload.sortedLists().count == 2)  // only active lists shown
        #expect(payload.cards.count == 2)
        #expect(payload.taskLists.count == 1)
        #expect(payload.tasks.count == 2)
    }

    // MARK: - createCard

    @Test("createCard sends POST /api/lists/{id}/cards with name and position")
    func createCardRequest() async throws {
        let cardJSON = #"{"item":{"id":"c-new","boardId":"b1","listId":"l1","creatorUserId":"u1","prevListId":null,"coverAttachmentId":null,"type":"project","position":65536,"name":"New Card","description":null,"dueDate":null,"isDueCompleted":null,"stopwatch":null,"commentsTotal":0,"isClosed":false,"listChangedAt":null,"createdAt":"2024-01-01T10:00:00.000Z","updatedAt":"2024-01-01T10:00:00.000Z"}}"#
        mockHTTP.stub(json: cardJSON)
        let card = try await client.createCard(listId: "l1", name: "New Card", position: 65536)

        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "POST")
        #expect(req.url?.path.hasSuffix("/api/lists/l1/cards") == true)
        let body = try #require(req.httpBody)
        let json = try JSONDecoder().decode([String: AnyCodable].self, from: body)
        #expect(json["name"]?.value as? String == "New Card")
        #expect(card.name == "New Card")
    }

    // MARK: - updateCard

    @Test("updateCard sends PATCH /api/cards/{id}")
    func updateCardRequest() async throws {
        let cardJSON = #"{"item":{"id":"c1","boardId":"b1","listId":"l2","creatorUserId":"u1","prevListId":null,"coverAttachmentId":null,"type":"project","position":65536,"name":"Updated","description":null,"dueDate":null,"isDueCompleted":null,"stopwatch":null,"commentsTotal":0,"isClosed":false,"listChangedAt":null,"createdAt":"2024-01-01T10:00:00.000Z","updatedAt":"2024-01-01T10:00:00.000Z"}}"#
        mockHTTP.stub(json: cardJSON)
        let patch = CardPatch(listId: "l2")
        _ = try await client.updateCard(id: "c1", patch: patch)

        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "PATCH")
        #expect(req.url?.path.hasSuffix("/api/cards/c1") == true)
    }

    // MARK: - updateTask

    @Test("updateTask sends PATCH /api/tasks/{id} with isCompleted")
    func updateTaskRequest() async throws {
        let taskJSON = #"{"item":{"id":"t1","taskListId":"tl1","linkedCardId":null,"assigneeUserId":null,"position":65536,"name":"Write tests","isCompleted":true,"createdAt":"2024-01-01T10:00:00.000Z","updatedAt":"2024-01-01T10:00:00.000Z"}}"#
        mockHTTP.stub(json: taskJSON)
        let task = try await client.updateTask(id: "t1", patch: TaskPatch(isCompleted: true))

        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "PATCH")
        #expect(req.url?.path.hasSuffix("/api/tasks/t1") == true)
        #expect(task.isCompleted == true)
    }

    // MARK: - deleteCard

    @Test("deleteCard sends DELETE /api/cards/{id}")
    func deleteCardRequest() async throws {
        let cardJSON = #"{"item":{"id":"c1","boardId":"b1","listId":"l1","creatorUserId":"u1","prevListId":null,"coverAttachmentId":null,"type":"project","position":65536,"name":"Old","description":null,"dueDate":null,"isDueCompleted":null,"stopwatch":null,"commentsTotal":0,"isClosed":false,"listChangedAt":null,"createdAt":"2024-01-01T10:00:00.000Z","updatedAt":"2024-01-01T10:00:00.000Z"}}"#
        mockHTTP.stub(json: cardJSON)
        try await client.deleteCard(id: "c1")
        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "DELETE")
        #expect(req.url?.path.hasSuffix("/api/cards/c1") == true)
    }
}
