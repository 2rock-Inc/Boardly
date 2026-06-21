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
        struct Response: Decodable { let item: Bootstrap }
        let request = try buildRequest(method: "GET", path: "/bootstrap", requiresAuth: false)
        let response: Response = try await execute(request)
        return response.item
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

    // MARK: - Projects

    public func getProjects() async throws -> ProjectsPayload {
        struct ProjectsIncluded: Decodable {
            let boards: [Board]
        }
        struct Response: Decodable {
            let items: [Project]
            let included: ProjectsIncluded
        }
        let request = try buildRequest(method: "GET", path: "/projects")
        let response: Response = try await execute(request)
        return ProjectsPayload(projects: response.items, boards: response.included.boards)
    }

    // MARK: - Board

    public func getBoard(id: String) async throws -> BoardPayload {
        struct BoardIncluded: Decodable {
            let lists: [PlankaList]?
            let cards: [Card]?
            let taskLists: [TaskList]?
            let tasks: [PlankaTask]?
            let labels: [Label]?
            let cardMemberships: [CardMembership]?
            let cardLabels: [CardLabel]?
            let users: [User]?
        }
        struct Response: Decodable {
            let item: Board
            let included: BoardIncluded
        }
        let request = try buildRequest(method: "GET", path: "/boards/\(id)")
        let response: Response = try await execute(request)
        let inc = response.included
        return BoardPayload(
            board: response.item,
            lists: inc.lists ?? [],
            cards: inc.cards ?? [],
            taskLists: inc.taskLists ?? [],
            tasks: inc.tasks ?? [],
            labels: inc.labels ?? [],
            cardMemberships: inc.cardMemberships ?? [],
            cardLabels: inc.cardLabels ?? [],
            users: inc.users ?? []
        )
    }

    // MARK: - Cards

    public func createCard(listId: String, name: String, position: Double) async throws -> Card {
        struct Body: Encodable { let name: String; let position: Double }
        struct Response: Decodable { let item: Card }
        let body = try JSONEncoder().encode(Body(name: name, position: position))
        let request = try buildRequest(method: "POST", path: "/lists/\(listId)/cards", body: body)
        let response: Response = try await execute(request)
        return response.item
    }

    public func updateCard(id: String, patch: CardPatch) async throws -> Card {
        struct Response: Decodable { let item: Card }
        let body = try JSONEncoder().encode(patch)
        let request = try buildRequest(method: "PATCH", path: "/cards/\(id)", body: body)
        let response: Response = try await execute(request)
        return response.item
    }

    @discardableResult
    public func deleteCard(id: String) async throws -> Card {
        struct Response: Decodable { let item: Card }
        let request = try buildRequest(method: "DELETE", path: "/cards/\(id)")
        let response: Response = try await execute(request)
        return response.item
    }

    // MARK: - Task lists

    public func createTaskList(cardId: String, name: String, position: Double) async throws -> TaskList {
        struct Body: Encodable { let name: String; let position: Double }
        struct Response: Decodable { let item: TaskList }
        let body = try JSONEncoder().encode(Body(name: name, position: position))
        let request = try buildRequest(method: "POST", path: "/cards/\(cardId)/task-lists", body: body)
        let response: Response = try await execute(request)
        return response.item
    }

    // MARK: - Tasks

    public func createTask(taskListId: String, name: String, position: Double) async throws -> PlankaTask {
        struct Body: Encodable { let name: String; let position: Double }
        struct Response: Decodable { let item: PlankaTask }
        let body = try JSONEncoder().encode(Body(name: name, position: position))
        let request = try buildRequest(method: "POST", path: "/task-lists/\(taskListId)/tasks", body: body)
        let response: Response = try await execute(request)
        return response.item
    }

    public func updateTask(id: String, patch: TaskPatch) async throws -> PlankaTask {
        struct Response: Decodable { let item: PlankaTask }
        let body = try JSONEncoder().encode(patch)
        let request = try buildRequest(method: "PATCH", path: "/tasks/\(id)", body: body)
        let response: Response = try await execute(request)
        return response.item
    }

    @discardableResult
    public func deleteTask(id: String) async throws -> PlankaTask {
        struct Response: Decodable { let item: PlankaTask }
        let request = try buildRequest(method: "DELETE", path: "/tasks/\(id)")
        let response: Response = try await execute(request)
        return response.item
    }

    // MARK: - Auth (continued)

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
