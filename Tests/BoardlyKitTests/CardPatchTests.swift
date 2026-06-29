import Testing
import Foundation
@testable import BoardlyKit

@Suite("CardPatch encoding")
struct CardPatchTests {

    private func encoded(_ patch: CardPatch) throws -> [String: Any] {
        let data = try JSONEncoder().encode(patch)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test("omits unset fields")
    func omitsUnsetFields() throws {
        let json = try encoded(CardPatch(name: "Renamed"))
        #expect(json["name"] as? String == "Renamed")
        #expect(json.keys.contains("description") == false)
        #expect(json.keys.contains("dueDate") == false)
    }

    @Test("encodes dueDate as a fractional ISO-8601 string, not a number")
    func encodesDueDateAsISOString() throws {
        let due = Date(timeIntervalSince1970: 1_700_000_000)
        let json = try encoded(CardPatch(dueDate: due))
        let string = try #require(json["dueDate"] as? String)

        #expect(ISO8601Formatters.fractional.date(from: string) == due)
    }

    @Test("clearDueDate emits an explicit null")
    func clearDueDateEmitsNull() throws {
        let json = try encoded(CardPatch(clearDueDate: true))
        #expect(json.keys.contains("dueDate"))
        #expect(json["dueDate"] is NSNull)
    }

    @Test("clearDueDate wins over a provided dueDate")
    func clearDueDateTakesPrecedence() throws {
        let json = try encoded(CardPatch(dueDate: Date(), clearDueDate: true))
        #expect(json["dueDate"] is NSNull)
    }
}
