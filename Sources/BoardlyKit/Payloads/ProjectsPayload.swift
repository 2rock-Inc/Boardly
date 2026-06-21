import Foundation

public struct ProjectsPayload: Sendable {
    public let projects: [Project]
    public let boards: [Board]

    public func boards(for project: Project) -> [Board] {
        boards.filter { $0.projectId == project.id }
              .sorted { $0.position < $1.position }
    }
}
