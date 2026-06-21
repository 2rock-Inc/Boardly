import Foundation

public struct Comment: Codable, Identifiable, Sendable {
    public let id: String
    public let cardId: String
    public let userId: String
    public let text: String
    public let createdAt: Date?
    public let updatedAt: Date?
}
