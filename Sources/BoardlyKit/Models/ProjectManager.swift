import Foundation

public struct ProjectManager: Codable, Identifiable, Sendable {
    public let id: String
    public let projectId: String
    public let userId: String
    public let createdAt: Date?
    public let updatedAt: Date?
}
