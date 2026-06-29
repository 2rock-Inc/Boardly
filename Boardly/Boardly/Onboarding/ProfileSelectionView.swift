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

            Text("Vos tableaux, vos cartes et votre équipe — réunis dans une app pensée pour avancer.")
                .font(.sans(16.5, .regular))
                .foregroundStyle(Color.boardlyTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.top, 12)
                .frame(maxWidth: 290)

            Spacer()

            Button("Configurer un serveur") { path.append(.addServer) }
                .buttonStyle(.boardlyPrimary)
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
        }
    }

    // MARK: - Server list

    private var serverList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Serveurs")
                    .font(.boardlyTitle)
                    .foregroundStyle(Color.boardlyInk)
                    .padding(.top, 8)

                ForEach(profileStore.profiles) { profile in
                    Button {
                        profileStore.setActiveProfile(id: profile.id)
                        path.append(.login(profileID: profile.id))
                    } label: {
                        ProfileRowView(profile: profile)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            profileStore.removeProfile(id: profile.id)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(20)
        }
    }
}

private struct ProfileRowView: View {
    let profile: ServerProfile

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

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.boardlyTextTertiary)
        }
        .boardlyCard()
    }
}
