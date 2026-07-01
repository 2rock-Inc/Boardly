import Foundation

public struct ProjectsPayload: Sendable {
    public let projects: [Project]
    public let boards: [Board]
    public let users: [User]
    public let boardMemberships: [BoardMembership]

    public init(
        projects: [Project],
        boards: [Board],
        users: [User] = [],
        boardMemberships: [BoardMembership] = []
    ) {
        self.projects = projects
        self.boards = boards
        self.users = users
        self.boardMemberships = boardMemberships
    }

    public func boards(for project: Project) -> [Board] {
        boards.filter { $0.projectId == project.id }
              .sorted { ($0.position ?? 0) < ($1.position ?? 0) }
    }

    /// Distinct users who are members of any board in the project.
    public func members(for project: Project) -> [User] {
        let ids = Set(boardMemberships.filter { $0.projectId == project.id }.map(\.userId))
        return users.filter { ids.contains($0.id) }
    }
}
