import Foundation
import Testing
@testable import BoardlyKit

@Suite("ProjectPatch encoding")
struct ProjectPatchTests {
    private func encoded(_ patch: ProjectPatch) throws -> [String: Any] {
        let data = try JSONEncoder().encode(patch)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test("omits unset fields")
    func omitsUnset() throws {
        let json = try encoded(ProjectPatch(backgroundGradient: "ocean-dive"))
        #expect(json["backgroundGradient"] as? String == "ocean-dive")
        #expect(json.keys.contains("name") == false)
        #expect(json.keys.contains("backgroundType") == false)
    }

    @Test("gradient selection sets type + gradient")
    func gradientSelection() throws {
        let json = try encoded(ProjectPatch(backgroundType: "gradient", backgroundGradient: "sun-scream"))
        #expect(json["backgroundType"] as? String == "gradient")
        #expect(json["backgroundGradient"] as? String == "sun-scream")
    }

    @Test("image selection sets type + imageId")
    func imageSelection() throws {
        let json = try encoded(ProjectPatch(backgroundType: "image", backgroundImageId: "bg1"))
        #expect(json["backgroundType"] as? String == "image")
        #expect(json["backgroundImageId"] as? String == "bg1")
    }

    @Test("clearBackground emits an explicit null backgroundType")
    func clearBackground() throws {
        let json = try encoded(ProjectPatch(clearBackground: true))
        #expect(json.keys.contains("backgroundType"))
        #expect(json["backgroundType"] is NSNull)
    }
}

@Suite("WebhookPatch encoding")
struct WebhookPatchTests {
    private func encoded(_ patch: WebhookPatch) throws -> [String: Any] {
        let data = try JSONEncoder().encode(patch)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test("joins events into a comma-separated string")
    func joinsEvents() throws {
        let json = try encoded(WebhookPatch(events: ["cardCreate", "cardUpdate", "cardDelete"]))
        #expect(json["events"] as? String == "cardCreate,cardUpdate,cardDelete")
    }

    @Test("omits nil events entirely")
    func omitsNilEvents() throws {
        let json = try encoded(WebhookPatch(name: "Hook", url: "https://h"))
        #expect(json["name"] as? String == "Hook")
        #expect(json.keys.contains("events") == false)
        #expect(json.keys.contains("excludedEvents") == false)
    }
}
