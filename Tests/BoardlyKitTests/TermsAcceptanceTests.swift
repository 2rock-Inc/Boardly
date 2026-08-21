import Foundation
import Testing
@testable import BoardlyKit

@Suite("Terms acceptance")
struct TermsAcceptanceTests {
    let profile: ServerProfile
    let mockHTTP: MockHTTPClient
    let mockKeychain: MockKeychainStore
    let client: PlankaClient

    init() {
        profile = makeProfile(baseURL: URL(string: "https://planka.example.com")!)
        mockHTTP = MockHTTPClient()
        mockKeychain = MockKeychainStore()
        client = PlankaClient(
            profile: profile,
            tokenStore: TokenStore(profileID: profile.id, keychainStore: mockKeychain),
            httpClient: mockHTTP)
    }

    // MARK: - Reading the restriction out of a 403

    @Test("a terms-required 403 surfaces the reason and the pending token")
    func termsRestrictionParsed() async throws {
        // The body below is what a real PLANKA instance returns; `pendingToken` and `step`
        // are absent from planka-openapi.json, which is why the flow could not be built
        // from the spec alone.
        mockHTTP.stub(json: #"""
        {"code":"E_FORBIDDEN","pendingToken":"pending-abc","message":"Terms acceptance required","step":"accept-terms"}
        """#, statusCode: 403)

        await #expect(throws: PlankaAPIError.authRestriction(
            AuthRestriction(reason: .termsAcceptanceRequired, pendingToken: "pending-abc")))
        {
            try await client.login(emailOrUsername: "alice", password: "secret")
        }
    }

    @Test("an SSO-only 403 is told apart from terms")
    func ssoRestrictionParsed() async throws {
        mockHTTP.stub(json: #"{"code":"E_FORBIDDEN","message":"Use single sign-on"}"#, statusCode: 403)

        await #expect(throws: PlankaAPIError.authRestriction(
            AuthRestriction(reason: .useSingleSignOn, pendingToken: nil)))
        {
            try await client.login(emailOrUsername: "alice", password: "secret")
        }
    }

    @Test("an uninitialised instance is told apart too")
    func adminRestrictionParsed() async throws {
        mockHTTP.stub(json: #"""
        {"code":"E_FORBIDDEN","message":"Admin login required to initialize instance"}
        """#, statusCode: 403)

        await #expect(throws: PlankaAPIError.authRestriction(
            AuthRestriction(reason: .adminLoginRequired, pendingToken: nil)))
        {
            try await client.login(emailOrUsername: "alice", password: "secret")
        }
    }

    @Test("an ordinary permission 403 stays .forbidden")
    func plainForbiddenUnchanged() async throws {
        // A board the user may not open must keep producing a plain permission error, or
        // every 403 in the app would start reading as a sign-in problem.
        mockHTTP.stub(json: #"{"code":"E_FORBIDDEN","message":"Not enough rights"}"#, statusCode: 403)

        await #expect(throws: PlankaAPIError.forbidden) {
            _ = try await client.getBoard(id: "b1")
        }
    }

    @Test("a 403 with no body at all stays .forbidden")
    func emptyForbiddenUnchanged() async throws {
        mockHTTP.stub(json: "{}", statusCode: 403)

        await #expect(throws: PlankaAPIError.forbidden) {
            _ = try await client.getBoard(id: "b1")
        }
    }

    // MARK: - Fetching the terms

    @Test("getTerms hits /terms unauthenticated and passes the language")
    func getTermsRequest() async throws {
        mockHTTP.stub(json: #"""
        {"item":{"type":"privacyPolicy","language":"en-US","content":"# Hello","signature":"sig-123"}}
        """#)

        let terms = try await client.getTerms(language: "fr-FR")

        let request = try #require(mockHTTP.lastRequest)
        #expect(request.httpMethod == "GET")
        #expect(request.url?.path.hasSuffix("/terms") == true)
        // The language belongs in the query string; folding it into the path would
        // percent-encode the "?" and quietly request a URL that does not exist.
        #expect(request.url?.query == "language=fr-FR")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(terms.signature == "sig-123")
        #expect(terms.content == "# Hello")
    }

    @Test("getTerms omits the query when no language is given")
    func getTermsNoLanguage() async throws {
        mockHTTP.stub(json: #"""
        {"item":{"type":"privacyPolicy","language":"en-US","content":"x","signature":"s"}}
        """#)

        _ = try await client.getTerms()

        let request = try #require(mockHTTP.lastRequest)
        #expect(request.url?.query == nil)
    }

    // MARK: - Accepting

    @Test("acceptTerms posts the pending token and signature, then stores the token")
    func acceptTermsStoresToken() async throws {
        mockHTTP.stub(json: #"{"item":"final-token"}"#)

        try await client.acceptTerms(pendingToken: "pending-abc", signature: "sig-123")

        let request = try #require(mockHTTP.lastRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path.hasSuffix("/access-tokens/accept-terms") == true)
        let body = try JSONDecoder().decode([String: String].self, from: #require(request.httpBody))
        #expect(body["pendingToken"] == "pending-abc")
        #expect(body["signature"] == "sig-123")

        let stored = try mockKeychain.load(for: "token.\(profile.id.uuidString)")
        #expect(stored == "final-token")
    }

    @Test("an expired pending token surfaces as .unauthorized")
    func expiredPendingToken() async throws {
        // The pending token lasts about ten minutes, so a user who leaves the terms on
        // screen comes back to a rejection — it has to read as "start over", not as a
        // lost password.
        mockHTTP.stub(json: #"{"code":"E_UNAUTHORIZED","message":"Invalid pending token"}"#, statusCode: 401)

        await #expect(throws: PlankaAPIError.unauthorized) {
            try await client.acceptTerms(pendingToken: "stale", signature: "sig")
        }
        #expect(mockKeychain.saveCallCount == 0)
    }
}
