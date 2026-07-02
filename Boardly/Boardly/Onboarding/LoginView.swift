import SwiftUI
import BoardlyKit

@Observable
@MainActor
final class LoginViewModel {
    var email: String = ""
    var password: String = ""
    var isLoggingIn: Bool = false
    var error: String?

    var canLogin: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
    }

    func login(using client: PlankaClient) async -> Bool {
        isLoggingIn = true
        error = nil
        defer { isLoggingIn = false }

        do {
            try await client.login(
                emailOrUsername: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
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
                    Text("Connexion")
                        .font(.boardlyTitle)
                        .foregroundStyle(Color.boardlyInk)
                        .padding(.bottom, 24)

                    // Server (read-only)
                    BoardlyFieldLabel("Serveur").padding(.bottom, 6)
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

                    // Credentials (grouped)
                    BoardlyFieldLabel("Identifiants").padding(.top, 18).padding(.bottom, 6)
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            Image(systemName: "envelope").foregroundStyle(Color.boardlyTextTertiary).frame(width: 20)
                            TextField("email ou nom d’utilisateur", text: $viewModel.email)
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
                        Button("Mot de passe oublié ?") {}
                            .font(.boardlyCallout)
                            .foregroundStyle(Color.accentColor)
                    }
                    .padding(.top, 12)

                    if let errorMessage = viewModel.error {
                        Text(errorMessage)
                            .font(.boardlyCallout)
                            .foregroundStyle(.red)
                            .padding(.top, 12)
                    }

                    Button(action: handleSignIn) {
                        if viewModel.isLoggingIn { ProgressView().tint(.white) }
                        else { Text("Se connecter") }
                    }
                    .buttonStyle(.boardlyPrimary)
                    .disabled(!viewModel.canLogin || viewModel.isLoggingIn)
                    .opacity(viewModel.canLogin ? 1 : 0.5)
                    .padding(.top, 18)

                    // Divider
                    HStack(spacing: 12) {
                        Rectangle().fill(Color.boardlySeparator).frame(height: 1)
                        Text("ou").font(.boardlyMonoLabel).foregroundStyle(Color.boardlyTextTertiary)
                        Rectangle().fill(Color.boardlySeparator).frame(height: 1)
                    }
                    .padding(.vertical, 18)

                    // SSO (OIDC — Phase 5, not yet wired)
                    Button {} label: {
                        Label("Continuer avec le SSO", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .buttonStyle(.boardlySecondary)
                }
                .padding(24)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
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
}
