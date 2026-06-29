import Foundation
import SocketIO

/// The real Socket.IO transport for PLANKA (Socket.IO v4 / Engine.IO 4). This is
/// the only file that imports the third-party SocketIO dependency.
///
/// PLANKA hosts the socket at `<basePath>/socket.io/` on the same origin as the
/// REST API and speaks the Sails virtual-request protocol: emit the lowercased
/// HTTP method as the event name with `{ method, url, headers, data }`, and read
/// the JWR (`{ statusCode, body }`) from the ack.
public final class SocketIOTransport: SocketTransport, @unchecked Sendable {
    private let manager: SocketManager
    private let socket: SocketIOClient
    private let ackTimeout: Double

    public init(baseURL: URL, ackTimeout: Double = 15) {
        self.ackTimeout = ackTimeout

        // Split the user-supplied base URL into origin + subpath, since PLANKA
        // supports subpath hosting (e.g. https://example.com/planka).
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        let basePath = components?.path.hasSuffix("/") == true
            ? String(components!.path.dropLast())
            : (components?.path ?? "")
        components?.path = ""
        let origin = components?.url ?? baseURL

        manager = SocketManager(socketURL: origin, config: [
            .path("\(basePath)/socket.io/"),
            .reconnects(true),
            .log(false),
            .compress,
        ])
        socket = manager.defaultSocket
    }

    public func connect() { socket.connect() }
    public func disconnect() { socket.disconnect() }

    public func onConnect(_ handler: @escaping @Sendable () -> Void) {
        socket.on(clientEvent: .connect) { _, _ in handler() }
    }

    public func onDisconnect(_ handler: @escaping @Sendable () -> Void) {
        socket.on(clientEvent: .disconnect) { _, _ in handler() }
    }

    public func on(event: String, _ handler: @escaping @Sendable (Data) -> Void) {
        socket.on(event) { data, _ in
            guard let payload = data.first,
                  let json = try? JSONSerialization.data(withJSONObject: payload)
            else { return }
            handler(json)
        }
    }

    public func request(_ request: SailsRequest) async throws -> SailsResponse {
        let envelope: [String: Any] = [
            "method": request.method,
            "url": request.url,
            "headers": request.headers,
            "data": [String: Any](),
        ]

        return try await withCheckedThrowingContinuation { continuation in
            socket.emitWithAck(request.method, envelope).timingOut(after: ackTimeout) { ack in
                // Timeout / no ack → SocketIO yields a marker rather than a JWR.
                guard let ctx = ack.first as? [String: Any] else {
                    continuation.resume(throwing: PlankaAPIError.networkError(URLError(.timedOut)))
                    return
                }
                let status = ctx["statusCode"] as? Int ?? 0
                let bodyObject = ctx["body"] ?? [String: Any]()
                let body = (try? JSONSerialization.data(withJSONObject: bodyObject)) ?? Data()
                continuation.resume(returning: SailsResponse(statusCode: status, body: body))
            }
        }
    }
}
