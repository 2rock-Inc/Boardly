import Foundation

public struct PlankaTask: Codable, Identifiable, Sendable {
    public let id: String
    public let taskListId: String
    public let linkedCardId: String?
    public let assigneeUserId: String?
    public let position: Double?
    public let name: String
    public let isCompleted: Bool
    public let createdAt: Date?
    public let updatedAt: Date?
}
