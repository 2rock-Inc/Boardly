import SwiftUI
import BoardlyKit

@main
struct BoardlyApp: App {
    @State private var profileStore = ProfileStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(profileStore)
        }
    }
}
