import Testing
import Foundation
@testable import BoardlyKit

@Suite("PlankaClient — project edit endpoints")
struct PlankaClientProjectEditTests {
    let profile = makeProfile(baseURL: URL(string: "https://planka.example.com")!)
    let mockHTTP = MockHTTPClient()
    var client: PlankaClient {
        PlankaClient(profile: profile,
                     tokenStore: TokenStore(profileID: profile.id, keychainStore: MockKeychainStore()),
                     httpClient: mockHTTP)
    }

    private func body(of req: URLRequest) throws -> [String: Any] {
        let data = try #require(req.httpBody)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test("deleteProject DELETEs /projects/{id}")
    func deleteProject() async throws {
        mockHTTP.stub(json: #"{"item":{"id":"p1","ownerProjectManagerId":null,"backgroundImageId":null,"name":"P","description":null,"backgroundType":null,"backgroundGradient":null,"isHidden":false,"isFavorite":null,"createdAt":null,"updatedAt":null}}"#)
        try await client.deleteProject(id: "p1")
        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "DELETE")
        #expect(req.url?.path.hasSuffix("/api/projects/p1") == true)
    }

    @Test("addProjectManager POSTs userId to the project")
    func addProjectManager() async throws {
        mockHTTP.stub(json: #"{"item":{"id":"pm1","projectId":"p1","userId":"u2","createdAt":null,"updatedAt":null}}"#)
        _ = try await client.addProjectManager(projectId: "p1", userId: "u2")
        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "POST")
        #expect(req.url?.path.hasSuffix("/api/projects/p1/project-managers") == true)
        #expect(try body(of: req)["userId"] as? String == "u2")
    }

    @Test("removeProjectManager DELETEs /project-managers/{id}")
    func removeProjectManager() async throws {
        mockHTTP.stub(json: #"{"item":{"id":"pm1","projectId":"p1","userId":"u2","createdAt":null,"updatedAt":null}}"#)
        try await client.removeProjectManager(id: "pm1")
        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "DELETE")
        #expect(req.url?.path.hasSuffix("/api/project-managers/pm1") == true)
    }

    @Test("createBaseCustomFieldGroup POSTs name to the project")
    func createBaseGroup() async throws {
        mockHTTP.stub(json: #"{"item":{"id":"g1","projectId":"p1","name":"Tracking","createdAt":null,"updatedAt":null}}"#)
        _ = try await client.createBaseCustomFieldGroup(projectId: "p1", name: "Tracking")
        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "POST")
        #expect(req.url?.path.hasSuffix("/api/projects/p1/base-custom-field-groups") == true)
        #expect(try body(of: req)["name"] as? String == "Tracking")
    }

    @Test("createBaseCustomField POSTs to the group with name + position")
    func createBaseField() async throws {
        mockHTTP.stub(json: #"{"item":{"id":"cf1","baseCustomFieldGroupId":"g1","customFieldGroupId":null,"position":65536,"name":"Priority","showOnFrontOfCard":null,"createdAt":null,"updatedAt":null}}"#)
        _ = try await client.createBaseCustomField(groupId: "g1", name: "Priority", position: 65536)
        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "POST")
        #expect(req.url?.path.hasSuffix("/api/base-custom-field-groups/g1/custom-fields") == true)
        #expect(try body(of: req)["name"] as? String == "Priority")
    }

    @Test("ProjectPatch encodes description and isHidden")
    func projectPatchEncoding() throws {
        let data = try JSONEncoder().encode(ProjectPatch(name: "N", description: "D", isHidden: true))
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["name"] as? String == "N")
        #expect(json["description"] as? String == "D")
        #expect(json["isHidden"] as? Bool == true)
        #expect(json.keys.contains("backgroundType") == false)
    }
}

@Suite("ProjectsPayload — managers & base custom fields")
struct ProjectsPayloadEditTests {
    private func project() throws -> Project {
        try JSONDecoder.planka.decode(Project.self, from: Data(#"{"id":"p1","name":"P","isHidden":false}"#.utf8))
    }

    @Test("managers + managerUsers resolve by project")
    func managers() throws {
        let p = try project()
        let payload = ProjectsPayload(
            projects: [p], boards: [],
            users: [decodeUser("u1", "Marie"), decodeUser("u2", "Paul")],
            projectManagers: [
                pm("pm1", "p1", "u1"), pm("pm2", "p1", "u2"), pm("pm3", "pOther", "u3"),
            ])
        #expect(payload.managers(for: p).map(\.id) == ["pm1", "pm2"])
        #expect(Set(payload.managerUsers(for: p).map(\.id)) == ["u1", "u2"])
    }

    @Test("base groups and their fields resolve and sort by position")
    func baseGroups() throws {
        let p = try project()
        let payload = ProjectsPayload(
            projects: [p], boards: [],
            baseCustomFieldGroups: [bg("g1", "p1", "Tracking"), bg("g2", "pOther", "X")],
            customFields: [cf("cf2", "g1", "B", 2), cf("cf1", "g1", "A", 1)])
        let groups = payload.baseGroups(for: p)
        #expect(groups.map(\.id) == ["g1"])
        #expect(payload.fields(in: groups[0]).map(\.name) == ["A", "B"])
    }

    // Helpers
    private func decodeUser(_ id: String, _ name: String) -> User {
        try! JSONDecoder.planka.decode(User.self, from: Data(#"{"id":"\#(id)","role":"member","name":"\#(name)","isDeactivated":false}"#.utf8))
    }
    private func pm(_ id: String, _ pid: String, _ uid: String) -> ProjectManager {
        try! JSONDecoder.planka.decode(ProjectManager.self, from: Data(#"{"id":"\#(id)","projectId":"\#(pid)","userId":"\#(uid)"}"#.utf8))
    }
    private func bg(_ id: String, _ pid: String, _ name: String) -> BaseCustomFieldGroup {
        try! JSONDecoder.planka.decode(BaseCustomFieldGroup.self, from: Data(#"{"id":"\#(id)","projectId":"\#(pid)","name":"\#(name)"}"#.utf8))
    }
    private func cf(_ id: String, _ gid: String, _ name: String, _ pos: Double) -> CustomField {
        try! JSONDecoder.planka.decode(CustomField.self, from: Data(#"{"id":"\#(id)","baseCustomFieldGroupId":"\#(gid)","name":"\#(name)","position":\#(pos)}"#.utf8))
    }
}
