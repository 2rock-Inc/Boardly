import SwiftUI
import BoardlyKit

@main
struct BoardlyApp: App {
    @State private var profileStore = ProfileStore()

    init() {
        BoardlyFonts.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(profileStore)
        }
    }
}
