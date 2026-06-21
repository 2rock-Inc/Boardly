import Foundation

public struct PlankaNotification: Codable, Identifiable, Sendable {
    public let id: String
    public let userId: String
    public let creatorUserId: String
    public let boardId: String
    public let cardId: String
    public let commentId: String?
    public let actionId: String?
    public let type: String
    public let data: AnyCodable
    public let isRead: Bool
    public let createdAt: Date
    public let updatedAt: Date
}
