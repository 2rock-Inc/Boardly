import BoardlyKit
import SwiftUI

struct MainView: View {
    let profile: ServerProfile
    @Environment(ProfileStore.self) private var profileStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var path: [AppRoute] = []
    @State private var notificationsVM: NotificationsViewModel?
    /// Shared, ref-counted board sessions for this profile — so the same board open
    /// in Projects and Search shares one socket subscription. Reset on profile
    /// switch / logout so no socket outlives its profile.
    @State private var boardSessions = BoardSessionStore()

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
        .environment(boardSessions)
        .onChange(of: profile.id) { _, _ in
            // Switched server without going through the picker — drop the previous
            // profile's live boards so no socket crosses profiles.
            boardSessions.reset()
        }
        .onDisappear { boardSessions.reset() }
        // Keyed on scenePhase: the task restarts on every phase change, so returning
        // to active reloads immediately, and leaving active stops the poll below —
        // no needless background network/battery use.
        .task(id: scenePhase) {
            if notificationsVM == nil { notificationsVM = NotificationsViewModel(client: client) }
            guard scenePhase == .active else { return }
            await notificationsVM?.load()
            // Poll so the unread badge stays fresh while the app is foreground (Phase
            // 5 is pull-based; a Socket.IO live feed can replace this later).
            while !Task.isCancelled {
                try? await Task.sleep(for: notificationPollInterval)
                await notificationsVM?.load()
            }
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
                    .font(.boardlyScreenTitle)
                    .foregroundStyle(Color.boardlyInk)
                Text("Coming soon")
                    .font(.boardlyBody)
                    .foregroundStyle(Color.boardlyTextSecondary)
            }
        }
    }
}
