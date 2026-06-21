import Foundation

public struct TaskList: Codable, Identifiable, Sendable {
    public let id: String
    public let cardId: String
    public let position: Double?
    public let name: String
    public let showOnFrontOfCard: Bool
    public let hideCompletedTasks: Bool
    public let createdAt: Date?
    public let updatedAt: Date?
}
