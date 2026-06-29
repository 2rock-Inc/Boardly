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
                    Text("CONNEXION")
                        .font(.boardlyMonoLabel)
                        .tracking(2)
                        .foregroundStyle(Color.boardlyTextTertiary)
                        .padding(.bottom, 8)

                    Text(profile.name)
                        .font(.boardlyTitle)
                        .foregroundStyle(Color.boardlyInk)

                    Text(profile.baseURL.absoluteString)
                        .font(.boardlyMonoCaption)
                        .foregroundStyle(Color.boardlyTextSecondary)
                        .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 6) {
                        BoardlyFieldLabel("Identifiant")
                        TextField("email ou nom d’utilisateur", text: $viewModel.email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .boardlyField()
                    }
                    .padding(.top, 28)

                    VStack(alignment: .leading, spacing: 6) {
                        BoardlyFieldLabel("Mot de passe")
                        SecureField("••••••••", text: $viewModel.password)
                            .textContentType(.password)
                            .boardlyField()
                    }
                    .padding(.top, 16)

                    if let errorMessage = viewModel.error {
                        Text(errorMessage)
                            .font(.boardlyCallout)
                            .foregroundStyle(.red)
                            .padding(.top, 16)
                    }

                    Button(action: handleSignIn) {
                        if viewModel.isLoggingIn {
                            ProgressView().tint(.white)
                        } else {
                            Text("Se connecter")
                        }
                    }
                    .buttonStyle(.boardlyPrimary)
                    .disabled(!viewModel.canLogin || viewModel.isLoggingIn)
                    .opacity(viewModel.canLogin ? 1 : 0.5)
                    .padding(.top, 28)
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
