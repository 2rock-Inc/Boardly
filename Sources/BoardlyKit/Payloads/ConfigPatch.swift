import Foundation

/// Body for `PATCH /config` (admin only). Every field is optional; only the
/// ones set are sent, so a partial SMTP update leaves the rest untouched.
public struct ConfigPatch: Encodable, Sendable {
    public var smtpHost: String?
    public var smtpPort: Int?
    public var smtpName: String?
    public var smtpSecure: Bool?
    public var smtpTlsRejectUnauthorized: Bool?
    public var smtpUser: String?
    public var smtpPassword: String?
    public var smtpFrom: String?

    public init(
        smtpHost: String? = nil,
        smtpPort: Int? = nil,
        smtpName: String? = nil,
        smtpSecure: Bool? = nil,
        smtpTlsRejectUnauthorized: Bool? = nil,
        smtpUser: String? = nil,
        smtpPassword: String? = nil,
        smtpFrom: String? = nil
    ) {
        self.smtpHost = smtpHost
        self.smtpPort = smtpPort
        self.smtpName = smtpName
        self.smtpSecure = smtpSecure
        self.smtpTlsRejectUnauthorized = smtpTlsRejectUnauthorized
        self.smtpUser = smtpUser
        self.smtpPassword = smtpPassword
        self.smtpFrom = smtpFrom
    }

    // Optional fields synthesize to `encodeIfPresent`, so nil properties are
    // omitted from the PATCH body.
}
