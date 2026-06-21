import Foundation

public struct Attachment: Codable, Identifiable, Sendable {
    public let id: String
    public let cardId: String
    public let creatorUserId: String
    public let type: String
    public let data: AnyCodable
    public let name: String
    public let createdAt: Date?
    public let updatedAt: Date?
}
