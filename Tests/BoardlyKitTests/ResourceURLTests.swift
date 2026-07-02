import Testing
import Foundation
@testable import BoardlyKit

@Suite("PlankaClient.resourceURL — subpath-safe URL resolution")
struct ResourceURLTests {
    private func client(base: String) -> PlankaClient {
        let profile = makeProfile(baseURL: URL(string: base)!)
        return PlankaClient(
            profile: profile,
            tokenStore: TokenStore(profileID: profile.id, keychainStore: MockKeychainStore()),
            httpClient: MockHTTPClient()
        )
    }

    @Test("absolute URLs pass through unchanged")
    func absolutePassthrough() {
        let c = client(base: "https://planka.example.com")
        #expect(c.resourceURL("https://cdn.example.com/bg.png")?.absoluteString == "https://cdn.example.com/bg.png")
    }

    @Test("root-relative URL on a plain host")
    func rootRelativePlainHost() {
        let c = client(base: "https://planka.example.com")
        #expect(c.resourceURL("/background-images/x.png")?.absoluteString
            == "https://planka.example.com/background-images/x.png")
    }

    @Test("root-relative URL preserves a hosting subpath")
    func rootRelativeSubpath() {
        let c = client(base: "https://example.com/planka")
        #expect(c.resourceURL("/background-images/x.png")?.absoluteString
            == "https://example.com/planka/background-images/x.png")
    }

    @Test("relative URL (no leading slash) is appended under the subpath")
    func relativeNoSlash() {
        let c = client(base: "https://example.com/planka/")
        #expect(c.resourceURL("background-images/x.png")?.absoluteString
            == "https://example.com/planka/background-images/x.png")
    }
}
