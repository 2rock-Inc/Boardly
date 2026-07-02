import SwiftUI
import BoardlyKit

struct MainView: View {
    let profile: ServerProfile
    @Environment(ProfileStore.self) private var profileStore
    @State private var path: [AppRoute] = []
    @State private var notificationsVM: NotificationsViewModel?

    private var client: PlankaClient {
        profileStore.makeClient(for: profile)
    }

    var body: some View {
        TabView {
            NavigationStack(path: $path) {
                ProjectListView(client: client, path: $path)
                    .navigationDestination(for: AppRoute.self) { route in
                        switch route {
                        case .project(let id, let name):
                            ProjectDetailView(client: client, projectId: id, projectName: name, path: $path)
                        case .board(let id, let name, let projectName):
                            BoardView(client: client, boardId: id, boardName: name, projectName: projectName)
                        }
                    }
            }
            .tabItem { Label("Projets", systemImage: "house") }

            ComingSoonView(title: "Recherche", systemImage: "magnifyingglass")
                .tabItem { Label("Recherche", systemImage: "magnifyingglass") }

            Group {
                if let notificationsVM {
                    ActivityView(viewModel: notificationsVM)
                } else {
                    Color.boardlyBackground.ignoresSafeArea()
                }
            }
            .tabItem { Label("Activité", systemImage: "bell") }
            .badge(notificationsVM?.unreadCount ?? 0)

            ProfileView(profile: profile, client: client)
                .tabItem { Label("Profil", systemImage: "person") }
        }
        .tint(.accentColor)
        .task {
            if notificationsVM == nil { notificationsVM = NotificationsViewModel(client: client) }
            await notificationsVM?.load()
        }
    }
}

/// Placeholder for tabs whose feature lands in Phase 5 (search, notifications,
/// profile/settings).
struct ComingSoonView: View {
    let title: String
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
                Text("Bientôt disponible")
                    .font(.boardlyBody)
                    .foregroundStyle(Color.boardlyTextSecondary)
            }
        }
    }
}
