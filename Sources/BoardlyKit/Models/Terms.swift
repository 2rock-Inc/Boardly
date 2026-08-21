import Foundation

/// The instance's terms and conditions, as served by `GET /terms`.
///
/// `content` is Markdown authored by whoever runs the server, so it is user data: render
/// it, never localize it. `signature` is what proves *which* text was agreed to — it goes
/// back verbatim in `POST /access-tokens/accept-terms`.
public struct Terms: Codable, Sendable, Equatable {
    public let type: String
    public let language: String
    public let content: String
    public let signature: String

    public init(type: String, language: String, content: String, signature: String) {
        self.type = type
        self.language = language
        self.content = content
        self.signature = signature
    }
}
