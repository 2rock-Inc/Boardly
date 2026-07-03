import SwiftUI
import BoardlyKit

struct ProfileSelectionView: View {
    @Environment(ProfileStore.self) private var profileStore
    @Binding var path: [OnboardingRoute]

    var body: some View {
        ZStack {
            Color.boardlyBackground.ignoresSafeArea()

            if profileStore.profiles.isEmpty {
                welcome
            } else {
                serverList
            }
        }
        .navigationTitle("")
        .toolbar {
            if !profileStore.profiles.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button { path.append(.addServer) } label: {
                        Image(systemName: "plus")
                    }
                    .tint(.accentColor)
                }
            }
        }
    }

    // MARK: - Welcome (no servers yet)

    private var welcome: some View {
        VStack(spacing: 0) {
            Spacer()

            BoardlyLogo(size: 88)
                .padding(.bottom, 30)

            Text("Boardly")
                .font(.sans(34, .heavy, relativeTo: .largeTitle))
                .tracking(-1)
                .foregroundStyle(Color.boardlyInk)

            Text("Your boards, your cards, and your team — together in an app built to keep you moving.")
                .font(.sans(16.5, .regular))
                .foregroundStyle(Color.boardlyTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.top, 12)
                .frame(maxWidth: 290)

            Spacer()

            Button("Set Up a Server") { path.append(.addServer) }
                .buttonStyle(.boardlyPrimary)
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
        }
    }

    // MARK: - Server list

    private var serverList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Servers")
                    .font(.boardlyTitle)
                    .foregroundStyle(Color.boardlyInk)
                    .padding(.top, 8)

                ForEach(profileStore.profiles) { profile in
                    ProfileRowView(
                        profile: profile,
                        onSelect: { selectServer(profile) },
                        onDelete: { profileStore.removeProfile(id: profile.id) }
                    )
                }
            }
            .padding(20)
        }
    }

    // A saved server keeps its token: go straight in if we have one, otherwise
    // route to login. (Selecting must not activate a profile with no token, or
    // the app would drop into a session it can't authenticate.)
    private func selectServer(_ profile: ServerProfile) {
        if profileStore.tokenStore(for: profile).hasToken() {
            profileStore.setActiveProfile(id: profile.id)
        } else {
            path.append(.login(profileID: profile.id))
        }
    }
}

private struct ProfileRowView: View {
    let profile: ServerProfile
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "server.rack")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 40, height: 40)
                .background(Color.boardlySurfaceSecondary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(profile.name)
                    .font(.boardlyHeadline)
                    .foregroundStyle(Color.boardlyInk)
                Text(profile.baseURL.absoluteString)
                    .font(.boardlyMonoCaption)
                    .foregroundStyle(Color.boardlyTextSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Menu {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete Server", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.boardlyTextTertiary)
                    .frame(width: 32, height: 40)
                    .contentShape(Rectangle())
            }
        }
        .boardlyCard()
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
    }
}
