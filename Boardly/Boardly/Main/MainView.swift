import BoardlyKit
import SwiftUI

struct MainView: View {
    let profile: ServerProfile
    @Environment(ProfileStore.self) private var profileStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var path: [AppRoute] = []
    @State private var notificationsVM: NotificationsViewModel?

    /// How often the unread badge is refreshed while the app is foreground.
    private let notificationPollInterval: Duration = .seconds(60)

    private var client: PlankaClient {
        profileStore.makeClient(for: profile)
    }

    var body: some View {
        TabView {
            NavigationStack(path: $path) {
                ProjectListView(client: client, path: $path)
                    .navigationDestination(for: AppRoute.self) { route in
                        switch route {
                        case let .project(id, name):
                            ProjectDetailView(client: client, projectId: id, projectName: name, path: $path)
                        case let .board(id, name, projectName, focusCardId):
                            BoardView(
                                client: client,
                                boardId: id,
                                boardName: name,
                                projectName: projectName,
                                focusCardId: focusCardId)
                        }
                    }
            }
            .tabItem { Label("Projects", systemImage: "house") }

            SearchView(client: client)
                .tabItem { Label("Search", systemImage: "magnifyingglass") }

            Group {
                if let notificationsVM {
                    ActivityView(viewModel: notificationsVM)
                } else {
                    Color.boardlyBackground.ignoresSafeArea()
                }
            }
            .tabItem { Label("Activity", systemImage: "bell") }
            .badge(notificationsVM?.unreadCount ?? 0)

            ProfileView(profile: profile, client: client)
                .tabItem { Label("Profile", systemImage: "person") }
        }
        .tint(.accentColor)
        .task {
            if notificationsVM == nil { notificationsVM = NotificationsViewModel(client: client) }
            await notificationsVM?.load()
            // Poll so the unread badge stays fresh while the app is open (Phase 5
            // is pull-based; a Socket.IO live feed can replace this later).
            while !Task.isCancelled {
                try? await Task.sleep(for: notificationPollInterval)
                await notificationsVM?.load()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await notificationsVM?.load() } }
        }
    }
}

/// Placeholder for tabs whose feature lands in Phase 5 (search, notifications,
/// profile/settings).
struct ComingSoonView: View {
    let title: LocalizedStringKey
    let systemImage: String

    var body: some View {
        ZStack {
            Color.boardlyBackground.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(Color.boardlyTextTertiary)
                Text(title)
                    .font(.boardlyTitle)
                    .foregroundStyle(Color.boardlyInk)
                Text("Coming soon")
                    .font(.boardlyBody)
                    .foregroundStyle(Color.boardlyTextSecondary)
            }
        }
    }
}
