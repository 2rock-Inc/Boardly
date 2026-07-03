import Foundation

public struct ProjectsPayload: Sendable {
    public let projects: [Project]
    public let boards: [Board]
    public let users: [User]
    public let boardMemberships: [BoardMembership]
    public let backgroundImages: [BackgroundImage]
    public let projectManagers: [ProjectManager]
    public let baseCustomFieldGroups: [BaseCustomFieldGroup]
    public let customFields: [CustomField]

    public init(
        projects: [Project],
        boards: [Board],
        users: [User] = [],
        boardMemberships: [BoardMembership] = [],
        backgroundImages: [BackgroundImage] = [],
        projectManagers: [ProjectManager] = [],
        baseCustomFieldGroups: [BaseCustomFieldGroup] = [],
        customFields: [CustomField] = []
    ) {
        self.projects = projects
        self.boards = boards
        self.users = users
        self.boardMemberships = boardMemberships
        self.backgroundImages = backgroundImages
        self.projectManagers = projectManagers
        self.baseCustomFieldGroups = baseCustomFieldGroups
        self.customFields = customFields
    }

    /// Project managers (responsables) of the project.
    public func managers(for project: Project) -> [ProjectManager] {
        projectManagers.filter { $0.projectId == project.id }
    }

    /// The user records for the project's managers.
    public func managerUsers(for project: Project) -> [User] {
        let ids = Set(managers(for: project).map(\.userId))
        return users.filter { ids.contains($0.id) }
    }

    /// Base (project-level) custom field groups, inherited by all boards.
    public func baseGroups(for project: Project) -> [BaseCustomFieldGroup] {
        baseCustomFieldGroups.filter { $0.projectId == project.id }
    }

    /// Custom fields belonging to a base group, ordered by position.
    public func fields(in group: BaseCustomFieldGroup) -> [CustomField] {
        customFields.filter { $0.baseCustomFieldGroupId == group.id }
            .sorted { ($0.position ?? 0) < ($1.position ?? 0) }
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
