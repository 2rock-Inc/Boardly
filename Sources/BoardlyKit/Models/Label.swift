import Foundation

public struct Label: Codable, Identifiable, Sendable {
    public let id: String
    public let boardId: String
    public let position: Double?
    public let name: String?
    public let color: String
    public let createdAt: Date?
    public let updatedAt: Date?
}
