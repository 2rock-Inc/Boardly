import SwiftUI
import BoardlyKit

struct RootView: View {
    @Environment(ProfileStore.self) private var profileStore

    var body: some View {
        if let profile = profileStore.activeProfile {
            MainView(profile: profile)
        } else {
            OnboardingView()
        }
    }
}

private struct OnboardingView: View {
    @State private var path: [OnboardingRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            ProfileSelectionView(path: $path)
                .navigationDestination(for: OnboardingRoute.self) { route in
                    switch route {
                    case .addServer:
                        AddServerView(path: $path)
                    case .login(let profileID):
                        LoginDestination(profileID: profileID, path: $path)
                    }
                }
        }
    }
}

private struct LoginDestination: View {
    let profileID: UUID
    @Binding var path: [OnboardingRoute]
    @Environment(ProfileStore.self) private var profileStore

    var body: some View {
        if let profile = profileStore.profiles.first(where: { $0.id == profileID }) {
            LoginView(profile: profile, path: $path)
        }
    }
}
