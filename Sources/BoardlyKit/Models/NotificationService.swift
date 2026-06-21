import Foundation

public struct NotificationService: Codable, Identifiable, Sendable {
    public let id: String
    public let userId: String
    public let boardId: String?
    public let url: String
    public let format: String
    public let createdAt: Date?
    public let updatedAt: Date?
}
