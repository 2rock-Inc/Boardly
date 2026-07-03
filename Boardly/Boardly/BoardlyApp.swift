import SwiftUI
import BoardlyKit

@main
struct BoardlyApp: App {
    @State private var profileStore = ProfileStore()
    @AppStorage(AppTheme.storageKey) private var appearanceRaw = AppTheme.system.rawValue

    init() {
        BoardlyFonts.register()
    }

    private var colorScheme: ColorScheme? {
        AppTheme(rawValue: appearanceRaw)?.colorScheme
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
            } else if CommandLine.arguments.contains("-mockProfile") {
                MockProfileHarness()
            } else if CommandLine.arguments.contains("-mockSearch") {
                MockSearchHarness()
            } else if CommandLine.arguments.contains("-mockEditProject") {
                MockEditProjectHarness()
            } else {
                RootView().environment(profileStore).preferredColorScheme(colorScheme)
            }
            #else
            RootView().environment(profileStore).preferredColorScheme(colorScheme)
            #endif
        }
    }
}
