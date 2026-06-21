import SwiftUI
import BoardlyKit

struct ProfileSelectionView: View {
    @Environment(ProfileStore.self) private var profileStore
    @Binding var path: [OnboardingRoute]

    var body: some View {
        Group {
            if profileStore.profiles.isEmpty {
                ContentUnavailableView(
                    "No Servers",
                    systemImage: "server.rack",
                    description: Text("Add a PLANKA server to get started.")
                )
            } else {
                List(profileStore.profiles) { profile in
                    Button {
                        profileStore.setActiveProfile(id: profile.id)
                        path.append(.login(profileID: profile.id))
                    } label: {
                        ProfileRowView(profile: profile)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            profileStore.removeProfile(id: profile.id)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Servers")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    path.append(.addServer)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

private struct ProfileRowView: View {
    let profile: ServerProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(profile.name)
                .font(.headline)
            Text(profile.baseURL.absoluteString)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
