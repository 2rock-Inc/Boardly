import Foundation
import Testing
@testable import BoardlyKit

@Suite("BoardPayload — custom fields sideload")
struct BoardPayloadCustomFieldsTests {
    private let json = """
    {
      "item": { "id": "b1", "projectId": "p1", "name": "Board" },
      "included": {
        "lists": [{ "id": "l1", "boardId": "b1", "type": "active", "name": "L", "position": 1 }],
        "cards": [{ "id": "c1", "boardId": "b1", "listId": "l1", "name": "Card", "position": 1 }],
        "customFieldGroups": [
          { "id": "g1", "boardId": "b1", "cardId": null, "baseCustomFieldGroupId": "bg1", "position": 1, "name": "Product tracking", "createdAt": null, "updatedAt": null }
        ],
        "customFields": [
          { "id": "f2", "baseCustomFieldGroupId": null, "customFieldGroupId": "g1", "position": 2, "name": "Estimate", "showOnFrontOfCard": false, "createdAt": null, "updatedAt": null },
          { "id": "f1", "baseCustomFieldGroupId": null, "customFieldGroupId": "g1", "position": 1, "name": "Priority", "showOnFrontOfCard": true, "createdAt": null, "updatedAt": null }
        ],
        "customFieldValues": [
          { "id": "v1", "cardId": "c1", "customFieldGroupId": "g1", "customFieldId": "f1", "content": "High", "createdAt": null, "updatedAt": null }
        ]
      }
    }
    """

    private func decoded() throws -> (BoardPayload, Card, CustomFieldGroup) {
        let payload = try BoardPayload.decode(from: Data(json.utf8))
        let card = try #require(payload.card(id: "c1"))
        let group = try #require(payload.boardCustomFieldGroups().first)
        return (payload, card, group)
    }

    @Test("decode sideloads groups, fields and values")
    func decodeSideloads() throws {
        let (payload, _, _) = try decoded()
        #expect(payload.customFieldGroups.count == 1)
        #expect(payload.customFields.count == 2)
        #expect(payload.customFieldValues.count == 1)
    }

    @Test("customFieldGroups(for:) returns the board's groups")
    func groupsForCard() throws {
        let (payload, card, _) = try decoded()
        #expect(payload.customFieldGroups(for: card).map(\.id) == ["g1"])
    }

    @Test("fields(in:) sorts by position")
    func fieldsSorted() throws {
        let (payload, _, group) = try decoded()
        #expect(payload.fields(in: group).map(\.id) == ["f1", "f2"])
    }

    @Test("value(on:group:field:) resolves the (card,group,field) triple")
    func valueLookup() throws {
        let (payload, card, group) = try decoded()
        let f1 = try #require(payload.fields(in: group).first { $0.id == "f1" })
        let f2 = try #require(payload.fields(in: group).first { $0.id == "f2" })
        #expect(payload.value(on: card, group: group, field: f1)?.content == "High")
        #expect(payload.value(on: card, group: group, field: f2) == nil)
    }
}

@Suite("PlankaClient — custom field endpoints")
struct PlankaClientCustomFieldsTests {
    let profile = makeProfile(baseURL: URL(string: "https://planka.example.com")!)
    let mockHTTP = MockHTTPClient()
    var client: PlankaClient {
        PlankaClient(
            profile: profile,
            tokenStore: TokenStore(profileID: profile.id, keychainStore: MockKeychainStore()),
            httpClient: mockHTTP)
    }

