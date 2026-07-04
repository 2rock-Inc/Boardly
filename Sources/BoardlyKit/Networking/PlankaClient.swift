import Foundation

public struct PlankaClient: Sendable {
    public let profile: ServerProfile
    private let tokenStore: TokenStore
    private let httpClient: any HTTPClient

    public init(
        profile: ServerProfile,
        tokenStore: TokenStore,
        httpClient: any HTTPClient = URLSessionHTTPClient())
    {
        self.profile = profile
        self.tokenStore = tokenStore
        self.httpClient = httpClient
    }

    // MARK: - Auth

    public func validateInstance() async throws -> Bootstrap {
        struct Response: Decodable { let item: Bootstrap }
        BoardlyLog.tag(.network).icon("🔍").info(
            "Validate instance",
            metadata: ["url": profile.baseURL.absoluteString])
        let request = try buildRequest(method: "GET", path: "/bootstrap", requiresAuth: false)
        let response: Response = try await execute(request)
        BoardlyLog.tag(.network).icon("✅").info("Instance reachable")
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

        BoardlyLog.tag(.auth).icon("🔐").info(
            "Login attempt",
            metadata: ["user": emailOrUsername])
        let body = try JSONEncoder().encode(Body(emailOrUsername: emailOrUsername, password: password))
        let request = try buildRequest(method: "POST", path: "/access-tokens", body: body, requiresAuth: false)
        let response: Response = try await execute(request)
        try tokenStore.saveToken(response.item)
        BoardlyLog.tag(.auth).icon("✅").info(
            "Login succeeded",
            metadata: ["user": emailOrUsername])
    }

    /// Exchange an OIDC authorization `code` + `nonce` (captured from the SSO
    /// redirect) for a PLANKA access token, then store it — same shape as
    /// password login. The instance advertises OIDC via `Bootstrap.oidc`.
    public func exchangeOIDC(code: String, nonce: String) async throws {
        struct Body: Encodable { let code: String; let nonce: String }
        struct Response: Decodable { let item: String }
        BoardlyLog.tag(.auth).icon("🔐").info("OIDC token exchange")
        let body = try JSONEncoder().encode(Body(code: code, nonce: nonce))
        let request = try buildRequest(
            method: "POST",
            path: "/access-tokens/exchange-with-oidc",
            body: body,
            requiresAuth: false)
        let response: Response = try await execute(request)
        try tokenStore.saveToken(response.item)
        BoardlyLog.tag(.auth).icon("✅").info("OIDC login succeeded")
    }

    /// The current user's id, recovered from the stored access token (JWT).
    /// For display only — the server still authorizes every request.
    public func currentUserId() -> String? {
        guard let token = try? tokenStore.loadToken() else { return nil }
        return PlankaJWT.userId(from: token)
    }

    /// The full current-user record plus the notification services sideloaded by
    /// `GET /users/{id}`. Needed to gate admin-only UI on `role == "admin"`,
    /// populate the profile screen, and list the user's notification services.
    public func getCurrentUser() async throws -> CurrentUserPayload {
        guard let id = currentUserId() else { throw PlankaAPIError.unauthorized }
        struct Included: Decodable { let notificationServices: [NotificationService]? }
        struct Response: Decodable { let item: User; let included: Included? }
        let request = try buildRequest(method: "GET", path: "/users/\(id)")
        let response: Response = try await execute(request)
        return CurrentUserPayload(
            user: response.item,
            notificationServices: response.included?.notificationServices ?? [])
    }

    /// Update the current user's preferences (e.g. `defaultHomeView`,
    /// `defaultEditorMode`) via `PATCH /users/{id}`.
    public func updateCurrentUser(patch: UserPatch) async throws -> User {
        guard let id = currentUserId() else { throw PlankaAPIError.unauthorized }
        struct Response: Decodable { let item: User }
        let body = try JSONEncoder().encode(patch)
        let request = try buildRequest(method: "PATCH", path: "/users/\(id)", body: body)
        let response: Response = try await execute(request)
        return response.item
    }

