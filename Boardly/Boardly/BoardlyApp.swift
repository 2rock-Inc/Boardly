import SwiftUI
import BoardlyKit

@main
struct BoardlyApp: App {
    private let profileStore = ProfileStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(profileStore)
        }
    }
}
