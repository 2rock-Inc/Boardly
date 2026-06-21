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
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sign in to \(profile.name)")
                        .font(.headline)
                    Text(profile.baseURL.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section {
                TextField("Email or username", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                SecureField("Password", text: $viewModel.password)
                    .textContentType(.password)
            }

            if let errorMessage = viewModel.error {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
        }
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                signInButton
            }
        }
    }

    @ViewBuilder
    private var signInButton: some View {
        if viewModel.isLoggingIn {
            ProgressView()
        } else {
            Button("Sign In", action: handleSignIn)
                .disabled(!viewModel.canLogin)
        }
    }

    private func handleSignIn() {
        Task {
            let client = profileStore.makeClient(for: profile)
            if await viewModel.login(using: client) {
                path.append(.main(profileID: profile.id))
            }
        }
    }
}