    // MARK: - Projects

    public func getProjects() async throws -> ProjectsPayload {
        struct ProjectsIncluded: Decodable {
            let boards: [Board]?
            let users: [User]?
            let boardMemberships: [BoardMembership]?
            let backgroundImages: [BackgroundImage]?
            let projectManagers: [ProjectManager]?
            let baseCustomFieldGroups: [BaseCustomFieldGroup]?
            let customFields: [CustomField]?
        }
        struct Response: Decodable {
            let items: [Project]
            let included: ProjectsIncluded
        }
        let request = try buildRequest(method: "GET", path: "/projects")
        let response: Response = try await execute(request)
        return ProjectsPayload(
            projects: response.items,
            boards: response.included.boards ?? [],
            users: response.included.users ?? [],
            boardMemberships: response.included.boardMemberships ?? [],
            backgroundImages: response.included.backgroundImages ?? [],
            projectManagers: response.included.projectManagers ?? [],
            baseCustomFieldGroups: response.included.baseCustomFieldGroups ?? [],
            customFields: response.included.customFields ?? [])
    }

    // MARK: - Board

    public func getBoard(id: String) async throws -> BoardPayload {
        let request = try buildRequest(method: "GET", path: "/boards/\(id)")
        let (data, _) = try await performRequest(request)
        do {
            let payload = try BoardPayload.decode(from: data)
            BoardlyLog.tag(.board).icon("📋").info("Board payload decoded", metadata: [
                "lists": "\(payload.lists.count)",
                "cards": "\(payload.cards.count)",
                "taskLists": "\(payload.taskLists.count)",
                "tasks": "\(payload.tasks.count)",
            ])
            return payload
        } catch {
            BoardlyLog.tag(.network).icon("❌").error(
                "Decode failed", error: error, metadata: ["type": "BoardPayload", "path": request.url?.path ?? "?"])
            throw PlankaAPIError.decodingError(error)
        }
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

    // MARK: - Labels

    public func createLabel(boardId: String, name: String, color: String, position: Double) async throws -> Label {
        struct Body: Encodable { let name: String; let color: String; let position: Double }
        struct Response: Decodable { let item: Label }
        let body = try JSONEncoder().encode(Body(name: name, color: color, position: position))
        let request = try buildRequest(method: "POST", path: "/boards/\(boardId)/labels", body: body)
        let response: Response = try await execute(request)
        return response.item
    }

    public func addCardLabel(cardId: String, labelId: String) async throws -> CardLabel {
        struct Body: Encodable { let labelId: String }
        struct Response: Decodable { let item: CardLabel }
        let body = try JSONEncoder().encode(Body(labelId: labelId))
        let request = try buildRequest(method: "POST", path: "/cards/\(cardId)/card-labels", body: body)
        let response: Response = try await execute(request)
        return response.item
    }

    @discardableResult
    public func removeCardLabel(cardId: String, labelId: String) async throws -> CardLabel {
        struct Response: Decodable { let item: CardLabel }
        let request = try buildRequest(method: "DELETE", path: "/cards/\(cardId)/card-labels/labelId:\(labelId)")
        let response: Response = try await execute(request)
        return response.item
    }

    // MARK: - Card members

    public func addCardMember(cardId: String, userId: String) async throws -> CardMembership {
        struct Body: Encodable { let userId: String }
        struct Response: Decodable { let item: CardMembership }
        let body = try JSONEncoder().encode(Body(userId: userId))
        let request = try buildRequest(method: "POST", path: "/cards/\(cardId)/card-memberships", body: body)
        let response: Response = try await execute(request)
        return response.item
    }

    @discardableResult
    public func removeCardMember(cardId: String, userId: String) async throws -> CardMembership {
        struct Response: Decodable { let item: CardMembership }
        let request = try buildRequest(method: "DELETE", path: "/cards/\(cardId)/card-memberships/userId:\(userId)")
        let response: Response = try await execute(request)
        return response.item
    }

    // MARK: - Activity

    public func getCardActions(cardId: String) async throws -> [Action] {
        struct Response: Decodable { let items: [Action] }
        let request = try buildRequest(method: "GET", path: "/cards/\(cardId)/actions")
        let response: Response = try await execute(request)
        return response.items
    }

    // MARK: - Stopwatch

    @discardableResult
    public func updateStopwatch(cardId: String, total: Int, startedAt: Date?) async throws -> Card {
        struct Stopwatch: Encodable {
            let total: Int
            let startedAt: String?
            func encode(to encoder: any Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(total, forKey: .total)
                try c.encode(startedAt, forKey: .startedAt) // explicit null when nil (stopped)
            }

            enum CodingKeys: String, CodingKey { case total, startedAt }
        }
        struct Body: Encodable { let stopwatch: Stopwatch }
        struct Response: Decodable { let item: Card }
        let started = startedAt.map { ISO8601Formatters.fractional.string(from: $0) }
        let body = try JSONEncoder().encode(Body(stopwatch: Stopwatch(total: total, startedAt: started)))
        let request = try buildRequest(method: "PATCH", path: "/cards/\(cardId)", body: body)
        let response: Response = try await execute(request)
        return response.item
    }

    // MARK: - Comments

    public func getComments(cardId: String) async throws -> [Comment] {
        struct Response: Decodable { let items: [Comment] }
        let request = try buildRequest(method: "GET", path: "/cards/\(cardId)/comments")
        let response: Response = try await execute(request)
        return response.items
    }

    public func createComment(cardId: String, text: String) async throws -> Comment {
        struct Body: Encodable { let text: String }
        struct Response: Decodable { let item: Comment }
        let body = try JSONEncoder().encode(Body(text: text))
        let request = try buildRequest(method: "POST", path: "/cards/\(cardId)/comments", body: body)
        let response: Response = try await execute(request)
        return response.item
    }

    @discardableResult
    public func deleteComment(id: String) async throws -> Comment {
        struct Response: Decodable { let item: Comment }
        let request = try buildRequest(method: "DELETE", path: "/comments/\(id)")
        let response: Response = try await execute(request)
        return response.item
    }

    // MARK: - Attachments

    public func uploadFileAttachment(cardId: String, fileName: String, mimeType: String, data: Data) async throws -> Attachment {
        struct Response: Decodable { let item: Attachment }
        let request = try buildMultipartRequest(
            path: "/cards/\(cardId)/attachments",
            fields: ["type": "file", "name": fileName],
            file: (fieldName: "file", fileName: fileName, mimeType: mimeType, data: data))
        let response: Response = try await execute(request)
        return response.item
    }

    public func addLinkAttachment(cardId: String, url: String, name: String) async throws -> Attachment {
        struct Response: Decodable { let item: Attachment }
        let request = try buildMultipartRequest(
            path: "/cards/\(cardId)/attachments",
            fields: ["type": "link", "url": url, "name": name],
            file: nil)
        let response: Response = try await execute(request)
        return response.item
    }

    @discardableResult
    public func deleteAttachment(id: String) async throws -> Attachment {
        struct Response: Decodable { let item: Attachment }
        let request = try buildRequest(method: "DELETE", path: "/attachments/\(id)")
        let response: Response = try await execute(request)
        return response.item
    }

    // MARK: - Images

    /// Fetch image bytes (e.g. a card cover). The Bearer token is attached only
    /// when the image is hosted on this profile's own instance, so we never leak
    /// the token to a third-party host referenced by an attachment.
    public func imageData(url: URL) async -> Data? {
        var request = URLRequest(url: url)
        // Attach the token only for the exact same origin AND over TLS — never
        // send the Bearer to a different host/port/scheme or over plaintext http.
        if isSameSecureOrigin(url), let token = try? tokenStore.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        guard let (data, response) = try? await httpClient.data(for: request),
              let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode)
        else { return nil }
        return data
    }

