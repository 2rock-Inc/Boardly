import Foundation

public struct BaseCustomFieldGroup: Codable, Identifiable, Sendable {
    public let id: String
    public let projectId: String
    public let name: String
    public let createdAt: Date
    public let updatedAt: Date
}
