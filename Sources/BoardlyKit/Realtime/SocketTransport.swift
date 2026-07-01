import Foundation

/// A Sails "virtual request" sent over the socket (the same shape sails.io.js
/// emits): the event name is the lowercased HTTP method, the payload carries
/// the url/headers/data.
public struct SailsRequest: Sendable {
    public let method: String
    public let url: String
    public let headers: [String: String]

    public init(method: String, url: String, headers: [String: String]) {
        self.method = method
        self.url = url
        self.headers = headers
    }
}

/// The JSON-WebSocket-Response (JWR) returned in the Socket.IO ack.
public struct SailsResponse: Sendable {
    public let statusCode: Int
    public let body: Data

    public init(statusCode: Int, body: Data) {
        self.statusCode = statusCode
        self.body = body
    }
}

/// Abstracts the Socket.IO transport so the realtime client can be tested
/// against a mock with no real connection. The real implementation
/// (`SocketIOTransport`) is the only place the third-party SocketIO dependency
/// is used.
public protocol SocketTransport: Sendable {
    func connect()
    func disconnect()
    /// Emit a Sails virtual request and await its JWR ack.
    func request(_ request: SailsRequest) async throws -> SailsResponse
    /// Register a handler for a server-pushed event. The handler receives the
    /// raw JSON payload (`{ item: … }`) as `Data`.
    func on(event: String, _ handler: @escaping @Sendable (Data) -> Void)
    /// Called whenever the socket (re)connects, including after a reconnect.
    func onConnect(_ handler: @escaping @Sendable () -> Void)
    /// Called whenever the socket disconnects.
    func onDisconnect(_ handler: @escaping @Sendable () -> Void)
}