    private func isSameSecureOrigin(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https"
            && url.scheme?.lowercased() == profile.baseURL.scheme?.lowercased()
            && url.host?.lowercased() == profile.baseURL.host?.lowercased()
            && url.port == profile.baseURL.port
    }

    /// Resolve a (possibly relative) resource URL returned by PLANKA — e.g. a
    /// background-image or attachment `url` — against this profile's base URL.
    /// Absolute URLs pass through unchanged; relative ones are appended to the base
    /// URL **preserving any hosting subpath** (e.g. `https://example.com/planka`),
    /// so subpath-hosted instances don't drop the subpath.
    public func resourceURL(_ raw: String) -> URL? {
        if let url = URL(string: raw), url.scheme != nil { return url }
        let base = profile.baseURL.absoluteString
        let trimmedBase = base.hasSuffix("/") ? String(base.dropLast()) : base
        let suffix = raw.hasPrefix("/") ? raw : "/\(raw)"
        return URL(string: trimmedBase + suffix)
    }

    // MARK: - Notifications

    /// The current user's unread notifications, with creator users sideloaded.
    public func getNotifications() async throws -> NotificationsPayload {
        struct Included: Decodable { let users: [User]? }
        struct Response: Decodable { let items: [PlankaNotification]; let included: Included }
        let request = try buildRequest(method: "GET", path: "/notifications")
        let response: Response = try await execute(request)
        return NotificationsPayload(
            notifications: response.items,
            users: response.included.users ?? [])
    }

