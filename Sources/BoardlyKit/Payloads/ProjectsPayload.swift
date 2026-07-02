import Foundation

public struct ProjectsPayload: Sendable {
    public let projects: [Project]
    public let boards: [Board]
    public let users: [User]
    public let boardMemberships: [BoardMembership]
    public let backgroundImages: [BackgroundImage]

    public init(
        projects: [Project],
        boards: [Board],
        users: [User] = [],
        boardMemberships: [BoardMembership] = [],
        backgroundImages: [BackgroundImage] = []
    ) {
        self.projects = projects
        self.boards = boards
        self.users = users
        self.boardMemberships = boardMemberships
        self.backgroundImages = backgroundImages
    }

    public func boards(for project: Project) -> [Board] {
        boards.filter { $0.projectId == project.id }
              .sorted { ($0.position ?? 0) < ($1.position ?? 0) }
    }

    /// The uploaded background image currently set on the project, if any.
    public func backgroundImage(for project: Project) -> BackgroundImage? {
        guard let id = project.backgroundImageId else { return nil }
        return backgroundImages.first { $0.id == id }
    }

    /// Distinct users who are members of any board in the project.
    public func members(for project: Project) -> [User] {
        let ids = Set(boardMemberships.filter { $0.projectId == project.id }.map(\.userId))
        return users.filter { ids.contains($0.id) }
    }
}
