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
        Form {
            Section("Server URL") {
                TextField("https://planka.example.com", text: $viewModel.urlText)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }

            Section("Display Name (optional)") {
                TextField("My Server", text: $viewModel.name)
                    .autocorrectionDisabled()
            }

            if let error = viewModel.error {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
        }
        .navigationTitle("Add Server")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if viewModel.isValidating {
                    ProgressView()
                } else {
                    Button("Connect") {
                        Task {
                            if let profile = await viewModel.validateAndAdd(profileStore: profileStore) {
                                path.append(.login(profileID: profile.id))
                            }
                        }
                    }
                    .disabled(!viewModel.canValidate)
                }
            }
        }
    }
}
