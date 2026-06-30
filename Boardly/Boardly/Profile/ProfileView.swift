import SwiftUI
import BoardlyKit

struct ProfileView: View {
    let profile: ServerProfile
    let client: PlankaClient
    @Environment(ProfileStore.self) private var profileStore

    var body: some View {
        ZStack {
            Color.boardlyBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Profil")
                        .font(.boardlyTitle)
                        .foregroundStyle(Color.boardlyInk)
                        .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 12) {
                        BoardlyFieldLabel("Serveur actif")
                        HStack(spacing: 12) {
                            Image(systemName: "globe")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 40, height: 40)
                                .background(Color.boardlySurfaceSecondary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(profile.name)
                                    .font(.boardlyHeadline)
                                    .foregroundStyle(Color.boardlyInk)
                                Text(profile.baseURL.host ?? profile.baseURL.absoluteString)
                                    .font(.boardlyMonoCaption)
                                    .foregroundStyle(Color.boardlyTextSecondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .boardlyCard()

                    Button("Changer de serveur") {
                        profileStore.clearActiveProfile()
                    }
                    .buttonStyle(.boardlySecondary)
                    .padding(.top, 8)

                    Button(role: .destructive) {
                        Task {
                            try? await client.logout()
                            profileStore.clearActiveProfile()
                        }
                    } label: {
                        Text("Se déconnecter")
                            .font(.sans(16, .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color.labelRose, in: Capsule())
                    }
                }
                .padding(20)
            }
        }
    }
}
