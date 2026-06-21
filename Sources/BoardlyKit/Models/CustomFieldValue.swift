import Foundation

public struct CustomFieldValue: Codable, Identifiable, Sendable {
    public let id: String
    public let cardId: String
    public let customFieldGroupId: String
    public let customFieldId: String
    public let content: String?
    public let createdAt: Date?
    public let updatedAt: Date?
}
