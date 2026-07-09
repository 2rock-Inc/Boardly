import BoardlyKit
import SwiftUI

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
                        ForEach(AppTheme.allCases) { Text($0.localizedName).tag($0.rawValue) }
                    }
                } label: {
                    SettingsRow(
                        icon: "sun.max",
                        title: "Appearance",
                        value: AppTheme(rawValue: appearanceRaw).map { String(localized: $0.localizedName) },
                        showsChevron: true)
                }

                Divider().padding(.leading, 56)

                // Home view — PLANKA pref.
                Menu {
                    ForEach(HomeViewOption.allCases) { option in
                        prefButton(option.localizedName, selected: viewModel.homeView == option) {
                            viewModel.setHomeView(option)
                        }
                    }
                } label: {
                    SettingsRow(
                        icon: "square.grid.2x2",
                        title: "Home View",
                        value: String(localized: viewModel.homeView.localizedName),
                        showsChevron: true)
                }

                Divider().padding(.leading, 56)

                // Markdown editor — PLANKA pref.
                Menu {
                    ForEach(EditorModeOption.allCases) { option in
                        prefButton(option.localizedName, selected: viewModel.editorMode == option) {
                            viewModel.setEditorMode(option)
                        }
                    }
                } label: {
                    SettingsRow(
                        icon: "text.alignleft",
                        title: "Markdown Editor",
                        value: String(localized: viewModel.editorMode.localizedName),
                        showsChevron: true)
                }
            }
            .boardlyCard(padding: 0)
        }
    }

    private func prefButton(_ title: LocalizedStringResource, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if selected {
                Label { Text(title) } icon: { Image(systemName: "checkmark") }
            } else {
                Text(title)
            }
        }
    }

    private func errorBanner(_ message: String, retry: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Text(message)
                .font(.boardlyCallout)
                .foregroundStyle(Color.boardlyDestructive)
            Spacer(minLength: 8)
            Button("Retry", action: retry)
                .font(.boardlyCallout)
                .foregroundStyle(Color.accentColor)
        }
        .padding(12)
        .background(Color.boardlyDestructive.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Header

    private func header(_ user: User?) -> some View {
        HStack(spacing: 14) {
            AvatarView(name: user?.name ?? profile.name, size: 64, bordered: false)
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: user?.name ?? profile.name)
                    .font(.sans(21, .heavy))
                    .foregroundStyle(Color.boardlyInk)
                if let username = user?.username {
                    Text(verbatim: "@\(username)")
                        .font(.boardlyMonoCaption)
                        .foregroundStyle(Color.boardlyTextSecondary)
                }
                if let subtitle = subtitle(for: user) {
                    Text(verbatim: subtitle)
                        .font(.boardlyCallout)
                        .foregroundStyle(Color.boardlyTextTertiary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func subtitle(for user: User?) -> String? {
        guard let user else { return nil }
        let role = String(localized: roleLabel(user.role))
        if let org = user.organization, !org.isEmpty { return "\(org) · \(role)" }
        return role
    }

    private func roleLabel(_ role: String) -> LocalizedStringResource {
        switch role {
        case "admin": "Administrator"
        case "projectOwner": "Project Owner"
        default: "Member"
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
                    SettingsRow(
                        icon: "bell",
                        title: "Notifications",
                        value: "\(viewModel.services.count)",
                        showsChevron: true,
                        tint: .labelPurple, fill: .labelPurple.opacity(0.14))
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 56)

                SettingsRow(
                    icon: "globe",
                    title: "Server",
                    value: profile.baseURL.host ?? profile.baseURL.absoluteString,
                    showsChevron: false,
                    tint: .labelPurple, fill: .labelPurple.opacity(0.14))

                if viewModel.isAdmin {
                    Divider().padding(.leading, 56)
                    NavigationLink {
                        WebhooksView(client: client)
                    } label: {
                        SettingsRow(
                            icon: "point.3.connected.trianglepath.dotted",
                            title: "Webhooks",
                            value: nil,
                            showsChevron: true,
                            tint: .labelPurple, fill: .labelPurple.opacity(0.14))
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.leading, 56)
                    NavigationLink {
                        SMTPConfigView(client: client)
                    } label: {
                        SettingsRow(
                            icon: "envelope",
                            title: "SMTP Configuration",
                            value: nil,
                            showsChevron: true,
                            tint: .labelPurple, fill: .labelPurple.opacity(0.14))
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
                    .font(.sans(15, .bold))
                    .foregroundStyle(Color.boardlyDestructive)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.vertical, 6)
                    .background(Color.boardlySurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
            }
            .buttonStyle(.plain)
        }
    }

    private func footer(_ viewModel: ProfileViewModel) -> some View {
        // Version string — proper nouns + numbers, rendered verbatim.
        Text(verbatim: footerText(viewModel))
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
    let title: LocalizedStringKey
    /// Pre-resolved data (a server name, a localized enum name) — rendered verbatim.
    var value: String?
    var showsChevron: Bool
    /// Tinted icon-tile colors (per section: teal for Preferences, purple for Account).
    var tint: Color = .accentColor
    var fill: Color = .boardlyTealFill

    var body: some View {
        HStack(spacing: 12) {
            BoardlyIconTile(systemName: icon, tint: tint, fill: fill)
            Text(title)
                .font(.boardlyBody)
                .foregroundStyle(Color.boardlyInk)
            Spacer(minLength: 8)
            if let value {
                Text(verbatim: value)
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
