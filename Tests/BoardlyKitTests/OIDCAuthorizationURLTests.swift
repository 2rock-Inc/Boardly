import Foundation
import Testing
@testable import BoardlyKit

/// A live instance was found serving `authorizationUrl` with its query separators
/// HTML-escaped (`&amp;` instead of `&`). `URLComponents` splits on the `&` and glues
/// `amp;` onto the *next parameter's name*, so every parameter but the first changes
/// identity — and every lookup for it returns nil.
@Suite("OIDC authorization URL")
struct OIDCAuthorizationURLTests {
    /// Captured verbatim from a PLANKA instance fronted by Authentik.
    private let escaped = """
    {"authorizationUrl":"https://auth.example.com/application/o/authorize/?client_id=ABC\
    &amp;scope=openid%20email%20profile&amp;response_type=code\
    &amp;redirect_uri=https%3A%2F%2Ftodo.example.com%2Foidc-callback&amp;response_mode=fragment",
     "endSessionUrl":null,"isEnforced":true}
    """

    private func decode(_ json: String) throws -> Bootstrap.OIDCConfig {
        try JSONDecoder.planka.decode(Bootstrap.OIDCConfig.self, from: Data(json.utf8))
    }

    private func queryItems(_ config: Bootstrap.OIDCConfig) -> [String: String] {
        let components = URLComponents(string: config.authorizationUrl)
        return (components?.queryItems ?? []).reduce(into: [:]) { $0[$1.name] = $1.value }
    }

    @Test("escaped separators are repaired at decode time")
    func repairsEscapedSeparators() throws {
        let items = try queryItems(decode(escaped))
        #expect(items["scope"] == "openid email profile")
        #expect(items["response_type"] == "code")
        #expect(items["redirect_uri"] == "https://todo.example.com/oidc-callback")
        #expect(items["response_mode"] == "fragment")
        // The corrupted names must be gone, not merely joined by working ones.
        #expect(items["amp;scope"] == nil)
        #expect(items["amp;response_type"] == nil)
    }

    @Test("without the repair, every parameter but the first is unreachable")
    func documentsTheFailure() {
        // Guards the reasoning behind the fix: this is what the app used to see.
        let raw = "https://idp.example.com/auth?client_id=ABC&amp;scope=openid&amp;response_type=code"
        let items = (URLComponents(string: raw)?.queryItems ?? [])
            .reduce(into: [String: String]()) { $0[$1.name] = $1.value }
        #expect(items["client_id"] == "ABC")
        #expect(items["scope"] == nil)
        #expect(items["amp;scope"] == "openid")
    }

    @Test("a well-formed URL is left exactly as it is")
    func leavesCleanURLsAlone() throws {
        let clean = #"{"authorizationUrl":"https://idp.example.com/auth?client_id=ABC&scope=openid","endSessionUrl":null,"isEnforced":false}"#
        let config = try decode(clean)
        #expect(config.authorizationUrl == "https://idp.example.com/auth?client_id=ABC&scope=openid")
    }

    @Test("a double-escaped separator resolves too")
    func handlesDoubleEscaping() throws {
        let json = #"{"authorizationUrl":"https://idp.example.com/auth?a=1&amp;amp;b=2","endSessionUrl":null,"isEnforced":false}"#
        #expect(try decode(json).authorizationUrl == "https://idp.example.com/auth?a=1&b=2")
    }

    @Test("endSessionUrl gets the same repair")
    func repairsEndSessionUrl() throws {
        let json = #"{"authorizationUrl":"https://idp.example.com/auth","endSessionUrl":"https://idp.example.com/end?client_id=ABC&amp;x=1","isEnforced":false}"#
        #expect(try decode(json).endSessionUrl == "https://idp.example.com/end?client_id=ABC&x=1")
    }

    @Test("an ampersand inside a percent-encoded value is untouched")
    func leavesEncodedValuesAlone() throws {
        // %26 is an encoded `&` in a value — unescaping must not go near it.
        let json = #"{"authorizationUrl":"https://idp.example.com/auth?state=a%26b","endSessionUrl":null,"isEnforced":false}"#
        let items = try queryItems(decode(json))
        #expect(items["state"] == "a&b")
    }
}
