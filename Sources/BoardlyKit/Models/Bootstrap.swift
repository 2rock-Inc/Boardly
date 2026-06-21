import Foundation

public struct Bootstrap: Codable, Sendable {
    public let version: String
    public let oidc: OIDCConfig?
    public let activeUsersLimit: Int?
    public let customerPanelUrl: String?
    public let termsLanguages: [String]?

    public struct OIDCConfig: Codable, Sendable {
        public let authorizationUrl: String
        public let endSessionUrl: String?
        public let isEnforced: Bool
    }
}
