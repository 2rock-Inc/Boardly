import Foundation

public struct ServerProfile: Codable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var baseURL: URL

    public init(id: UUID = UUID(), name: String, baseURL: URL) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
    }
}