    @discardableResult
    public func setNotificationRead(id: String, isRead: Bool) async throws -> PlankaNotification {
        struct Body: Encodable { let isRead: Bool }
        struct Response: Decodable { let item: PlankaNotification }
        let body = try JSONEncoder().encode(Body(isRead: isRead))
        let request = try buildRequest(method: "PATCH", path: "/notifications/\(id)", body: body)
        let response: Response = try await execute(request)
        return response.item
    }

    public func markAllNotificationsRead() async throws {
        let request = try buildRequest(method: "POST", path: "/notifications/read-all")
        try await executeVoid(request)
    }

    // MARK: - Notification services

    public func createUserNotificationService(userId: String, url: String, format: String) async throws -> NotificationService {
        try await createNotificationService(path: "/users/\(userId)/notification-services", url: url, format: format)
    }

    public func createBoardNotificationService(boardId: String, url: String, format: String) async throws -> NotificationService {
        try await createNotificationService(path: "/boards/\(boardId)/notification-services", url: url, format: format)
    }

    private func createNotificationService(path: String, url: String, format: String) async throws -> NotificationService {
        struct Body: Encodable { let url: String; let format: String }
        struct Response: Decodable { let item: NotificationService }
        let body = try JSONEncoder().encode(Body(url: url, format: format))
        let request = try buildRequest(method: "POST", path: path, body: body)
        let response: Response = try await execute(request)
        return response.item
    }

    public func updateNotificationService(id: String, url: String?, format: String?) async throws -> NotificationService {
        struct Body: Encodable { let url: String?; let format: String? }
        struct Response: Decodable { let item: NotificationService }
        let body = try JSONEncoder().encode(Body(url: url, format: format))
        let request = try buildRequest(method: "PATCH", path: "/notification-services/\(id)", body: body)
        let response: Response = try await execute(request)
        return response.item
    }

    @discardableResult
    public func deleteNotificationService(id: String) async throws -> NotificationService {
        struct Response: Decodable { let item: NotificationService }
        let request = try buildRequest(method: "DELETE", path: "/notification-services/\(id)")
        let response: Response = try await execute(request)
        return response.item
    }

    public func testNotificationService(id: String) async throws {
        let request = try buildRequest(method: "POST", path: "/notification-services/\(id)/test")
        try await executeVoid(request)
    }

    // MARK: - Project background

