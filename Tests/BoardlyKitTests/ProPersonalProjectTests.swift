import Foundation
import Testing
@testable import BoardlyKit

/// PLANKA Pro prepends an unnamed personal project to `GET /projects`: every field
/// comes back null but the id, the timestamps and the owner. Decoding it used to throw
/// (`name` and `isHidden` were non-optional), and because `items` is decoded as one
/// array, that single item took the whole projects screen down with it — the user saw
/// "Couldn't read the server's response." and no projects at all.
///
/// The payload below is the real one, captured from pro.demo.planka.cloud.
@Suite("PLANKA Pro — unnamed personal project")
struct ProPersonalProjectTests {
    private let personalProject = #"""
    {
      "id": "1680575820910822412",
      "createdAt": "2026-01-04T13:04:09.645Z",
      "updatedAt": "2026-01-04T13:04:09.652Z",
      "ownerProjectManagerId": "1680575820927599629",
      "name": null,
      "description": null,
      "backgroundType": null,
      "backgroundGradient": null,
      "backgroundStockImage": null,
      "backgroundFilter": null,
      "backgroundFilterStrength": null,
      "isHidden": null,
      "backgroundImageId": null,
      "isFavorite": false
    }
    """#

    private func decode(_ json: String) throws -> Project {
        try JSONDecoder.planka.decode(Project.self, from: Data(json.utf8))
    }

    @Test("decodes an all-null personal project instead of throwing")
    func decodesPersonalProject() throws {
        let project = try decode(personalProject)
        #expect(project.id == "1680575820910822412")
        #expect(project.name == nil)
        #expect(project.isHidden == nil)
        // Pro-only keys we don't model yet must stay harmless.
        #expect(project.backgroundType == nil)
    }

    @Test("a null isHidden reads as not hidden")
    func absentHiddenFlagMeansVisible() throws {
        #expect(try decode(personalProject).isEffectivelyHidden == false)
    }

    @Test("listable drops the unnamed project but keeps the named ones")
    func listableFiltersUnnamed() throws {
        let named = #"{"id":"p1","name":"Engineering Office","isHidden":false}"#
        let payload = try ProjectsPayload(
            projects: [decode(personalProject), decode(named)], boards: [])

        #expect(payload.projects.count == 2, "the raw list stays faithful to the server")
        #expect(payload.listable.map(\.id) == ["p1"])
    }

    @Test("a whole Pro projects response decodes end to end")
    func decodesFullResponse() throws {
        // The shape `getProjects()` actually parses: unnamed project first, as Pro sends it.
        let json = #"""
        {"items":[\#(personalProject),{"id":"p1","name":"Engineering Office","isHidden":false}],
         "included":{"boards":[{"id":"b1","projectId":"p1","name":"Sprint","position":1}]}}
        """#
        struct Response: Decodable {
            let items: [Project]
        }
        let decoded = try JSONDecoder.planka.decode(Response.self, from: Data(json.utf8))
        #expect(decoded.items.count == 2)
        #expect(decoded.items.compactMap(\.name) == ["Engineering Office"])
    }
}
