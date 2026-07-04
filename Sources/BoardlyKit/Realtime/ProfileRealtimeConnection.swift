import Foundation

/// The single Socket.IO connection for one server profile. PLANKA multiplexes
/// every subscribed board over one socket (Sails rooms), and the pushed events
/// don't name their board — so this connection **broadcasts** each incremental
/// event to every open board and lets each `BoardPayload` keep only what it owns
/// (`BoardPayload.owns`). A board's `resynced` snapshot, by contrast, is delivered
/// only to that board.
///
/// Bound to one profile. Per CLAUDE.md the socket must never outlive its profile:
/// the owner (`BoardSessionStore`) calls `shutdown()` on profile switch / logout.
public actor ProfileRealtimeConnection {
    private let transport: any SocketTransport
    private let token: String

    /// Live event sinks, one per open board, tagged with the owner that opened it
    /// so a stale `closeBoard` from a torn-down session can't finish a newer one.
    private var streams: [String: (owner: UUID, continuation: AsyncStream<BoardRealtimeEvent>.Continuation)] = [:]
    /// Boards subscribed in the *current* connection — reset on (re)connect and on
    /// full disconnect, so each board is subscribed exactly once per connection.
    private var subscribedBoards: Set<String> = []

    /// Transport handlers are registered once for the connection's whole life —
    /// re-registering on a reconnect would double every callback on the real socket.
    private var handlersRegistered = false
    /// Whether we've told the transport to connect (set synchronously so teardown
    /// decisions don't depend on the async handshake).
    private var transportUp = false
    /// Whether the socket handshake has completed (drives subscribe routing).
    private var connected = false

    public init(transport: any SocketTransport, token: String) {
        self.transport = transport
        self.token = token
    }

    /// Open a board's live event stream over the shared connection. Balance every
    /// call with `closeBoard(_:)`. The first board connects the transport; a board
    /// opened once the socket is up subscribes immediately, and one opened mid-
    /// handshake is picked up when `onConnect` resubscribes everyone.
    public func openBoard(_ boardId: String, owner: UUID) -> AsyncStream<BoardRealtimeEvent> {
        // Unbounded on purpose: the @MainActor consumer drains promptly, and dropping
        // a realtime event would silently diverge board state until the next resync.
        let (stream, continuation) = AsyncStream.makeStream(of: BoardRealtimeEvent.self)
        // Finish any prior sink for this board (a previous session whose teardown
        // hasn't run yet) so it doesn't leak, then take ownership.
        streams[boardId]?.continuation.finish()
        streams[boardId] = (owner, continuation)
        subscribedBoards.remove(boardId) // the new owner must (re)subscribe
        registerHandlersIfNeeded()

        if !transportUp {
            transportUp = true
            transport.connect()
        } else if connected {
            Task { await subscribe(boardId) }
        }
        // else: mid-handshake — `onConnect` will subscribe every open board.
        return stream
    }

    /// Close a board's stream — but only if `owner` still owns it (a stale close
    /// from a replaced session is a no-op). When the last board closes, the
    /// transport is disconnected (kept for reuse — a later `openBoard` reconnects).
    public func closeBoard(_ boardId: String, owner: UUID) {
        guard streams[boardId]?.owner == owner else { return }
        streams[boardId]?.continuation.finish()
        streams[boardId] = nil
        subscribedBoards.remove(boardId)
        guard streams.isEmpty, transportUp else { return }
        disconnectTransport()
        BoardlyLog.tag(.sync).icon("🔌").info("Profile realtime idle — disconnected")
    }

    /// Tear the whole connection down — profile switch / logout.
    public func shutdown() {
        for entry in streams.values { entry.continuation.finish() }
        streams.removeAll()
        if transportUp { disconnectTransport() }
        BoardlyLog.tag(.sync).icon("🔌").info("Profile realtime shut down")
    }

    // MARK: - Transport wiring

    private func disconnectTransport() {
        transport.disconnect()
        transportUp = false
        connected = false
        subscribedBoards.removeAll()
    }

    private func registerHandlersIfNeeded() {
        guard !handlersRegistered else { return }
        handlersRegistered = true

        // Server-pushed resource changes → typed events, fanned out to every board.
        for name in BoardRealtimeEvent.handledNames {
            transport.on(event: name) { [weak self] data in
                guard let event = BoardRealtimeEvent.parse(event: name, payload: data) else { return }
                Task { await self?.broadcast(event) }
            }
        }

        // Every (re)connect must re-issue the subscribe GET for each open board —
        // room membership does not survive a reconnect.
        transport.onConnect { [weak self] in
            Task { await self?.handleConnect() }
        }
    }

    /// Every incremental event goes to every open board; each board's reconciler
    /// keeps only what it owns.
    private func broadcast(_ event: BoardRealtimeEvent) {
        for entry in streams.values { entry.continuation.yield(event) }
    }

    private func handleConnect() {
        connected = true
        // A fresh connection lost all room memberships — re-subscribe everyone.
        subscribedBoards.removeAll()
        for boardId in streams.keys {
            Task { await subscribe(boardId) }
        }
    }

    /// Join a board's room and deliver its fresh payload as `resynced` to that
    /// board only. Idempotent within a connection: a board already subscribed is
    /// skipped (the reservation is taken before the `await` to survive actor
    /// reentrancy).
    private func subscribe(_ boardId: String) async {
        guard streams[boardId] != nil, !subscribedBoards.contains(boardId) else { return }
        subscribedBoards.insert(boardId)

        let request = SailsRequest(
            method: "get",
            url: "/api/boards/\(boardId)?subscribe=true",
            headers: ["Authorization": "Bearer \(token)"])
        do {
            let response = try await transport.request(request)
            guard (200 ... 299).contains(response.statusCode) else {
                subscribedBoards.remove(boardId)
                BoardlyLog.tag(.sync).icon("⚠️").warning(
                    "Subscribe rejected", metadata: ["status": "\(response.statusCode)", "board": boardId])
                return
            }
            let payload = try BoardPayload.decode(from: response.body)
            streams[boardId]?.continuation.yield(.resynced(payload))
            BoardlyLog.tag(.sync).icon("🔄").info("Board (re)subscribed", metadata: ["board": boardId])
        } catch {
            subscribedBoards.remove(boardId)
            BoardlyLog.tag(.sync).icon("❌").error("Subscribe error", error: error, metadata: ["board": boardId])
        }
    }
}
