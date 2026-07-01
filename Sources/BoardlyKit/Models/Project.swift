import Foundation

public struct Project: Codable, Identifiable, Sendable {
    public let id: String
    public let ownerProjectManagerId: String?
    public let backgroundImageId: String?
    public let name: String
    public let description: String?
    public let backgroundType: String?
    public let backgroundGradient: String?
    public let isHidden: Bool
    /// Personal flag returned by `GET /projects` — whether the current user
    /// favorited this project. Absent from the base schema, hence optional.
    public let isFavorite: Bool?
    public let createdAt: Date?
    public let updatedAt: Date?
}
