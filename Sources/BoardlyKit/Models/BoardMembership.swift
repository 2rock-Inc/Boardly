import Foundation

public struct BoardMembership: Codable, Identifiable, Sendable {
    public let id: String
    public let projectId: String
    public let boardId: String
    public let userId: String
    public let role: String
    public let canComment: Bool
    public let createdAt: Date?
    public let updatedAt: Date?
}
