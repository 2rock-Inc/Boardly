import Foundation

public struct BackgroundImage: Codable, Identifiable, Sendable {
    public let id: String
    public let projectId: String
    public let size: String
    public let url: String
    public let thumbnailUrls: AnyCodable
    public let createdAt: Date?
    public let updatedAt: Date?
}
