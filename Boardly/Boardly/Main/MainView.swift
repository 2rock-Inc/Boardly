import SwiftUI
import BoardlyKit

struct MainView: View {
    let profile: ServerProfile
    @Environment(ProfileStore.self) private var profileStore
    @State private var path: [AppRoute] = []

    private var client: PlankaClient {
        profileStore.makeClient(for: profile)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ProjectListView(client: client, path: $path)
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .board(let id, let name):
                        BoardView(client: client, boardId: id, boardName: name)
                    }
                }
        }
    }
}
