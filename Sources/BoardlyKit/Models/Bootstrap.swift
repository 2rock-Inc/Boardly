import Foundation

public struct Bootstrap: Codable, Sendable {
    public let version: String
    public let oidc: OIDCConfig?
    public let activeUsersLimit: Int?
    public let customerPanelUrl: String?
    public let termsLanguages: [String]?

    public struct OIDCConfig: Codable, Sendable {
        /// The provider's authorization endpoint, **with any HTML-escaped `&`
        /// separators repaired** — see `unescapingHTMLAmpersands`.
        public let authorizationUrl: String
        public let endSessionUrl: String?
        public let isEnforced: Bool

        public init(authorizationUrl: String, endSessionUrl: String?, isEnforced: Bool) {
            self.authorizationUrl = authorizationUrl.unescapingHTMLAmpersands
            self.endSessionUrl = endSessionUrl?.unescapingHTMLAmpersands
            self.isEnforced = isEnforced
        }

        /// Repairs the URLs at decode time so no call site can forget to.
        ///
        /// Instances have been observed serving `authorizationUrl` with its query
        /// separators HTML-escaped as `&amp;`. `URLComponents` splits on the `&` and
        /// leaves the `amp;` glued to the next parameter's *name*, so every parameter
        /// but the first silently changes identity: `scope` becomes `amp;scope`,
        /// `response_type` becomes `amp;response_type`. Looking any of them up returns
        /// nil, and the request we build drops `response_type` — required by OAuth 2 —
        /// while keeping the provider's `response_mode=fragment` that we meant to
        /// replace, because the filter no longer matches its name either.
        ///
        /// It fails quietly rather than loudly: the provider falls back to the
        /// application's default scopes, and our own `redirect_uri` fallback happens to
        /// derive the same value PLANKA advertised. Unescaping is a no-op on a
        /// well-formed URL, so this costs nothing when the server behaves.
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            try self.init(
                authorizationUrl: container.decode(String.self, forKey: .authorizationUrl),
                endSessionUrl: container.decodeIfPresent(String.self, forKey: .endSessionUrl),
                isEnforced: container.decode(Bool.self, forKey: .isEnforced))
        }
    }
}

extension String {
    /// `&amp;` → `&`, repeatedly, so a double-escaped `&amp;amp;` also resolves.
    ///
    /// Deliberately narrow: only the ampersand entity is touched, because that is the
    /// one that changes a URL's *structure*. Decoding entities wholesale here would
    /// risk rewriting characters that legitimately appear in a percent-encoded value.
    var unescapingHTMLAmpersands: String {
        var result = self
        while result.contains("&amp;") {
            result = result.replacingOccurrences(of: "&amp;", with: "&")
        }
        return result
    }
}
