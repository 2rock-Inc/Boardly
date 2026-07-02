import Foundation

/// Result of `GET /notifications`: the (unread) notifications plus the creator
/// users sideloaded alongside them, so the UI can attribute each notification
/// to a person without a follow-up request per creator.
public struct NotificationsPayload: Sendable {
    public let notifications: [PlankaNotification]
    public let users: [User]

    public init(notifications: [PlankaNotification], users: [User]) {
        self.notifications = notifications
        self.users = users
    }

    /// The user who triggered `notification`, if their record was sideloaded.
    public func creator(of notification: PlankaNotification) -> User? {
        guard let id = notification.creatorUserId else { return nil }
        return users.first { $0.id == id }
    }
}
