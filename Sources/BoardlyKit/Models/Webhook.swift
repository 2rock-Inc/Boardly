import Foundation

public struct Webhook: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let url: String
    public let accessToken: String
    public let events: [String]
    public let excludedEvents: [String]
    public let createdAt: Date
    public let updatedAt: Date
}
