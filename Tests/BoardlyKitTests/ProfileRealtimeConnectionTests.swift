import Foundation
import Testing
@testable import BoardlyKit

private final class MockSocketTransport: SocketTransport, @unchecked Sendable {
    private(set) var connectCount = 0
    private(set) var disconnectCount = 0
    private(set) var requests: [SailsRequest] = []
    var requestHandler: (@Sendable (SailsRequest) async throws -> SailsResponse)?

    private var connectHandler: (@Sendable () -> Void)?
    // The connection registers one handler per event name (registered once for the
    // connection's whole life); record how many times, to catch double-registration.
    private(set) var registrationCount = 0
    private var eventHandlers: [String: @Sendable (Data) -> Void] = [:]

    func connect() { connectCount += 1; connectHandler?() }
    func disconnect() { disconnectCount += 1 }
    func onConnect(_ handler: @escaping @Sendable () -> Void) { connectHandler = handler }
    func onDisconnect(_: @escaping @Sendable () -> Void) {}
    func on(event: String, _ handler: @escaping @Sendable (Data) -> Void) {
        registrationCount += 1
        eventHandlers[event] = handler
    }

    func request(_ request: SailsRequest) async throws -> SailsResponse {
        requests.append(request)
        return try await requestHandler!(request)
    }

    // Test helpers
    func simulateReconnect() { connect() }
    func push(event: String, json: String) { eventHandlers[event]?(Data(json.utf8)) }
}

private func boardBody(_ id: String) -> String {
    """
    { "item": { "id": "\(id)", "projectId": "p1", "name": "Board" },
      "included": { "lists": [], "cards": [{ "id": "card-\(id)", "boardId": "\(id)", "listId": "l1", "name": "X" }],
                    "taskLists": [], "tasks": [] } }
    """
}

@Suite("ProfileRealtimeConnection — shared per-profile socket")
struct ProfileRealtimeConnectionTests {
    private func makeConnection() -> (ProfileRealtimeConnection, MockSocketTransport) {
        let transport = MockSocketTransport()
        transport.requestHandler = { request in
            let id = request.url.contains("/b2?") ? "b2" : "b1"
            return SailsResponse(statusCode: 200, body: Data(boardBody(id).utf8))
        }
        return (ProfileRealtimeConnection(transport: transport, token: "tok"), transport)
    }

    @Test("opening a board subscribes on connect and emits resynced with the auth header")
    func subscribesOnConnect() async {
        let (connection, transport) = makeConnection()
        let stream = await connection.openBoard("b1", owner: UUID())
        var it = stream.makeAsyncIterator()

        let first = await it.next()
        guard case let .resynced(payload) = first else { Issue.record("expected resynced"); return }
        #expect(payload.board.id == "b1")
        #expect(transport.connectCount == 1)
        #expect(transport.requests.first?.url == "/api/boards/b1?subscribe=true")
        #expect(transport.requests.first?.headers["Authorization"] == "Bearer tok")
    }

    @Test("re-subscribes every open board on reconnect")
    func reSubscribesOnReconnect() async {
        let (connection, transport) = makeConnection()
        let stream = await connection.openBoard("b1", owner: UUID())
        var it = stream.makeAsyncIterator()

        _ = await it.next() // initial resync
        transport.simulateReconnect()
        let second = await it.next()
        guard case .resynced = second else { Issue.record("expected second resynced"); return }
        #expect(transport.requests.count == 2)
    }

    @Test("multiplexes two boards over one connection: broadcast events, board-scoped resync")
    func multiplexesBoards() async {
        let (connection, transport) = makeConnection()

        let s1 = await connection.openBoard("b1", owner: UUID())
        var it1 = s1.makeAsyncIterator()
        let first1 = await it1.next()

        let s2 = await connection.openBoard("b2", owner: UUID())
        var it2 = s2.makeAsyncIterator()
        let first2 = await it2.next()

        // One physical connection; handlers registered exactly once per event name.
        #expect(transport.connectCount == 1)
        #expect(transport.registrationCount == BoardRealtimeEvent.handledNames.count)

        // Resync is board-scoped.
        guard case let .resynced(p1) = first1, case let .resynced(p2) = first2 else {
            Issue.record("expected a resync per board"); return
        }
        #expect(p1.board.id == "b1")
        #expect(p2.board.id == "b2")

        // An incremental event is broadcast to every open board (each reconciler
        // then keeps only what it owns).
        transport.push(event: "cardUpdate", json: #"{"item":{"id":"c1","position":9}}"#)
        let e1 = await it1.next()
        let e2 = await it2.next()
        guard case .cardUpdated = e1, case .cardUpdated = e2 else {
            Issue.record("both boards should receive the broadcast"); return
        }
    }

    @Test("the transport stays up until the last board closes")
    func lastCloseDisconnects() async {
        let (connection, transport) = makeConnection()
        let ownerB1 = UUID(), ownerB2 = UUID()
        _ = await connection.openBoard("b1", owner: ownerB1)
        _ = await connection.openBoard("b2", owner: ownerB2)

        await connection.closeBoard("b1", owner: ownerB1)
        #expect(transport.disconnectCount == 0, "b2 still open")

        await connection.closeBoard("b2", owner: ownerB2)
        #expect(transport.disconnectCount == 1, "last board closed")
    }

    @Test("closing a board finishes its stream")
    func closeFinishesStream() async {
        let (connection, _) = makeConnection()
        let owner = UUID()
        let stream = await connection.openBoard("b1", owner: owner)
        var it = stream.makeAsyncIterator()
        _ = await it.next() // resync

        await connection.closeBoard("b1", owner: owner)
        let next = await it.next()
        #expect(next == nil)
    }

    @Test("shutdown disconnects and finishes every stream")
    func shutdownTearsEverythingDown() async {
        let (connection, transport) = makeConnection()
        let s1 = await connection.openBoard("b1", owner: UUID())
        let s2 = await connection.openBoard("b2", owner: UUID())
        var it1 = s1.makeAsyncIterator()
        var it2 = s2.makeAsyncIterator()
        _ = await it1.next()
        _ = await it2.next()

        await connection.shutdown()
        #expect(transport.disconnectCount == 1)
        #expect(await it1.next() == nil)
        #expect(await it2.next() == nil)
    }

    @Test("a stale close from a replaced session doesn't kill the reopened stream")
    func staleCloseIsIgnored() async {
        let (connection, transport) = makeConnection()

        let ownerA = UUID()
        let sA = await connection.openBoard("b1", owner: ownerA)
        var itA = sA.makeAsyncIterator()
        _ = await itA.next() // resync A

        // Reopen the same board with a new owner before A's teardown runs.
        let ownerB = UUID()
        let sB = await connection.openBoard("b1", owner: ownerB)
        var itB = sB.makeAsyncIterator()
        _ = await itB.next() // resync B

        // Reopen finished A's orphaned stream.
        #expect(await itA.next() == nil)

        // A's late close must be a no-op — B stays live and keeps receiving events.
        await connection.closeBoard("b1", owner: ownerA)
        transport.push(event: "cardUpdate", json: #"{"item":{"id":"c1","position":5}}"#)
        guard case .cardUpdated = await itB.next() else {
            Issue.record("B should still be live after A's stale close"); return
        }
    }
}
