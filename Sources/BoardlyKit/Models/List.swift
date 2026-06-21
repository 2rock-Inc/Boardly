import Foundation

public struct PlankaList: Codable, Identifiable, Sendable {
    public let id: String
    public let boardId: String
    public let type: String?
    public let position: Double
    public let name: String
    public let color: String?
    public let createdAt: Date
    public let updatedAt: Date
}
