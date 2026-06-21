import Foundation

public struct Board: Codable, Identifiable, Sendable {
    public let id: String
    public let projectId: String
    public let position: Double
    public let name: String
    public let defaultView: String
    public let defaultCardType: String
    public let limitCardTypesToDefaultOne: Bool
    public let alwaysDisplayCardCreator: Bool
    public let expandTaskListsByDefault: Bool
    public let createdAt: Date
    public let updatedAt: Date
}
