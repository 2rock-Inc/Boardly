import Foundation

public struct Action: Codable, Identifiable, Sendable {
    public let id: String
    public let boardId: String?
    public let cardId: String
    public let userId: String?
    public let type: String
    public let data: AnyCodable
    public let createdAt: Date?
    public let updatedAt: Date?
}