    public func updateProject(id: String, patch: ProjectPatch) async throws -> Project {
        struct Response: Decodable { let item: Project }
        let body = try JSONEncoder().encode(patch)
        let request = try buildRequest(method: "PATCH", path: "/projects/\(id)", body: body)
        let response: Response = try await execute(request)
        return response.item
    }

    public func uploadBackgroundImage(projectId: String, fileName: String, mimeType: String, data: Data) async throws -> BackgroundImage {
        struct Response: Decodable { let item: BackgroundImage }
        let request = try buildMultipartRequest(
            path: "/projects/\(projectId)/background-images",
            fields: [:],
            file: (fieldName: "file", fileName: fileName, mimeType: mimeType, data: data))
        let response: Response = try await execute(request)
        return response.item
    }

    @discardableResult
    public func deleteBackgroundImage(id: String) async throws -> BackgroundImage {
        struct Response: Decodable { let item: BackgroundImage }
        let request = try buildRequest(method: "DELETE", path: "/background-images/\(id)")
        let response: Response = try await execute(request)
        return response.item
    }

    // MARK: - Project management

    @discardableResult
    public func deleteProject(id: String) async throws -> Project {
        struct Response: Decodable { let item: Project }
        let request = try buildRequest(method: "DELETE", path: "/projects/\(id)")
        let response: Response = try await execute(request)
        return response.item
    }

    public func addProjectManager(projectId: String, userId: String) async throws -> ProjectManager {
        struct Body: Encodable { let userId: String }
        struct Response: Decodable { let item: ProjectManager }
        let body = try JSONEncoder().encode(Body(userId: userId))
        let request = try buildRequest(method: "POST", path: "/projects/\(projectId)/project-managers", body: body)
        let response: Response = try await execute(request)
        return response.item
    }

    @discardableResult
    public func removeProjectManager(id: String) async throws -> ProjectManager {
        struct Response: Decodable { let item: ProjectManager }
        let request = try buildRequest(method: "DELETE", path: "/project-managers/\(id)")
        let response: Response = try await execute(request)
        return response.item
    }

    // MARK: - Base custom field groups (project-level)

    public func createBaseCustomFieldGroup(projectId: String, name: String) async throws -> BaseCustomFieldGroup {
        struct Body: Encodable { let name: String }
        struct Response: Decodable { let item: BaseCustomFieldGroup }
        let body = try JSONEncoder().encode(Body(name: name))
        let request = try buildRequest(method: "POST", path: "/projects/\(projectId)/base-custom-field-groups", body: body)
        let response: Response = try await execute(request)
        return response.item
    }

    public func updateBaseCustomFieldGroup(id: String, name: String) async throws -> BaseCustomFieldGroup {
        struct Body: Encodable { let name: String }
        struct Response: Decodable { let item: BaseCustomFieldGroup }
        let body = try JSONEncoder().encode(Body(name: name))
        let request = try buildRequest(method: "PATCH", path: "/base-custom-field-groups/\(id)", body: body)
        let response: Response = try await execute(request)
        return response.item
    }

    @discardableResult
    public func deleteBaseCustomFieldGroup(id: String) async throws -> BaseCustomFieldGroup {
        struct Response: Decodable { let item: BaseCustomFieldGroup }
        let request = try buildRequest(method: "DELETE", path: "/base-custom-field-groups/\(id)")
        let response: Response = try await execute(request)
        return response.item
    }

    public func createBaseCustomField(groupId: String, name: String, position: Double) async throws -> CustomField {
        struct Body: Encodable { let name: String; let position: Double }
        struct Response: Decodable { let item: CustomField }
        let body = try JSONEncoder().encode(Body(name: name, position: position))
        let request = try buildRequest(method: "POST", path: "/base-custom-field-groups/\(groupId)/custom-fields", body: body)
        let response: Response = try await execute(request)
        return response.item
    }

    // MARK: - Board custom field groups, fields & values (Phase 7)

