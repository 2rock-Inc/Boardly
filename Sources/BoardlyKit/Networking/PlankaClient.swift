import Foundation

public struct PlankaClient: Sendable {
    public let profile: ServerProfile
    private let tokenStore: TokenStore
    private let httpClient: any HTTPClient

    public init(
        profile: ServerProfile,
        tokenStore: TokenStore,
        httpClient: any HTTPClient = URLSessionHTTPClient()
    ) {
        self.profile = profile
        self.tokenStore = tokenStore
        self.httpClient = httpClient
    }

    // MARK: - Auth

    public func validateInstance() async throws -> Bootstrap {
        let request = try buildRequest(method: "GET", path: "/bootstrap", requiresAuth: false)
        return try await execute(request)
    }

    public func login(emailOrUsername: String, password: String) async throws {
        struct Body: Encodable {
            let emailOrUsername: String
            let password: String
        }
        struct Response: Decodable {
            let item: String
        }

        let body = try JSONEncoder().encode(Body(emailOrUsername: emailOrUsername, password: password))
        let request = try buildRequest(method: "POST", path: "/access-tokens", body: body, requiresAuth: false)
        let response: Response = try await execute(request)
        try tokenStore.saveToken(response.item)
    }

    public func logout() async throws {
        let request = try buildRequest(method: "DELETE", path: "/access-tokens/me")
        try await executeVoid(request)
        try tokenStore.clearToken()
    }

    // MARK: - Request building

    private func buildRequest(
        method: String,
        path: String,
        body: Data? = nil,
        requiresAuth: Bool = true
    ) throws -> URLRequest {
        guard var components = URLComponents(url: profile.baseURL, resolvingAgainstBaseURL: false) else {
            throw PlankaAPIError.invalidURL
        }
        let basePath = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        components.path = basePath + "/api" + path

        guard let url = components.url else {
            throw PlankaAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = body

        if requiresAuth, let token = try? tokenStore.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    // MARK: - Execution

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, _) = try await performRequest(request)
        do {
            return try JSONDecoder.planka.decode(T.self, from: data)
        } catch {
            throw PlankaAPIError.decodingError(error)
        }
    }

    private func executeVoid(_ request: URLRequest) async throws {
        _ = try await performRequest(request)
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await httpClient.data(for: request)
        } catch {
            throw PlankaAPIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw PlankaAPIError.networkError(URLError(.badServerResponse))
        }

        guard (200...299).contains(http.statusCode) else {
            // Try to parse PLANKA's structured error body
            let plankaCode = (try? JSONDecoder().decode(PlankaErrorBody.self, from: data))?.code
            if let mapped = plankaCode.flatMap(PlankaAPIError.from(plankaCode:)) {
                throw mapped
            }
            switch http.statusCode {
            case 401:
                try? tokenStore.clearToken()
                throw PlankaAPIError.unauthorized
            case 403: throw PlankaAPIError.forbidden
            case 404: throw PlankaAPIError.notFound
            case 409: throw PlankaAPIError.conflict
            case 422: throw PlankaAPIError.invalidParams
            default: throw PlankaAPIError.serverError(http.statusCode)
            }
        }

        return (data, http)
    }
}

private struct PlankaErrorBody: Decodable {
    let code: String?
    let message: String?
}
