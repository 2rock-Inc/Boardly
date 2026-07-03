import BoardlyKit
import Foundation
import SwiftUI

@Observable
@MainActor
final class NotificationsViewModel {
    private let client: PlankaClient
    private(set) var payload: NotificationsPayload?
    private(set) var isLoading = false
    var error: String?

    init(client: PlankaClient) {
        self.client = client
    }

    var notifications: [PlankaNotification] {
        (payload?.notifications ?? []).sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    /// `GET /notifications` returns only *unread* notifications, so every item
    /// here is unread — the count doubles as the tab badge.
    var unreadCount: Int { payload?.notifications.count ?? 0 }

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            payload = try await client.getNotifications()
        } catch {
            self.error = String(localized: "Couldn’t load notifications.")
        }
    }

    /// Mark one notification read — optimistically remove it (the list is
    /// unread-only), rolling back with a reload if the request fails.
    func markRead(_ notification: PlankaNotification) async {
        guard let current = payload else { return }
        payload = NotificationsPayload(
            notifications: current.notifications.filter { $0.id != notification.id },
            users: current.users)
        do {
            _ = try await client.setNotificationRead(id: notification.id, isRead: true)
        } catch {
            await load()
        }
    }

    func markAllRead() async {
        let previous = payload
        if let current = payload {
            payload = NotificationsPayload(notifications: [], users: current.users)
        }
        do {
            try await client.markAllNotificationsRead()
        } catch {
            payload = previous
            self.error = String(localized: "Couldn’t mark all as read.")
        }
    }

    // MARK: - Presentation helpers

    func creatorName(_ notification: PlankaNotification) -> String {
        payload?.creator(of: notification)?.name ?? "Someone"
    }

    /// The card name carried in the notification's free-form `data` payload.
    func cardName(_ notification: PlankaNotification) -> String? {
        guard let dict = notification.data.value as? [String: AnyCodable] else { return nil }
        if let card = dict["card"]?.value as? [String: AnyCodable],
           let name = card["name"]?.value as? String { return name }
        return nil
    }

    /// A short excerpt of a comment, when the notification carries one.
    func excerpt(_ notification: PlankaNotification) -> String? {
        (notification.data.value as? [String: AnyCodable])?["text"]?.value as? String
    }

    /// A rendered line — actor + action + subject — with the actor and the card
    /// name emphasized (bold), matching the Activity design.
    func line(for notification: PlankaNotification) -> AttributedString {
        let actor = creatorName(notification)
        let card = cardName(notification) ?? "a card"
        let phrasing: (prefix: String, suffix: String) = switch notification.type {
        case "mentionInComment": (" mentioned you in ", "")
        case "commentCard": (" commented on ", "")
        case "addMemberToCard": (" assigned you to ", "")
        case "moveCard": (" moved ", "")
        default: (" updated ", "")
        }

        var result = AttributedString(actor)
        result.font = .boardlyBody.bold()
        var middle = AttributedString(phrasing.prefix)
        middle.font = .boardlyBody
        var subject = AttributedString(card)
        subject.font = .boardlyBody.bold()
        result.append(middle)
        result.append(subject)
        if !phrasing.suffix.isEmpty {
            var tail = AttributedString(phrasing.suffix)
            tail.font = .boardlyBody
            result.append(tail)
        }
        return result
    }

    func relativeTime(_ notification: PlankaNotification) -> String {
        guard let date = notification.createdAt else { return "" }
        return Self.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    /// Recency bucket for section grouping: 0 today, 1 this week, 2 earlier.
    func bucket(_ notification: PlankaNotification) -> Int {
        guard let date = notification.createdAt else { return 2 }
        if Calendar.current.isDateInToday(date) { return 0 }
        if date > Date().addingTimeInterval(-7 * 86400) { return 1 }
        return 2
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = .autoupdatingCurrent
        f.unitsStyle = .abbreviated
        return f
    }()
}
