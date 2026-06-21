import SwiftUI
import BoardlyKit

struct MainPlaceholderView: View {
    @Environment(ProfileStore.self) private var profileStore

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("You're in!")
                .font(.largeTitle.bold())
            if let name = profileStore.activeProfile?.name {
                Text("Connected to \(name)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text("Board view coming in Phase 2.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .navigationTitle("Boardly")
        .navigationBarBackButtonHidden()
    }
}
