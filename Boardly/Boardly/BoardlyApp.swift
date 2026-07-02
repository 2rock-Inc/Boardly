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
            #if DEBUG
            if CommandLine.arguments.contains("-mockCard") {
                MockCardHarness()
            } else if CommandLine.arguments.contains("-mockBoard") {
                MockBoardHarness()
            } else if CommandLine.arguments.contains("-mockProjects") {
                MockProjectsHarness()
            } else if CommandLine.arguments.contains("-mockLogin") {
                MockLoginHarness()
            } else if CommandLine.arguments.contains("-mockProjectDetail") {
                MockProjectDetailHarness()
            } else if CommandLine.arguments.contains("-mockMembersSheet") {
                MockMembersSheetHarness()
            } else if CommandLine.arguments.contains("-mockActivity") {
                MockActivityHarness()
            } else {
                RootView().environment(profileStore)
            }
            #else
            RootView().environment(profileStore)
            #endif
        }
    }
}
