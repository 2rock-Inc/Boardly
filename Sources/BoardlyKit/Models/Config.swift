import Foundation

public struct Config: Codable, Identifiable, Sendable {
    public let id: String
    public let smtpHost: String?
    public let smtpPort: Int?
    public let smtpName: String?
    public let smtpSecure: Bool?
    public let smtpTlsRejectUnauthorized: Bool?
    public let smtpUser: String?
    public let smtpPassword: String?
    public let smtpFrom: String?
    public let createdAt: Date?
    public let updatedAt: Date?
}