    /// Instantiate a custom-field group on a board — either cloned from a base
    /// group (`baseCustomFieldGroupId`) or ad-hoc (`name`). Exactly one is provided.
    public func createBoardCustomFieldGroup(
        boardId: String,
        position: Double,
        baseCustomFieldGroupId: String? = nil,
        name: String? = nil) async throws -> CustomFieldGroup
    {
        struct Body: Encodable { let position: Double; let baseCustomFieldGroupId: String?; let name: String? }
        struct Response: Decodable { let item: CustomFieldGroup }
        let body = try JSONEncoder().encode(Body(position: position, baseCustomFieldGroupId: baseCustomFieldGroupId, name: name))
        let request = try buildRequest(method: "POST", path: "/boards/\(boardId)/custom-field-groups", body: body)
        let response: Response = try await execute(request)
        return response.item
    }

    public func updateCustomFieldGroup(id: String, position: Double? = nil, name: String? = nil) async throws -> CustomFieldGroup {
        struct Body: Encodable { let position: Double?; let name: String? }
        struct Response: Decodable { let item: CustomFieldGroup }
        let body = try JSONEncoder().encode(Body(position: position, name: name))
        let request = try buildRequest(method: "PATCH", path: "/custom-field-groups/\(id)", body: body)
        let response: Response = try await execute(request)
        return response.item
    }

    @discardableResult
    public func deleteCustomFieldGroup(id: String) async throws -> CustomFieldGroup {
        struct Response: Decodable { let item: CustomFieldGroup }
        let request = try buildRequest(method: "DELETE", path: "/custom-field-groups/\(id)")
        let response: Response = try await execute(request)
        return response.item
    }

    public func createCustomFieldInGroup(
        groupId: String,
        name: String,
        position: Double,
        showOnFrontOfCard: Bool? = nil) async throws -> CustomField
    {
        struct Body: Encodable { let name: String; let position: Double; let showOnFrontOfCard: Bool? }
        struct Response: Decodable { let item: CustomField }
        let body = try JSONEncoder().encode(Body(name: name, position: position, showOnFrontOfCard: showOnFrontOfCard))
        let request = try buildRequest(method: "POST", path: "/custom-field-groups/\(groupId)/custom-fields", body: body)
        let response: Response = try await execute(request)
        return response.item
    }

    public func updateCustomField(
        id: String,
        name: String? = nil,
        position: Double? = nil,
        showOnFrontOfCard: Bool? = nil) async throws -> CustomField
    {
        struct Body: Encodable { let name: String?; let position: Double?; let showOnFrontOfCard: Bool? }
        struct Response: Decodable { let item: CustomField }
        let body = try JSONEncoder().encode(Body(name: name, position: position, showOnFrontOfCard: showOnFrontOfCard))
        let request = try buildRequest(method: "PATCH", path: "/custom-fields/\(id)", body: body)
        let response: Response = try await execute(request)
        return response.item
    }

    @discardableResult
    public func deleteCustomField(id: String) async throws -> CustomField {
        struct Response: Decodable { let item: CustomField }
        let request = try buildRequest(method: "DELETE", path: "/custom-fields/\(id)")
        let response: Response = try await execute(request)
        return response.item
    }

    /// Set (upsert) a card's value for a field. PLANKA encodes the group+field IDs
    /// into the path segment — note the literal `$` before the field id and the
    /// **plural** `custom-field-values`.
    public func setCustomFieldValue(
        cardId: String,
        groupId: String,
        fieldId: String,
        content: String) async throws -> CustomFieldValue
    {
        struct Body: Encodable { let content: String }
        struct Response: Decodable { let item: CustomFieldValue }
        let body = try JSONEncoder().encode(Body(content: content))
        let path = "/cards/\(cardId)/custom-field-values/customFieldGroupId:\(groupId):customFieldId:$\(fieldId)"
        let request = try buildRequest(method: "PATCH", path: path, body: body)
        let response: Response = try await execute(request)
        return response.item
    }

