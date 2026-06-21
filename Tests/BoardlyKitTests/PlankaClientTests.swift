import Testing
import Foundation
@testable import BoardlyKit

@Suite("PlankaClient")
struct PlankaClientTests {
    let baseURL = URL(string: "https://planka.example.com")!
    let profile: ServerProfile
    let mockHTTP: MockHTTPClient
    let mockKeychain: MockKeychainStore
    let tokenStore: TokenStore
    let client: PlankaClient

    init() {
        profile = makeProfile(baseURL: URL(string: "https://planka.example.com")!)
        mockHTTP = MockHTTPClient()
        mockKeychain = MockKeychainStore()
        tokenStore = TokenStore(profileID: profile.id, keychainStore: mockKeychain)
        client = PlankaClient(profile: profile, tokenStore: tokenStore, httpClient: mockHTTP)
    }

    // MARK: - Request building

    @Test("validateInstance sends GET /bootstrap without auth header")
    func validateInstanceRequest() async throws {
        mockHTTP.stub(json: #"{"version":"2.0.1","termsLanguages":[],"oidc":null}"#)
        _ = try await client.validateInstance()

        let request = try #require(mockHTTP.lastRequest)
        #expect(request.httpMethod == "GET")
        #expect(request.url?.path.hasSuffix("/bootstrap") == true)
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("login sends POST /access-tokens and stores token")
    func loginStoresToken() async throws {
        let fixture = loadFixture("login_success")
        mockHTTP.stub(data: fixture)
        try await client.login(emailOrUsername: "alice@example.com", password: "secret")

        let request = try #require(mockHTTP.lastRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path.hasSuffix("/access-tokens") == true)
        #expect(mockKeychain.saveCallCount == 1)
        let stored = try mockKeychain.load(for: "token.\(profile.id.uuidString)")
        #expect(stored != nil)
    }

    @Test("login request body contains emailOrUsername and password")
    func loginRequestBody() async throws {
        mockHTTP.stub(json: #"{"item":"tok123"}"#)
        try await client.login(emailOrUsername: "alice", password: "pass")

        let request = try #require(mockHTTP.lastRequest)
        let body = try #require(request.httpBody)
        let json = try JSONDecoder().decode([String: String].self, from: body)
        #expect(json["emailOrUsername"] == "alice")
        #expect(json["password"] == "pass")
    }

    @Test("logout sends DELETE /access-tokens/me and clears token")
    func logoutClearsToken() async throws {
        try mockKeychain.save("tok123", for: "token.\(profile.id.uuidString)")
        mockHTTP.stub(json: "{}", statusCode: 200)
        try await client.logout()

        let request = try #require(mockHTTP.lastRequest)
        #expect(request.httpMethod == "DELETE")
        #expect(request.url?.path.hasSuffix("/access-tokens/me") == true)
        #expect(mockKeychain.deleteCallCount == 1)
    }

    @Test("authenticated request includes Bearer token in Authorization header")
    func authenticatedRequestIncludesToken() async throws {
        let profileID = profile.id
        try mockKeychain.save("mytoken", for: "token.\(profileID.uuidString)")
        mockHTTP.stub(json: "{}", statusCode: 200)
        // logout will use an authenticated request
        try await client.logout()

        let request = try #require(mockHTTP.lastRequest)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer mytoken")
    }

    // MARK: - Error mapping

    @Test("401 response maps to .unauthorized")
    func maps401ToUnauthorized() async throws {
        mockHTTP.stub(json: #"{"code":"E_UNAUTHORIZED","message":"Invalid credentials"}"#, statusCode: 401)
        await #expect(throws: PlankaAPIError.unauthorized) {
            try await client.login(emailOrUsername: "x", password: "y")
        }
    }

    @Test("403 response maps to .forbidden")
    func maps403ToForbidden() async throws {
        mockHTTP.stub(json: #"{"code":"E_FORBIDDEN"}"#, statusCode: 403)
        await #expect(throws: PlankaAPIError.forbidden) {
            try await client.validateInstance()
        }
    }

    @Test("404 response maps to .notFound")
    func maps404ToNotFound() async throws {
        mockHTTP.stub(json: #"{"code":"E_NOT_FOUND"}"#, statusCode: 404)
        await #expect(throws: PlankaAPIError.notFound) {
            try await client.validateInstance()
        }
    }

    @Test("409 response maps to .conflict")
    func maps409ToConflict() async throws {
        mockHTTP.stub(json: #"{"code":"E_CONFLICT"}"#, statusCode: 409)
        await #expect(throws: PlankaAPIError.conflict) {
            try await client.validateInstance()
        }
    }

    @Test("422 response maps to .invalidParams")
    func maps422ToInvalidParams() async throws {
        mockHTTP.stub(json: #"{"code":"E_MISSING_OR_INVALID_PARAMS"}"#, statusCode: 422)
        await #expect(throws: PlankaAPIError.invalidParams) {
            try await client.login(emailOrUsername: "", password: "")
        }
    }

    @Test("500 response maps to .serverError")
    func maps500ToServerError() async throws {
        mockHTTP.stub(json: "{}", statusCode: 500)
        await #expect(throws: PlankaAPIError.serverError(500)) {
            try await client.validateInstance()
        }
    }

    @Test("network transport error maps to .networkError")
    func transportErrorMapsToNetworkError() async throws {
        mockHTTP.stubbedError = URLError(.notConnectedToInternet)
        do {
            _ = try await client.validateInstance()
            Issue.record("Expected .networkError to be thrown")
        } catch let error as PlankaAPIError {
            guard case .networkError = error else {
                Issue.record("Expected .networkError, got \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("401 clears stored token")
    func unauthorizedClearsToken() async throws {
        try mockKeychain.save("expiredtoken", for: "token.\(profile.id.uuidString)")
        mockHTTP.stub(json: "{}", statusCode: 401)
        _ = try? await client.validateInstance()
        let token = try mockKeychain.load(for: "token.\(profile.id.uuidString)")
        #expect(token == nil)
    }

    // MARK: - URL building

    @Test("subpath base URL is preserved when building request")
    func subpathBaseURLPreserved() async throws {
        let subpathProfile = makeProfile(baseURL: URL(string: "https://example.com/planka")!)
        let subClient = PlankaClient(
            profile: subpathProfile,
            tokenStore: TokenStore(profileID: subpathProfile.id, keychainStore: mockKeychain),
            httpClient: mockHTTP
        )
        mockHTTP.stub(json: #"{"version":"2.0.1","termsLanguages":[],"oidc":null}"#)
        _ = try await subClient.validateInstance()

        let request = try #require(mockHTTP.lastRequest)
        #expect(request.url?.absoluteString == "https://example.com/planka/bootstrap")
    }
}
