import Foundation

/// Drives live sync for a single open board: connects the socket, (re)subscribes
/// on every (re)connect, and surfaces typed events as an `AsyncStream`.
///
/// Bound to one server profile + board. Per CLAUDE.md it must be torn down when
/// leaving the board or switching profiles — never reused across profiles.
public actor BoardRealtimeClient {
    private let transport: any SocketTransport
    private let boardId: String
    private let token: String
    private var continuation: AsyncStream<BoardRealtimeEvent>.Continuation?

    public init(transport: any SocketTransport, boardId: String, token: String) {
        self.transport = transport
        self.boardId = boardId
        self.token = token
    }

    /// Connect and return the live event stream. Call once per client.
    public func start() -> AsyncStream<BoardRealtimeEvent> {
        let (stream, continuation) = AsyncStream.makeStream(of: BoardRealtimeEvent.self)
        self.continuation = continuation

        // Server-pushed resource changes → typed events on the stream.
        for name in BoardRealtimeEvent.handledNames {
            transport.on(event: name) { data in
                if let event = BoardRealtimeEvent.parse(event: name, payload: data) {
                    continuation.yield(event)
                }
            }
        }

        // Every (re)connect must re-issue the subscribe GET to (re)join the
        // board room — room membership does not survive a reconnect.
        transport.onConnect { [weak self] in
            Task { await self?.subscribe() }
        }

        transport.connect()
        return stream
    }

    /// Tear down the connection and finish the stream.
    public func stop() {
        transport.disconnect()
        continuation?.finish()
        continuation = nil
        BoardlyLog.tag(.sync).icon("🔌").info("Realtime stopped", metadata: ["board": boardId])
    }

    private func subscribe() async {
        let request = SailsRequest(
            method: "get",
            url: "/api/boards/\(boardId)?subscribe=true",
            headers: ["Authorization": "Bearer \(token)"]
        )
        do {
            let response = try await transport.request(request)
            guard (200 ... 299).contains(response.statusCode) else {
                BoardlyLog.tag(.sync).icon("⚠️").warning(
                    "Subscribe rejected", metadata: ["status": "\(response.statusCode)", "board": boardId]
                )
                return
            }
            let payload = try BoardPayload.decode(from: response.body)
            continuation?.yield(.resynced(payload))
            BoardlyLog.tag(.sync).icon("🔄").info("Board (re)subscribed", metadata: ["board": boardId])
        } catch {
            BoardlyLog.tag(.sync).icon("❌").error("Subscribe error", error: error, metadata: ["board": boardId])
        }
    }
}
