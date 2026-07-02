import Testing
import Foundation
@testable import BoardlyKit

@Suite("ProjectsPayload — background images")
struct ProjectsPayloadTests {
    private func project(id: String, backgroundImageId: String?) throws -> Project {
        let bg = backgroundImageId.map { "\"\($0)\"" } ?? "null"
        let json = #"{"id":"\#(id)","backgroundImageId":\#(bg),"name":"P","isHidden":false}"#
        return try JSONDecoder.planka.decode(Project.self, from: Data(json.utf8))
    }

    private func image(id: String, projectId: String) throws -> BackgroundImage {
        let json = #"{"id":"\#(id)","projectId":"\#(projectId)","size":"1024","url":"https://x/\#(id).png","thumbnailUrls":{}}"#
        return try JSONDecoder.planka.decode(BackgroundImage.self, from: Data(json.utf8))
    }

    @Test("resolves the project's background image by id")
    func resolvesBackgroundImage() throws {
        let p = try project(id: "p1", backgroundImageId: "bg1")
        let payload = ProjectsPayload(
            projects: [p], boards: [],
            backgroundImages: [try image(id: "bg1", projectId: "p1"), try image(id: "bg2", projectId: "p1")]
        )
        #expect(payload.backgroundImage(for: p)?.id == "bg1")
    }

    @Test("returns nil when the project has no background image")
    func noBackgroundImage() throws {
        let p = try project(id: "p1", backgroundImageId: nil)
        let payload = ProjectsPayload(projects: [p], boards: [], backgroundImages: [try image(id: "bg1", projectId: "p1")])
        #expect(payload.backgroundImage(for: p) == nil)
    }
}
