import SwiftUI
import BoardlyKit

/// The Activity tab: the current user's unread notifications, grouped by recency.
/// Functional for Phase 5; Phase 6 restyles it to the polished design (screen 11).
struct ActivityView: View {
    let viewModel: NotificationsViewModel

    private var sections: [(title: String, items: [PlankaNotification])] {
        let all = viewModel.notifications
        let titles = ["Today", "This week", "Earlier"]
        return titles.enumerated().compactMap { index, title in
            let items = all.filter { viewModel.bucket($0) == index }
            return items.isEmpty ? nil : (title, items)
        }
    }

    var body: some View {
        ZStack {
            Color.boardlyBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    if let error = viewModel.error, viewModel.notifications.isEmpty {
                        errorState(error)
                    } else if viewModel.notifications.isEmpty {
                        emptyState
                    } else {
                        ForEach(sections, id: \.title) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                BoardlyFieldLabel(section.title)
                                VStack(spacing: 0) {
                                    ForEach(Array(section.items.enumerated()), id: \.element.id) { index, notification in
                                        if index > 0 { Divider().padding(.leading, 52) }
                                        row(notification)
                                    }
                                }
                                .boardlyCard(padding: 0)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Activity")
                .font(.boardlyTitle)
                .foregroundStyle(Color.boardlyInk)
            Spacer()
            if !viewModel.notifications.isEmpty {
                Button("Mark all as read") { Task { await viewModel.markAllRead() } }
                    .font(.boardlyCallout)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.top, 8)
    }

    private func row(_ notification: PlankaNotification) -> some View {
        Button {
            Task { await viewModel.markRead(notification) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                AvatarView(name: viewModel.creatorName(notification), size: 36, bordered: false)

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.line(for: notification))
                        .foregroundStyle(Color.boardlyInk)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        if let excerpt = viewModel.excerpt(notification), !excerpt.isEmpty {
                            Text("« \(excerpt) »")
                                .foregroundStyle(Color.boardlyTextSecondary)
                                .lineLimit(1)
                            Text("·").foregroundStyle(Color.boardlyTextTertiary)
                        }
                        Text(viewModel.relativeTime(notification))
                            .foregroundStyle(Color.boardlyTextTertiary)
                    }
                    .font(.boardlyCallout)
                }

                Spacer(minLength: 8)

                Circle()
                    .fill(Color.labelGreen)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
            }
            .padding(14)
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.badge")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Color.boardlyTextTertiary)
            Text("No notifications")
                .font(.boardlyHeadline)
                .foregroundStyle(Color.boardlyInk)
            Text("You’re all caught up.")
                .font(.boardlyBody)
                .foregroundStyle(Color.boardlyTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    /// Distinct from the empty state: a failed fetch must not read as "all caught up".
    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Color.labelRose)
            Text(message)
                .font(.boardlyBody)
                .foregroundStyle(Color.boardlyTextSecondary)
                .multilineTextAlignment(.center)
            Button("Retry") { Task { await viewModel.load() } }
                .buttonStyle(.boardlySecondary)
                .fixedSize()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}
