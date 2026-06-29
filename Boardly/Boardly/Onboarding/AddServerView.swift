import SwiftUI
import BoardlyKit

@Observable
@MainActor
final class AddServerViewModel {
    var urlText: String = ""
    var name: String = ""
    var isValidating: Bool = false
    var error: String?

    var canValidate: Bool {
        !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func validateAndAdd(profileStore: ProfileStore) async -> ServerProfile? {
        let raw = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: raw) else {
            error = "Invalid URL format."
            return nil
        }
        if components.scheme == nil { components.scheme = "https" }
        guard let url = components.url else {
            error = "Could not construct a valid URL."
            return nil
        }

        let resolvedName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (url.host ?? raw)
            : name.trimmingCharacters(in: .whitespacesAndNewlines)

        let profile = ServerProfile(name: resolvedName, baseURL: url)
        let tempTokenStore = TokenStore(profileID: profile.id)
        let client = PlankaClient(profile: profile, tokenStore: tempTokenStore)

        isValidating = true
        error = nil
        defer { isValidating = false }

        do {
            _ = try await client.validateInstance()
            profileStore.addProfile(profile)
            return profile
        } catch PlankaAPIError.instanceUnreachable {
            error = "Could not reach a PLANKA instance at that URL."
        } catch PlankaAPIError.networkError {
            error = "Network error. Check the URL and your connection."
        } catch {
            self.error = "Unexpected error: \(error.localizedDescription)"
        }
        return nil
    }
}

struct AddServerView: View {
    @Environment(ProfileStore.self) private var profileStore
    @Binding var path: [OnboardingRoute]
    @State private var viewModel = AddServerViewModel()

    var body: some View {
        ZStack {
            Color.boardlyBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("NOUVEAU SERVEUR")
                        .font(.boardlyMonoLabel)
                        .tracking(2)
                        .foregroundStyle(Color.boardlyTextTertiary)
                        .padding(.bottom, 8)

                    Text("Ajouter un serveur")
                        .font(.boardlyTitle)
                        .foregroundStyle(Color.boardlyInk)

                    Text("Connecte Boardly à ton instance PLANKA auto-hébergée.")
                        .font(.boardlyBody)
                        .foregroundStyle(Color.boardlyTextSecondary)
                        .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 6) {
                        BoardlyFieldLabel("Adresse du serveur")
                        TextField("https://planka.example.com", text: $viewModel.urlText)
                            .textContentType(.URL)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .boardlyField()
                    }
                    .padding(.top, 28)

                    VStack(alignment: .leading, spacing: 6) {
                        BoardlyFieldLabel("Nom affiché (optionnel)")
                        TextField("Mon serveur", text: $viewModel.name)
                            .autocorrectionDisabled()
                            .boardlyField()
                    }
                    .padding(.top, 16)

                    if let error = viewModel.error {
                        Text(error)
                            .font(.boardlyCallout)
                            .foregroundStyle(.red)
                            .padding(.top, 16)
                    }

                    Button(action: handleConnect) {
                        if viewModel.isValidating {
                            ProgressView().tint(.white)
                        } else {
                            Text("Se connecter")
                        }
                    }
                    .buttonStyle(.boardlyPrimary)
                    .disabled(!viewModel.canValidate || viewModel.isValidating)
                    .opacity(viewModel.canValidate ? 1 : 0.5)
                    .padding(.top, 28)
                }
                .padding(24)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func handleConnect() {
        Task {
            if let profile = await viewModel.validateAndAdd(profileStore: profileStore) {
                path.append(.login(profileID: profile.id))
            }
        }
    }
}
