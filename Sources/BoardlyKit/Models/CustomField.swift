import Foundation

public struct CustomField: Codable, Identifiable, Sendable {
    public let id: String
    public let baseCustomFieldGroupId: String?
    public let customFieldGroupId: String?
    public let position: Double?
    public let name: String
    public let showOnFrontOfCard: Bool?
    public let createdAt: Date?
    public let updatedAt: Date?
}
