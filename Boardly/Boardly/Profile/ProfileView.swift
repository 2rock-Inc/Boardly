import SwiftUI
import BoardlyKit

struct ProfileView: View {
    let profile: ServerProfile
    let client: PlankaClient
    @Environment(ProfileStore.self) private var profileStore
    @State private var viewModel: ProfileViewModel?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.boardlyBackground.ignoresSafeArea()
                ScrollView {
                    if let viewModel {
                        content(viewModel)
                    }
                }
            }
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.large)
            .task {
                if viewModel == nil { viewModel = ProfileViewModel(client: client) }
                await viewModel?.load()
            }
        }
    }

    private func content(_ viewModel: ProfileViewModel) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            header(viewModel.user)
            accountSection(viewModel)
            actions
            footer
        }
        .padding(20)
    }

    // MARK: - Header

    private func header(_ user: User?) -> some View {
        HStack(spacing: 14) {
            AvatarView(name: user?.name ?? profile.name, size: 60, bordered: false)
            VStack(alignment: .leading, spacing: 3) {
                Text(user?.name ?? profile.name)
                    .font(.sans(20, .bold))
                    .foregroundStyle(Color.boardlyInk)
                if let username = user?.username {
                    Text("@\(username)")
                        .font(.boardlyMonoCaption)
                        .foregroundStyle(Color.boardlyTextSecondary)
                }
                if let subtitle = subtitle(for: user) {
                    Text(subtitle)
                        .font(.boardlyCallout)
                        .foregroundStyle(Color.boardlyTextTertiary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func subtitle(for user: User?) -> String? {
        guard let user else { return nil }
        let role = roleLabel(user.role)
        if let org = user.organization, !org.isEmpty { return "\(org) · \(role)" }
        return role
    }

    private func roleLabel(_ role: String) -> String {
        switch role {
        case "admin": return "Administrateur"
        case "projectOwner": return "Chef de projet"
        default: return "Membre"
        }
    }

    // MARK: - Sections

    private func accountSection(_ viewModel: ProfileViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            BoardlyFieldLabel("Compte & serveur")
            VStack(spacing: 0) {
                NavigationLink {
                    NotificationServicesView(viewModel: viewModel)
                } label: {
                    SettingsRow(icon: "bell", title: "Notifications",
                                value: "\(viewModel.services.count)", showsChevron: true)
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 52)

                SettingsRow(icon: "globe", title: "Serveur",
                            value: profile.baseURL.host, showsChevron: false)

                if viewModel.isAdmin {
                    Divider().padding(.leading, 52)
                    NavigationLink {
                        WebhooksView(client: client)
                    } label: {
                        SettingsRow(icon: "point.3.connected.trianglepath.dotted",
                                    title: "Webhooks", value: nil, showsChevron: true)
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.leading, 52)
                    NavigationLink {
                        SMTPConfigView(client: client)
                    } label: {
                        SettingsRow(icon: "envelope", title: "Configuration SMTP",
                                    value: nil, showsChevron: true)
                    }
                    .buttonStyle(.plain)
                }
            }
            .boardlyCard(padding: 0)
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button("Changer de serveur") { profileStore.clearActiveProfile() }
                .buttonStyle(.boardlySecondary)

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
    }

    private var footer: some View {
        Text("Boardly \(appVersion)")
            .font(.boardlyMonoCaption)
            .foregroundStyle(Color.boardlyTextTertiary)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

// MARK: - Settings row

struct SettingsRow: View {
    let icon: String
    let title: String
    var value: String?
    var showsChevron: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
            Text(title)
                .font(.boardlyBody)
                .foregroundStyle(Color.boardlyInk)
            Spacer(minLength: 8)
            if let value {
                Text(value)
                    .font(.boardlyCallout)
                    .foregroundStyle(Color.boardlyTextSecondary)
                    .lineLimit(1)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.boardlyTextTertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}