    private func body(of req: URLRequest) throws -> [String: Any] {
        let data = try #require(req.httpBody)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private let groupJSON = #"{"item":{"id":"g1","boardId":"b1","cardId":null,"baseCustomFieldGroupId":"bg1","position":65536,"name":"Tracking","createdAt":null,"updatedAt":null}}"#
    private let fieldJSON = #"{"item":{"id":"f1","baseCustomFieldGroupId":null,"customFieldGroupId":"g1","position":65536,"name":"Priority","showOnFrontOfCard":false,"createdAt":null,"updatedAt":null}}"#
    private let valueJSON = #"{"item":{"id":"v1","cardId":"c1","customFieldGroupId":"g1","customFieldId":"f1","content":"High","createdAt":null,"updatedAt":null}}"#

    @Test("createBoardCustomFieldGroup from base POSTs baseCustomFieldGroupId, omits name")
    func createFromBase() async throws {
        mockHTTP.stub(json: groupJSON)
        _ = try await client.createBoardCustomFieldGroup(boardId: "b1", position: 65536, baseCustomFieldGroupId: "bg1")
        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "POST")
        #expect(req.url?.path.hasSuffix("/api/boards/b1/custom-field-groups") == true)
        let b = try body(of: req)
        #expect(b["baseCustomFieldGroupId"] as? String == "bg1")
        #expect(b["name"] == nil) // nil optional omitted, not sent as null
    }

    @Test("createBoardCustomFieldGroup ad-hoc POSTs name, omits base id")
    func createAdHoc() async throws {
        mockHTTP.stub(json: groupJSON)
        _ = try await client.createBoardCustomFieldGroup(boardId: "b1", position: 65536, name: "Ad hoc")
        let b = try body(of: #require(mockHTTP.lastRequest))
        #expect(b["name"] as? String == "Ad hoc")
        #expect(b["baseCustomFieldGroupId"] == nil)
    }

    @Test("updateCustomFieldGroup PATCHes /custom-field-groups/{id}")
    func updateGroup() async throws {
        mockHTTP.stub(json: groupJSON)
        _ = try await client.updateCustomFieldGroup(id: "g1", name: "Renamed")
        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "PATCH")
        #expect(req.url?.path.hasSuffix("/api/custom-field-groups/g1") == true)
        #expect(try body(of: req)["name"] as? String == "Renamed")
    }

    @Test("deleteCustomFieldGroup DELETEs /custom-field-groups/{id}")
    func deleteGroup() async throws {
        mockHTTP.stub(json: groupJSON)
        try await client.deleteCustomFieldGroup(id: "g1")
        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "DELETE")
        #expect(req.url?.path.hasSuffix("/api/custom-field-groups/g1") == true)
    }

    @Test("createCustomFieldInGroup POSTs name+position to the group")
    func createField() async throws {
        mockHTTP.stub(json: fieldJSON)
        _ = try await client.createCustomFieldInGroup(groupId: "g1", name: "Priority", position: 65536)
        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "POST")
        #expect(req.url?.path.hasSuffix("/api/custom-field-groups/g1/custom-fields") == true)
        #expect(try body(of: req)["name"] as? String == "Priority")
    }

    @Test("deleteCustomField DELETEs /custom-fields/{id}")
    func deleteField() async throws {
        mockHTTP.stub(json: fieldJSON)
        try await client.deleteCustomField(id: "f1")
        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "DELETE")
        #expect(req.url?.path.hasSuffix("/api/custom-fields/f1") == true)
    }

    @Test("setCustomFieldValue PATCHes the compound value path with content")
    func setValue() async throws {
        mockHTTP.stub(json: valueJSON)
        _ = try await client.setCustomFieldValue(cardId: "c1", groupId: "g1", fieldId: "f1", content: "High")
        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "PATCH")
        // Plural `custom-field-values`, literal `$` before the field id.
        #expect(req.url?.path.hasSuffix("/api/cards/c1/custom-field-values/customFieldGroupId:g1:customFieldId:$f1") == true)
        #expect(try body(of: req)["content"] as? String == "High")
    }

    @Test("clearCustomFieldValue DELETEs the singular value path")
    func clearValue() async throws {
        mockHTTP.stub(json: valueJSON)
        try await client.clearCustomFieldValue(cardId: "c1", groupId: "g1", fieldId: "f1")
        let req = try #require(mockHTTP.lastRequest)
        #expect(req.httpMethod == "DELETE")
        // Singular `custom-field-value` (differs from set), literal `$`.
        #expect(req.url?.path.hasSuffix("/api/cards/c1/custom-field-value/customFieldGroupId:g1:customFieldId:$f1") == true)
    }
}
