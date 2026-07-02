import SwiftUI
import BoardlyKit

/// The Activité tab: the current user's unread notifications, grouped by recency.
/// Functional for Phase 5; Phase 6 restyles it to the polished design (screen 11).
struct ActivityView: View {
    let viewModel: NotificationsViewModel

    private var sections: [(title: String, items: [PlankaNotification])] {
        let all = viewModel.notifications
        let titles = ["Aujourd’hui", "Cette semaine", "Plus tôt"]
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

                    if viewModel.notifications.isEmpty {
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
            Text("Activité")
                .font(.boardlyTitle)
                .foregroundStyle(Color.boardlyInk)
            Spacer()
            if !viewModel.notifications.isEmpty {
                Button("Tout lire") { Task { await viewModel.markAllRead() } }
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
            Text("Aucune notification")
                .font(.boardlyHeadline)
                .foregroundStyle(Color.boardlyInk)
            Text("Vous êtes à jour.")
                .font(.boardlyBody)
                .foregroundStyle(Color.boardlyTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}
