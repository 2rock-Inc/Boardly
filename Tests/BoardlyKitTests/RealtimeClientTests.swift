import Foundation
import Testing
@testable import BoardlyKit

private final class MockSocketTransport: SocketTransport, @unchecked Sendable {
    private(set) var connectCount = 0
    private(set) var disconnectCount = 0
    private(set) var requests: [SailsRequest] = []
    var requestHandler: (@Sendable (SailsRequest) async throws -> SailsResponse)?

    private var connectHandler: (@Sendable () -> Void)?
    private var eventHandlers: [String: @Sendable (Data) -> Void] = [:]

    func connect() { connectCount += 1; connectHandler?() }
    func disconnect() { disconnectCount += 1 }
    func onConnect(_ handler: @escaping @Sendable () -> Void) { connectHandler = handler }
    func onDisconnect(_: @escaping @Sendable () -> Void) {}
    func on(event: String, _ handler: @escaping @Sendable (Data) -> Void) { eventHandlers[event] = handler }

    func request(_ request: SailsRequest) async throws -> SailsResponse {
        requests.append(request)
        return try await requestHandler!(request)
    }

    // Test helpers
    func simulateReconnect() { connect() }
    func push(event: String, json: String) { eventHandlers[event]?(Data(json.utf8)) }
}

private let boardBody = """
{ "item": { "id": "b1", "projectId": "p1", "name": "Board" },
  "included": { "lists": [], "cards": [{ "id": "c1", "boardId": "b1", "listId": "l1", "name": "X" }],
                "taskLists": [], "tasks": [] } }
"""

@Suite("BoardRealtimeClient lifecycle")
struct RealtimeClientTests {
    private func makeClient() -> (BoardRealtimeClient, MockSocketTransport) {
        let transport = MockSocketTransport()
        transport.requestHandler = { _ in SailsResponse(statusCode: 200, body: Data(boardBody.utf8)) }
        return (BoardRealtimeClient(transport: transport, boardId: "b1", token: "tok"), transport)
    }

    @Test("subscribes on connect and emits resynced with the auth header")
    func subscribesOnConnect() async {
        let (client, transport) = makeClient()
        let stream = await client.start()
        var it = stream.makeAsyncIterator()

        let first = await it.next()
        guard case let .resynced(payload) = first else { Issue.record("expected resynced"); return }
        #expect(payload.cards.count == 1)
        #expect(transport.requests.count == 1)
        #expect(transport.requests.first?.url == "/api/boards/b1?subscribe=true")
        #expect(transport.requests.first?.headers["Authorization"] == "Bearer tok")
    }

    @Test("re-subscribes on reconnect")
    func reSubscribesOnReconnect() async {
        let (client, transport) = makeClient()
        let stream = await client.start()
        var it = stream.makeAsyncIterator()

        _ = await it.next() // initial resync
        transport.simulateReconnect()
        let second = await it.next()
        guard case .resynced = second else { Issue.record("expected second resynced"); return }
        #expect(transport.requests.count == 2)
    }

    @Test("server-pushed events surface as typed events")
    func pushesResourceEvents() async {
        let (client, transport) = makeClient()
        let stream = await client.start()
        var it = stream.makeAsyncIterator()

        _ = await it.next() // resync
        transport.push(event: "cardUpdate", json: #"{"item":{"id":"c1","position":42}}"#)
        let event = await it.next()
        guard case let .cardUpdated(partial) = event else { Issue.record("expected cardUpdated"); return }
        #expect(partial.id == "c1")
        #expect(partial.position == 42)
    }

    @Test("stop disconnects the transport and finishes the stream")
    func stopDisconnects() async {
        let (client, transport) = makeClient()
        let stream = await client.start()
        var it = stream.makeAsyncIterator()
        _ = await it.next() // resync

        await client.stop()
        #expect(transport.disconnectCount == 1)
        let next = await it.next()
        #expect(next == nil) // stream finished
    }
}
