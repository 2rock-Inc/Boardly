import Foundation

public struct User: Codable, Identifiable, Sendable {
    public let id: String
    public let email: String?
    public let role: String
    public let name: String
    public let username: String
    public let avatar: AnyCodable?
    public let gravatarUrl: String?
    public let phone: String
    public let organization: String
    public let language: String?
    public let apiKeyPrefix: String?
    public let subscribeToOwnCards: Bool?
    public let subscribeToCardWhenCommenting: Bool?
    public let turnOffRecentCardHighlighting: Bool?
    public let enableFavoritesByDefault: Bool?
    public let defaultEditorMode: String?
    public let defaultHomeView: String?
    public let defaultProjectsOrder: String?
    public let isSsoUser: Bool?
    public let isDeactivated: Bool
    public let isDefaultAdmin: Bool?
    public let createdAt: Date
    public let updatedAt: Date
}
