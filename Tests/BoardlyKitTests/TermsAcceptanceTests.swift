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

    @Test("terms decode without the `type` the spec calls required")
    func termsDecodeWithoutType() async throws {
        // What pro.demo.planka.cloud actually serves: no `type`, even though
        // planka-openapi.json lists it under `required`. Declaring it non-optional made
        // every fetch fail with "couldn't read the server's response".
        mockHTTP.stub(json: #"""
        {"item":{"language":"en-US","content":"# Terms","signature":"sig-abc"}}
        """#)

        let terms = try await client.getTerms()
        #expect(terms.type == nil)
        #expect(terms.signature == "sig-abc")
    }

    @Test("the confirmations block is split out of the terms body")
    func confirmationsSplit() {
        // PLANKA appends the statements to tick after a `[confirmations]::` marker. Left
        // in place, the marker renders as literal text in the middle of the terms.
        let terms = Terms(
            language: "en-US",
            content: "Some terms.\n\n[confirmations]::\n---\n✔️ **I accept these terms**\n",
            signature: "sig")

        #expect(terms.body == "Some terms.")
        #expect(terms.confirmations == ["✔️ **I accept these terms**"])
    }

    @Test("terms with no confirmations block are left whole")
    func noConfirmations() {
        let terms = Terms(language: "en-US", content: "Just terms.", signature: "sig")
        #expect(terms.body == "Just terms.")
        #expect(terms.confirmations.isEmpty)
    }

    // MARK: - Choosing a language

    @Test("an exact language match wins")
    func languageExactMatch() {
        #expect(Terms.preferredLanguage(
            available: ["de-DE", "en-US", "fr-FR"],
            preferred: ["fr-FR", "en-GB"]) == "fr-FR")
    }

    @Test("a regional variant beats an unrelated language")
    func languageRegionalVariant() {
        #expect(Terms.preferredLanguage(
            available: ["de-DE", "fr-FR"],
            preferred: ["fr-CA"]) == "fr-FR")
    }

    @Test("English is the fallback, not whatever the instance lists first")
    func languageFallsBackToEnglish() {
        // Verified against a live instance: asking a de-DE/en-US instance for fr-FR
        // returns German. Left to the server, a French user reads legal terms in a
        // language they may not speak.
        #expect(Terms.preferredLanguage(
            available: ["de-DE", "en-US"],
            preferred: ["fr-FR"]) == "en-US")
    }

    @Test("with neither the user's language nor English, the first is used")
    func languageLastResort() {
        #expect(Terms.preferredLanguage(
            available: ["de-DE", "it-IT"],
            preferred: ["fr-FR"]) == "de-DE")
    }

    @Test("no advertised languages means no query at all")
    func languageNoneAdvertised() {
        #expect(Terms.preferredLanguage(available: [], preferred: ["fr-FR"]) == nil)
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
