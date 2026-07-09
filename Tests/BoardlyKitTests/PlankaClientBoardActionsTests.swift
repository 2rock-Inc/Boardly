import Foundation
import Testing
@testable import BoardlyKit

@Suite("PlankaClient — board action endpoints")
struct PlankaClientBoardActionsTests {
    let profile = makeProfile(baseURL: URL(string: "https://planka.example.com")!)
    let mockHTTP = MockHTTPClient()
    var client: PlankaClient {
        PlankaClient(
            profile: profile,
            tokenStore: TokenStore(profileID: profile.id, keychainStore: MockKeychainStore()),
            httpClient: mockHTTP)
    }

    private func body(of req: URLRequest) throws -> [String: Any] {
        let data = try #require(req.httpBody)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private let boardJSON = #"{"item":{"id":"b1","projectId":"p1","position":1,"name":"Sprint"}}"#
    private let membershipJSON = #"{"item":{"id":"bm1","projectId":"p1","boardId":"b1","userId":"u2","role":"editor"}}"#

    @Test("renameBoard PATCHes /boards/{id} with the new name")
    func renameBoard() async throws {
        mockHTTP.stub(json: boardJSON)
        let board = try await client.renameBoard(id: "b1", name: "Sprint")
        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "PATCH")
        #expect(req.url?.path.hasSuffix("/api/boards/b1") == true)
        #expect(try body(of: req)["name"] as? String == "Sprint")
        #expect(board.name == "Sprint")
    }

    @Test("deleteBoard DELETEs /boards/{id}")
    func deleteBoard() async throws {
        mockHTTP.stub(json: boardJSON)
        try await client.deleteBoard(id: "b1")
        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "DELETE")
        #expect(req.url?.path.hasSuffix("/api/boards/b1") == true)
    }

    @Test("addBoardMember POSTs userId + role to the board")
    func addBoardMember() async throws {
        mockHTTP.stub(json: membershipJSON)
        _ = try await client.addBoardMember(boardId: "b1", userId: "u2")
        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "POST")
        #expect(req.url?.path.hasSuffix("/api/boards/b1/board-memberships") == true)
        #expect(try body(of: req)["userId"] as? String == "u2")
        #expect(try body(of: req)["role"] as? String == "editor")
    }

    @Test("removeBoardMember DELETEs /board-memberships/{id}")
    func removeBoardMember() async throws {
        mockHTTP.stub(json: membershipJSON)
        try await client.removeBoardMember(membershipId: "bm1")
        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "DELETE")
        #expect(req.url?.path.hasSuffix("/api/board-memberships/bm1") == true)
    }
}
