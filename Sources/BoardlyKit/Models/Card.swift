import Foundation

public struct Card: Codable, Identifiable, Sendable {
    public let id: String
    public let boardId: String
    public let listId: String
    public let creatorUserId: String
    public let prevListId: String?
    public let coverAttachmentId: String?
    public let type: String
    public let position: Double
    public let name: String
    public let description: String?
    public let dueDate: Date?
    public let isDueCompleted: Bool?
    public let stopwatch: AnyCodable?
    public let commentsTotal: Int
    public let isClosed: Bool
    public let listChangedAt: Date?
    public let createdAt: Date?
    public let updatedAt: Date?
}
