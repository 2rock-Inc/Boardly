import Foundation

public struct CustomFieldGroup: Codable, Identifiable, Sendable {
    public let id: String
    public let boardId: String?
    public let cardId: String?
    public let baseCustomFieldGroupId: String
    public let position: Double
    public let name: String
    public let createdAt: Date
    public let updatedAt: Date
}
