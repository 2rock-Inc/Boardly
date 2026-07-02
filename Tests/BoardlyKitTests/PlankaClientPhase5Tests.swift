import Testing
import Foundation
@testable import BoardlyKit

@Suite("PlankaClient — Phase 5 endpoints")
struct PlankaClientPhase5Tests {
    let profile: ServerProfile
    let mockHTTP: MockHTTPClient
    let tokenStore: TokenStore
    let client: PlankaClient

    init() {
        profile = makeProfile(baseURL: URL(string: "https://planka.example.com")!)
        mockHTTP = MockHTTPClient()
        tokenStore = TokenStore(profileID: profile.id, keychainStore: MockKeychainStore())
        client = PlankaClient(profile: profile, tokenStore: tokenStore, httpClient: mockHTTP)
    }

    /// A structurally valid JWT (`header.payload.signature`) whose payload
    /// decodes to `userId` — enough for `currentUserId()` to recover the id.
    private func fakeJWT(userId: String) -> String {
        let payload = Data(#"{"subject":"\#(userId)"}"#.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "header.\(payload).signature"
    }

    private func body(of req: URLRequest) throws -> [String: Any] {
        let data = try #require(req.httpBody)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: - OIDC

    @Test("exchangeOIDC posts code+nonce and stores the returned token")
    func exchangeOIDC() async throws {
        mockHTTP.stub(json: #"{"item":"jwt-from-oidc"}"#)
        try await client.exchangeOIDC(code: "abc", nonce: "xyz")

        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "POST")
        #expect(req.url?.path.hasSuffix("/api/access-tokens/exchange-with-oidc") == true)
        #expect(req.value(forHTTPHeaderField: "Authorization") == nil) // requiresAuth: false
        let json = try body(of: req)
        #expect(json["code"] as? String == "abc")
        #expect(json["nonce"] as? String == "xyz")
        #expect(try tokenStore.loadToken() == "jwt-from-oidc")
    }

    // MARK: - Current user

    @Test("getCurrentUser GETs /users/{id} from the JWT and decodes role")
    func getCurrentUser() async throws {
        try tokenStore.saveToken(fakeJWT(userId: "u1"))
        mockHTTP.stub(json: #"{"item":{"id":"u1","role":"admin","name":"Marie","isDeactivated":false,"isDefaultAdmin":true}}"#)
        let user = try await client.getCurrentUser()

        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "GET")
        #expect(req.url?.path.hasSuffix("/api/users/u1") == true)
        #expect(user.role == "admin")
        #expect(user.isDefaultAdmin == true)
    }

    // MARK: - Notifications

    @Test("getNotifications parses items + sideloaded creator users")
    func getNotifications() async throws {
        mockHTTP.stub(json: #"""
        {"items":[{"id":"n1","userId":"u1","creatorUserId":"u2","boardId":"b1","cardId":"c1","commentId":null,"actionId":null,"type":"commentCard","data":{"text":"hi"},"isRead":false,"createdAt":null,"updatedAt":null}],
         "included":{"users":[{"id":"u2","role":"member","name":"Paul","isDeactivated":false}]}}
        """#)
        let payload = try await client.getNotifications()

        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "GET")
        #expect(req.url?.path.hasSuffix("/api/notifications") == true)
        #expect(payload.notifications.count == 1)
        let n = try #require(payload.notifications.first)
        #expect(payload.creator(of: n)?.name == "Paul")
    }

    @Test("setNotificationRead PATCHes /notifications/{id} with isRead")
    func setNotificationRead() async throws {
        mockHTTP.stub(json: #"{"item":{"id":"n1","userId":"u1","creatorUserId":null,"boardId":"b1","cardId":"c1","commentId":null,"actionId":null,"type":"commentCard","data":{},"isRead":true,"createdAt":null,"updatedAt":null}}"#)
        _ = try await client.setNotificationRead(id: "n1", isRead: true)

        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "PATCH")
        #expect(req.url?.path.hasSuffix("/api/notifications/n1") == true)
        #expect(try body(of: req)["isRead"] as? Bool == true)
    }

    @Test("markAllNotificationsRead POSTs /notifications/read-all")
    func markAllRead() async throws {
        mockHTTP.stub(json: "{}")
        try await client.markAllNotificationsRead()
        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "POST")
        #expect(req.url?.path.hasSuffix("/api/notifications/read-all") == true)
    }

    // MARK: - Notification services

    @Test("createBoardNotificationService POSTs to the board with url+format")
    func createBoardNotificationService() async throws {
        mockHTTP.stub(json: #"{"item":{"id":"ns1","userId":null,"boardId":"b1","url":"https://hook","format":"text","createdAt":null,"updatedAt":null}}"#)
        _ = try await client.createBoardNotificationService(boardId: "b1", url: "https://hook", format: "text")

        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "POST")
        #expect(req.url?.path.hasSuffix("/api/boards/b1/notification-services") == true)
        let json = try body(of: req)
        #expect(json["url"] as? String == "https://hook")
        #expect(json["format"] as? String == "text")
    }

    @Test("createUserNotificationService POSTs to the user")
    func createUserNotificationService() async throws {
        mockHTTP.stub(json: #"{"item":{"id":"ns2","userId":"u1","boardId":null,"url":"https://h","format":"markdown","createdAt":null,"updatedAt":null}}"#)
        _ = try await client.createUserNotificationService(userId: "u1", url: "https://h", format: "markdown")
        let req = try #require(mockHTTP.lastRequest)
        #expect(req.url?.path.hasSuffix("/api/users/u1/notification-services") == true)
    }

    @Test("deleteNotificationService DELETEs /notification-services/{id}")
    func deleteNotificationService() async throws {
        mockHTTP.stub(json: #"{"item":{"id":"ns1","userId":"u1","boardId":null,"url":"https://h","format":"text","createdAt":null,"updatedAt":null}}"#)
        try await client.deleteNotificationService(id: "ns1")
        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "DELETE")
        #expect(req.url?.path.hasSuffix("/api/notification-services/ns1") == true)
    }

    @Test("testNotificationService POSTs /notification-services/{id}/test")
    func testNotificationService() async throws {
        mockHTTP.stub(json: "{}")
        try await client.testNotificationService(id: "ns1")
        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "POST")
        #expect(req.url?.path.hasSuffix("/api/notification-services/ns1/test") == true)
    }

    // MARK: - Project background

    @Test("updateProject PATCHes /projects/{id} with background fields")
    func updateProject() async throws {
        mockHTTP.stub(json: #"{"item":{"id":"p1","ownerProjectManagerId":null,"backgroundImageId":null,"name":"P","description":null,"backgroundType":"gradient","backgroundGradient":"ocean-dive","isHidden":false,"isFavorite":null,"createdAt":null,"updatedAt":null}}"#)
        let project = try await client.updateProject(
            id: "p1", patch: ProjectPatch(backgroundType: "gradient", backgroundGradient: "ocean-dive"))

        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "PATCH")
        #expect(req.url?.path.hasSuffix("/api/projects/p1") == true)
        let json = try body(of: req)
        #expect(json["backgroundType"] as? String == "gradient")
        #expect(json["backgroundGradient"] as? String == "ocean-dive")
        #expect(project.backgroundGradient == "ocean-dive")
    }

    @Test("uploadBackgroundImage sends multipart POST to the project")
    func uploadBackgroundImage() async throws {
        mockHTTP.stub(json: #"{"item":{"id":"bg1","projectId":"p1","size":"1024","url":"https://x/bg.png","thumbnailUrls":{"outside360":"https://x/t.png"},"createdAt":null,"updatedAt":null}}"#)
        let img = try await client.uploadBackgroundImage(
            projectId: "p1", fileName: "bg.png", mimeType: "image/png", data: Data([0x1, 0x2]))

        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "POST")
        #expect(req.url?.path.hasSuffix("/api/projects/p1/background-images") == true)
        #expect(req.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data") == true)
        #expect(img.id == "bg1")
    }

    @Test("deleteBackgroundImage DELETEs /background-images/{id}")
    func deleteBackgroundImage() async throws {
        mockHTTP.stub(json: #"{"item":{"id":"bg1","projectId":"p1","size":"1024","url":"https://x/bg.png","thumbnailUrls":{},"createdAt":null,"updatedAt":null}}"#)
        try await client.deleteBackgroundImage(id: "bg1")
        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "DELETE")
        #expect(req.url?.path.hasSuffix("/api/background-images/bg1") == true)
    }

    // MARK: - Webhooks

    @Test("getWebhooks GETs /webhooks and decodes events as an array")
    func getWebhooks() async throws {
        mockHTTP.stub(json: #"{"items":[{"id":"w1","name":"Hook","url":"https://h","accessToken":null,"events":["cardCreate","cardUpdate"],"excludedEvents":null,"createdAt":null,"updatedAt":null}]}"#)
        let hooks = try await client.getWebhooks()

        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "GET")
        #expect(req.url?.path.hasSuffix("/api/webhooks") == true)
        #expect(hooks.first?.events == ["cardCreate", "cardUpdate"])
    }

    @Test("createWebhook POSTs comma-joined events")
    func createWebhook() async throws {
        mockHTTP.stub(json: #"{"item":{"id":"w1","name":"Hook","url":"https://h","accessToken":null,"events":["cardCreate","cardDelete"],"excludedEvents":null,"createdAt":null,"updatedAt":null}}"#)
        _ = try await client.createWebhook(name: "Hook", url: "https://h", events: ["cardCreate", "cardDelete"])

        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "POST")
        #expect(req.url?.path.hasSuffix("/api/webhooks") == true)
        let json = try body(of: req)
        #expect(json["name"] as? String == "Hook")
        #expect(json["events"] as? String == "cardCreate,cardDelete") // request sends a comma string
    }

    @Test("deleteWebhook DELETEs /webhooks/{id}")
    func deleteWebhook() async throws {
        mockHTTP.stub(json: #"{"item":{"id":"w1","name":"Hook","url":"https://h","accessToken":null,"events":null,"excludedEvents":null,"createdAt":null,"updatedAt":null}}"#)
        try await client.deleteWebhook(id: "w1")
        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "DELETE")
        #expect(req.url?.path.hasSuffix("/api/webhooks/w1") == true)
    }

    // MARK: - Config

    @Test("getConfig GETs /config and decodes SMTP fields")
    func getConfig() async throws {
        mockHTTP.stub(json: #"{"item":{"id":"1","smtpHost":"smtp.example.com","smtpPort":587,"smtpName":null,"smtpSecure":true,"smtpTlsRejectUnauthorized":true,"smtpUser":"u","smtpPassword":"p","smtpFrom":"a@b.c","createdAt":null,"updatedAt":null}}"#)
        let config = try await client.getConfig()

        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "GET")
        #expect(req.url?.path.hasSuffix("/api/config") == true)
        #expect(config.smtpHost == "smtp.example.com")
        #expect(config.smtpPort == 587)
    }

    @Test("updateConfig PATCHes /config with only the set fields")
    func updateConfig() async throws {
        mockHTTP.stub(json: #"{"item":{"id":"1","smtpHost":"new.host","smtpPort":25,"smtpName":null,"smtpSecure":false,"smtpTlsRejectUnauthorized":true,"smtpUser":null,"smtpPassword":null,"smtpFrom":null,"createdAt":null,"updatedAt":null}}"#)
        _ = try await client.updateConfig(patch: ConfigPatch(smtpHost: "new.host", smtpPort: 25))

        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "PATCH")
        #expect(req.url?.path.hasSuffix("/api/config") == true)
        let json = try body(of: req)
        #expect(json["smtpHost"] as? String == "new.host")
        #expect(json["smtpPort"] as? Int == 25)
        #expect(json.keys.contains("smtpUser") == false) // unset → omitted
    }

    @Test("testSMTP POSTs /config/test-smtp")
    func testSMTP() async throws {
        mockHTTP.stub(json: "{}")
        try await client.testSMTP()
        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "POST")
        #expect(req.url?.path.hasSuffix("/api/config/test-smtp") == true)
    }
}
