import BoardlyKit
import SwiftUI

struct RootView: View {
    @Environment(ProfileStore.self) private var profileStore
    @State private var path: [OnboardingRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            ProfileSelectionView(path: $path)
                .navigationDestination(for: OnboardingRoute.self) { route in
                    switch route {
                    case .addServer:
                        AddServerView(path: $path)
                    case let .login(profileID):
                        if let profile = profileStore.profiles.first(where: { $0.id == profileID }) {
                            LoginView(profile: profile, path: $path)
                        }
                    }
                }
        }
        .fullScreenCover(isPresented: Binding(
            get: { profileStore.activeProfile != nil },
            set: { _ in }))
        {
            if let profile = profileStore.activeProfile {
                MainView(profile: profile)
            }
        }
        .onChange(of: profileStore.activeProfileID) { _, newValue in
            // Returning from a session (logout / switch server) — reset to the
            // server picker rather than landing back on a stale login screen.
            if newValue == nil { path = [] }
        }
    }
}
