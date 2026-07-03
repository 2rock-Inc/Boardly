import BoardlyKit
import SwiftUI

@Observable
@MainActor
final class LoginViewModel {
    var email: String = ""
    var password: String = ""
    var isLoggingIn: Bool = false
    var error: String?

    /// OIDC config advertised by the instance (`Bootstrap.oidc`). When non-nil the
    /// SSO button is shown; when `isEnforced` the password form is hidden.
    var oidc: Bootstrap.OIDCConfig?
    /// Non-nil while the SSO web flow is presented.
    var oidcSession: OIDCSession?

    var canLogin: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
    }

    var showsPasswordForm: Bool { oidc?.isEnforced != true }
    var showsSSO: Bool { oidc != nil }

    /// Fetch the instance bootstrap to learn whether OIDC is available/enforced.
    /// Best-effort — a failure just leaves the password form as the only option.
    func loadBootstrap(using client: PlankaClient) async {
        oidc = try? await client.validateInstance().oidc
    }

    func login(using client: PlankaClient) async -> Bool {
        isLoggingIn = true
        error = nil
        defer { isLoggingIn = false }

        do {
            try await client.login(
                emailOrUsername: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password)
            return true
        } catch let apiError as PlankaAPIError {
            switch apiError {
            case .unauthorized: error = "Invalid email/username or password."
            case .forbidden: error = "Login is restricted. Check with your administrator."
            default: error = "Network error. Please check your connection."
            }
        } catch {
            self.error = error.localizedDescription
        }
        return false
    }

    /// Begin the OIDC/SSO leg by presenting the web flow (parsed from the
    /// instance's advertised authorization URL). `baseURL` lets us derive the
    /// redirect target when the instance keeps `redirect_uri` server-side.
    func startSSO(baseURL: URL) {
        error = nil
        guard let oidc else {
            error = OIDCError.notConfigured.errorDescription
            return
        }
        guard let session = OIDCSession(oidc: oidc, baseURL: baseURL) else {
            #if DEBUG
                // Surface the raw URL so we can diagnose a parsing failure.
                error = "OIDC: authorization URL could not be parsed. authorizationUrl = \(oidc.authorizationUrl)"
            #else
                error = OIDCError.notConfigured.errorDescription
            #endif
            return
        }
        oidcSession = session
    }

    /// Finish SSO: exchange the captured `code` (+ the session's `nonce`) for a
    /// token. Returns whether login succeeded.
    func completeSSO(code: String, using client: PlankaClient) async -> Bool {
        guard let session = oidcSession else { return false }
        oidcSession = nil
        isLoggingIn = true
        error = nil
        defer { isLoggingIn = false }

        do {
            try await client.exchangeOIDC(code: code, nonce: session.nonce)
            return true
        } catch let apiError as PlankaAPIError {
            switch apiError {
            case .unauthorized: error = "SSO authentication failed (invalid code or nonce)."
            case .forbidden: error = "SSO login was refused by the server."
            default: error = "Network error during SSO login."
            }
        } catch {
            self.error = error.localizedDescription
        }
        return false
    }

    func cancelSSO() {
        oidcSession = nil
    }
}

struct LoginView: View {
    let profile: ServerProfile
    @Binding var path: [OnboardingRoute]
    @Environment(ProfileStore.self) private var profileStore
    @State private var viewModel = LoginViewModel()

    var body: some View {
        ZStack {
            Color.boardlyBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Login")
                        .font(.boardlyTitle)
                        .foregroundStyle(Color.boardlyInk)
                        .padding(.bottom, 24)

                    // Server (read-only)
                    BoardlyFieldLabel("Server").padding(.bottom, 6)
                    HStack(spacing: 10) {
                        Image(systemName: "globe")
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 20)
                        Text(profile.baseURL.host ?? profile.baseURL.absoluteString)
                            .font(.mono(15, .regular))
                            .foregroundStyle(Color.boardlyInk)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(Color.boardlySurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.boardlySeparator, lineWidth: 1))

                    // Credentials (grouped) — hidden when the instance enforces OIDC
                    if viewModel.showsPasswordForm {
                        BoardlyFieldLabel("Credentials").padding(.top, 18).padding(.bottom, 6)
                        VStack(spacing: 0) {
                            HStack(spacing: 10) {
                                Image(systemName: "envelope").foregroundStyle(Color.boardlyTextTertiary).frame(width: 20)
                                TextField("email or username", text: $viewModel.email)
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            Divider().padding(.leading, 44)
                            HStack(spacing: 10) {
                                Image(systemName: "lock").foregroundStyle(Color.boardlyTextTertiary).frame(width: 20)
                                SecureField("••••••••", text: $viewModel.password)
                                    .textContentType(.password)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                        }
                        .font(.boardlyBody)
                        .foregroundStyle(Color.boardlyInk)
                        .background(Color.boardlySurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.boardlySeparator, lineWidth: 1))

                        // Forgot password (Phase 5 — not yet wired)
                        HStack {
                            Spacer()
                            Button("Forgot password?") {}
                                .font(.boardlyCallout)
                                .foregroundStyle(Color.accentColor)
                        }
                        .padding(.top, 12)
                    }

                    if let errorMessage = viewModel.error {
                        Text(errorMessage)
                            .font(.boardlyCallout)
                            .foregroundStyle(.red)
                            .padding(.top, 12)
                    }

                    if viewModel.showsPasswordForm {
                        Button(action: handleSignIn) {
                            if viewModel.isLoggingIn { ProgressView().tint(.white) }
                            else { Text("Log In") }
                        }
                        .buttonStyle(.boardlyPrimary)
                        .disabled(!viewModel.canLogin || viewModel.isLoggingIn)
                        .opacity(viewModel.canLogin ? 1 : 0.5)
                        .padding(.top, 18)
                    }

                    // Divider — only when both password and SSO are offered
                    if viewModel.showsPasswordForm, viewModel.showsSSO {
                        HStack(spacing: 12) {
                            Rectangle().fill(Color.boardlySeparator).frame(height: 1)
                            Text("or").font(.boardlyMonoLabel).foregroundStyle(Color.boardlyTextTertiary)
                            Rectangle().fill(Color.boardlySeparator).frame(height: 1)
                        }
                        .padding(.vertical, 18)
                    }

                    // SSO (OIDC) — shown only when the instance advertises it
                    if viewModel.showsSSO {
                        Button(action: handleSSO) {
                            if viewModel.isLoggingIn, !viewModel.showsPasswordForm {
                                ProgressView().tint(Color.boardlyInk)
                            } else {
                                Label("Continue with SSO", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                        }
                        .buttonStyle(.boardlySecondary)
                        .disabled(viewModel.isLoggingIn)
                        .padding(.top, viewModel.showsPasswordForm ? 0 : 18)
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadBootstrap(using: profileStore.makeClient(for: profile)) }
        .fullScreenCover(item: $viewModel.oidcSession) { session in
            OIDCWebFlow(
                session: session,
                onCode: { code in
                    Task {
                        let client = profileStore.makeClient(for: profile)
                        if await viewModel.completeSSO(code: code, using: client) {
                            profileStore.setActiveProfile(id: profile.id)
                        }
                    }
                },
                onCancel: { viewModel.cancelSSO() })
        }
    }

    private func handleSignIn() {
        Task {
            let client = profileStore.makeClient(for: profile)
            if await viewModel.login(using: client) {
                profileStore.setActiveProfile(id: profile.id)
                // RootView swaps to MainView when activeProfile becomes non-nil
            }
        }
    }

    private func handleSSO() {
        viewModel.startSSO(baseURL: profile.baseURL)
    }
}
