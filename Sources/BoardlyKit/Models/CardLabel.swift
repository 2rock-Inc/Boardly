import Foundation

public struct CardLabel: Codable, Identifiable, Sendable {
    public let id: String
    public let cardId: String
    public let labelId: String
    public let createdAt: Date
    public let updatedAt: Date
}
