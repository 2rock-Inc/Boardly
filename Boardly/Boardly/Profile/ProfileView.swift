import SwiftUI
import BoardlyKit

struct ProfileView: View {
    let profile: ServerProfile
    let client: PlankaClient
    @Environment(ProfileStore.self) private var profileStore
    @AppStorage(AppTheme.storageKey) private var appearanceRaw = AppTheme.system.rawValue
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
            .navigationTitle("Profile")
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
            // Surface any failure: a load error (which would otherwise hide the
            // user's admin rows) or a preference-save error.
            if let error = viewModel.error {
                errorBanner(error) { Task { await viewModel.load() } }
            }
            preferencesSection(viewModel)
            accountSection(viewModel)
            actions
            footer(viewModel)
        }
        .padding(20)
    }

    // MARK: - Preferences (design 13)

    private func preferencesSection(_ viewModel: ProfileViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            BoardlyFieldLabel("Preferences")
            VStack(spacing: 0) {
                // Appearance — app-local theme.
                Menu {
                    Picker("Appearance", selection: $appearanceRaw) {
                        ForEach(AppTheme.allCases) { Text($0.label).tag($0.rawValue) }
                    }
                } label: {
                    SettingsRow(icon: "sun.max", title: "Appearance",
                                value: AppTheme(rawValue: appearanceRaw)?.label, showsChevron: true)
                }

                Divider().padding(.leading, 52)

                // Home view — PLANKA pref.
                Menu {
                    ForEach(HomeViewOption.allCases) { option in
                        prefButton(option.label, selected: viewModel.homeView == option) {
                            viewModel.setHomeView(option)
                        }
                    }
                } label: {
                    SettingsRow(icon: "square.grid.2x2", title: "Home View",
                                value: viewModel.homeView.label, showsChevron: true)
                }

                Divider().padding(.leading, 52)

                // Markdown editor — PLANKA pref.
                Menu {
                    ForEach(EditorModeOption.allCases) { option in
                        prefButton(option.label, selected: viewModel.editorMode == option) {
                            viewModel.setEditorMode(option)
                        }
                    }
                } label: {
                    SettingsRow(icon: "text.alignleft", title: "Markdown Editor",
                                value: viewModel.editorMode.label, showsChevron: true)
                }
            }
            .boardlyCard(padding: 0)
        }
    }

    private func prefButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if selected { Label(title, systemImage: "checkmark") } else { Text(title) }
        }
    }

    private func errorBanner(_ message: String, retry: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Text(message)
                .font(.boardlyCallout)
                .foregroundStyle(Color.labelRose)
            Spacer(minLength: 8)
            Button("Retry", action: retry)
                .font(.boardlyCallout)
                .foregroundStyle(Color.accentColor)
        }
        .padding(12)
        .background(Color.labelRose.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
        case "admin": return "Administrator"
        case "projectOwner": return "Project Owner"
        default: return "Member"
        }
    }

    // MARK: - Sections

    private func accountSection(_ viewModel: ProfileViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            BoardlyFieldLabel("Account & Server")
            VStack(spacing: 0) {
                NavigationLink {
                    NotificationServicesView(viewModel: viewModel)
                } label: {
                    SettingsRow(icon: "bell", title: "Notifications",
                                value: "\(viewModel.services.count)", showsChevron: true)
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 52)

                SettingsRow(icon: "globe", title: "Server",
                            value: profile.baseURL.host ?? profile.baseURL.absoluteString,
                            showsChevron: false)

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
                        SettingsRow(icon: "envelope", title: "SMTP Configuration",
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
            Button("Switch Server") { profileStore.clearActiveProfile() }
                .buttonStyle(.boardlySecondary)

            Button(role: .destructive) {
                Task {
                    try? await client.logout()
                    profileStore.clearActiveProfile()
                }
            } label: {
                Text("Log Out")
                    .font(.sans(16, .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.labelRose, in: Capsule())
            }
        }
    }

    private func footer(_ viewModel: ProfileViewModel) -> some View {
        Text(footerText(viewModel))
            .font(.boardlyMonoCaption)
            .foregroundStyle(Color.boardlyTextTertiary)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
    }

    private func footerText(_ viewModel: ProfileViewModel) -> String {
        var text = "Boardly \(appVersion)"
        if let version = viewModel.plankaVersion { text += " · Planka \(version)" }
        return text
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
