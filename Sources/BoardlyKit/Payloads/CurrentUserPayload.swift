import Foundation

/// Result of `GET /users/{id}` for the current user: the user record plus their
/// sideloaded notification services.
public struct CurrentUserPayload: Sendable {
    public let user: User
    public let notificationServices: [NotificationService]

    public init(user: User, notificationServices: [NotificationService]) {
        self.user = user
        self.notificationServices = notificationServices
    }

    /// Whether the user has instance-admin privileges (gates admin-only screens).
    public var isAdmin: Bool { user.role == "admin" }
}