    /// Clear a card's value for a field. Note the **singular** `custom-field-value`
    /// (differs from the set endpoint above) and the literal `$` before the field id.
    @discardableResult
    public func clearCustomFieldValue(cardId: String, groupId: String, fieldId: String) async throws -> CustomFieldValue {
        struct Response: Decodable { let item: CustomFieldValue }
        let path = "/cards/\(cardId)/custom-field-value/customFieldGroupId:\(groupId):customFieldId:$\(fieldId)"
        let request = try buildRequest(method: "DELETE", path: path)
        let response: Response = try await execute(request)
        return response.item
    }

    // MARK: - Webhooks (admin)

    public func getWebhooks() async throws -> [Webhook] {
        struct Response: Decodable { let items: [Webhook] }
        let request = try buildRequest(method: "GET", path: "/webhooks")
        let response: Response = try await execute(request)
        return response.items
    }

    public func createWebhook(
        name: String,
        url: String,
        accessToken: String? = nil,
        events: [String]? = nil,
        excludedEvents: [String]? = nil) async throws -> Webhook
    {
        struct Response: Decodable { let item: Webhook }
        let patch = WebhookPatch(
            name: name,
            url: url,
            accessToken: accessToken,
            events: events,
            excludedEvents: excludedEvents)
        let body = try JSONEncoder().encode(patch)
        let request = try buildRequest(method: "POST", path: "/webhooks", body: body)
        let response: Response = try await execute(request)
        return response.item
    }

    public func updateWebhook(id: String, patch: WebhookPatch) async throws -> Webhook {
        struct Response: Decodable { let item: Webhook }
        let body = try JSONEncoder().encode(patch)
        let request = try buildRequest(method: "PATCH", path: "/webhooks/\(id)", body: body)
        let response: Response = try await execute(request)
        return response.item
    }

    @discardableResult
    public func deleteWebhook(id: String) async throws -> Webhook {
        struct Response: Decodable { let item: Webhook }
        let request = try buildRequest(method: "DELETE", path: "/webhooks/\(id)")
        let response: Response = try await execute(request)
        return response.item
    }

    // MARK: - Instance config (admin)

    public func getConfig() async throws -> Config {
        struct Response: Decodable { let item: Config }
        let request = try buildRequest(method: "GET", path: "/config")
        let response: Response = try await execute(request)
        return response.item
    }

    public func updateConfig(patch: ConfigPatch) async throws -> Config {
        struct Response: Decodable { let item: Config }
        let body = try JSONEncoder().encode(patch)
        let request = try buildRequest(method: "PATCH", path: "/config", body: body)
        let response: Response = try await execute(request)
        return response.item
    }

    public func testSMTP() async throws {
        let request = try buildRequest(method: "POST", path: "/config/test-smtp")
        try await executeVoid(request)
    }

    // MARK: - Auth (continued)

    public func logout() async throws {
        BoardlyLog.tag(.auth).icon("🔓").info("Logout")
        let request = try buildRequest(method: "DELETE", path: "/access-tokens/me")
        // Best-effort server-side revoke; the local token is cleared regardless
        // so an expired/invalid token (which 401s here) still logs the user out.
        do {
            try await executeVoid(request)
        } catch {
            BoardlyLog.tag(.auth).icon("⚠️").warning("Logout request failed; clearing local token anyway")
        }
        try tokenStore.clearToken()
        BoardlyLog.tag(.auth).icon("✅").info("Logout succeeded")
    }

    // MARK: - Request building

    private func buildRequest(
        method: String,
        path: String,
        body: Data? = nil,
        requiresAuth: Bool = true) throws -> URLRequest
    {
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
        request.timeoutInterval = 30 // fail fast on an unreachable/black-holed host
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = body

        if requiresAuth, let token = try? tokenStore.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    private func buildMultipartRequest(
        path: String,
        fields: [String: String],
        file: (fieldName: String, fileName: String, mimeType: String, data: Data)?) throws -> URLRequest
    {
        guard var components = URLComponents(url: profile.baseURL, resolvingAgainstBaseURL: false) else {
            throw PlankaAPIError.invalidURL
        }
        let basePath = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        components.path = basePath + "/api" + path
        guard let url = components.url else { throw PlankaAPIError.invalidURL }

        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        func append(_ string: String) { body.append(Data(string.utf8)) }
        /// Strip CR/LF and escape quotes so a crafted field name / filename can't
        /// inject extra multipart headers into a Content-Disposition line.
        func headerSafe(_ value: String) -> String {
            value
                .replacingOccurrences(of: "\r", with: "")
                .replacingOccurrences(of: "\n", with: "")
                .replacingOccurrences(of: "\"", with: "'")
        }

        for (key, value) in fields {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(headerSafe(key))\"\r\n\r\n")
            append("\(value)\r\n")
        }
        if let file {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(headerSafe(file.fieldName))\"; filename=\"\(headerSafe(file.fileName))\"\r\n")
            append("Content-Type: \(file.mimeType)\r\n\r\n")
            body.append(file.data)
            append("\r\n")
        }
        append("--\(boundary)--\r\n")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = body
        if let token = try? tokenStore.loadToken() {
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
            BoardlyLog.tag(.network).icon("❌").error(
                "Decode failed",
                error: error,
                metadata: ["type": "\(T.self)", "path": request.url?.path ?? "?"])
            throw PlankaAPIError.decodingError(error)
        }
    }

    private func executeVoid(_ request: URLRequest) async throws {
        _ = try await performRequest(request)
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let method = request.httpMethod ?? "?"
        let path = request.url?.path ?? "?"
        BoardlyLog.tag(.network).icon("📡").info("→ \(method) \(path)")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await httpClient.data(for: request)
        } catch {
            BoardlyLog.tag(.network).icon("❌").error(
                "Network failure",
                error: error,
                metadata: ["path": path])
            throw PlankaAPIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            BoardlyLog.tag(.network).icon("❌").error(
                "Invalid response",
                metadata: ["path": path])
            throw PlankaAPIError.networkError(URLError(.badServerResponse))
        }

        guard (200 ... 299).contains(http.statusCode) else {
            // Try to parse PLANKA's structured error body
            let plankaCode = (try? JSONDecoder().decode(PlankaErrorBody.self, from: data))?.code
            var meta: [String: Any] = ["path": path]
            if let code = plankaCode { meta["code"] = code }
            if http.statusCode == 401 {
                // Clear the dead token here, regardless of the parsed PLANKA code:
                // the code mapping below throws before the status switch is reached,
                // so a real E_UNAUTHORIZED 401 would otherwise never clear it.
                try? tokenStore.clearToken()
                BoardlyLog.tag(.auth).icon("⚠️").warning(
                    "401 Unauthorized — token cleared",
                    metadata: meta)
            } else if http.statusCode >= 500 {
                BoardlyLog.tag(.network).icon("❌").error(
                    "← \(http.statusCode) \(method) \(path)",
                    metadata: meta)
            } else {
                BoardlyLog.tag(.network).icon("⚠️").warning(
                    "← \(http.statusCode) \(method) \(path)",
                    metadata: meta)
            }
            if let mapped = plankaCode.flatMap(PlankaAPIError.from(plankaCode:)) {
                throw mapped
            }
            switch http.statusCode {
            case 401:
                throw PlankaAPIError.unauthorized
            case 403: throw PlankaAPIError.forbidden
            case 404: throw PlankaAPIError.notFound
            case 409: throw PlankaAPIError.conflict
            case 422: throw PlankaAPIError.invalidParams
            default: throw PlankaAPIError.serverError(http.statusCode)
            }
        }

        BoardlyLog.tag(.network).icon("✅").info("← \(http.statusCode) \(method) \(path)")
        return (data, http)
    }
}

private struct PlankaErrorBody: Decodable {
    let code: String?
    let message: String?
}
