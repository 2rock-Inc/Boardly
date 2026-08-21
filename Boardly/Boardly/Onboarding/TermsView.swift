import BoardlyKit
import SwiftUI

@Observable
@MainActor
final class TermsViewModel {
    var terms: Terms?
    var isLoading = true
    var isAccepting = false
    var error: String?

    /// The terms are Markdown written by whoever runs the instance, so they are server
    /// data: parsed for display, never localized. Block syntax (headings, lists) is beyond
    /// `AttributedString`'s Markdown support, so inline parsing that keeps the author's
    /// line breaks is the honest rendering rather than one that silently collapses them.
    var attributedContent: AttributedString {
        guard let content = terms?.content else { return AttributedString() }
        let parsed = try? AttributedString(
            markdown: content,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))
        return parsed ?? AttributedString(content)
    }

    func load(using client: PlankaClient) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            terms = try await client.getTerms(language: Locale.preferredLanguages.first)
        } catch {
            self.error = localizedErrorMessage(error)
        }
    }

    /// Returns whether the sign-in completed, leaving a token stored for the profile.
    func accept(pendingToken: String, using client: PlankaClient) async -> Bool {
        guard let signature = terms?.signature else { return false }
        isAccepting = true
        error = nil
        defer { isAccepting = false }
        do {
            try await client.acceptTerms(pendingToken: pendingToken, signature: signature)
            return true
        } catch let apiError as PlankaAPIError {
            switch apiError {
            case .unauthorized:
                // The pending token only lives a few minutes; there is nothing to retry
                // here, the sign-in has to start over.
                error = String(localized: "This took too long and the sign-in expired. Please sign in again.")
            case .forbidden, .authRestriction:
                error = String(localized: "The server rejected these terms. Try signing in again.")
            default:
                error = localizedErrorMessage(apiError)
            }
        } catch {
            self.error = localizedErrorMessage(error)
        }
        return false
    }
}

struct TermsView: View {
    let profile: ServerProfile
    let pendingToken: String
    @Binding var path: [OnboardingRoute]

    @Environment(ProfileStore.self) private var profileStore
    @State private var viewModel = TermsViewModel()

    var body: some View {
        BoardlyScreen(title: "Terms of Service") {
            VStack(alignment: .leading, spacing: 16) {
                Text("\(profile.name) requires you to accept its terms before you can sign in.")
                    .font(.boardlyBody)
                    .foregroundStyle(Color.boardlyTextSecondary)
                    .padding(.horizontal, 20)

                content

                if let error = viewModel.error {
                    Text(error)
                        .font(.boardlyCallout)
                        .foregroundStyle(Color.boardlyDestructive)
                        .padding(.horizontal, 20)
                }

                actions
            }
        }
        .navigationTitle("")
        .task { await viewModel.load(using: profileStore.makeClient(for: profile)) }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            Spacer()
            ProgressView().frame(maxWidth: .infinity)
            Spacer()
        } else if viewModel.terms != nil {
            ScrollView {
                Text(viewModel.attributedContent) // server data — rendered, not localized
                    .font(.boardlyBody)
                    .foregroundStyle(Color.boardlyInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .boardlyCard()
                    .padding(.horizontal, 20)
            }
        } else {
            Spacer()
            Text("The terms couldn’t be loaded.")
                .font(.boardlyBody)
                .foregroundStyle(Color.boardlyTextSecondary)
                .frame(maxWidth: .infinity)
            Spacer()
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button(action: handleAccept) {
                if viewModel.isAccepting {
                    ProgressView().tint(.white)
                } else {
                    Text("Accept and Continue")
                }
            }
            .buttonStyle(.boardlyPrimary)
            .disabled(viewModel.terms == nil || viewModel.isAccepting)
            .opacity(viewModel.terms == nil ? 0.5 : 1)

            Button("Cancel") { path.removeLast() }
                .buttonStyle(.boardlySecondary)
                .disabled(viewModel.isAccepting)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private func handleAccept() {
        Task {
            let client = profileStore.makeClient(for: profile)
            if await viewModel.accept(pendingToken: pendingToken, using: client) {
                // A token is stored now, so activating the profile is safe — RootView
                // swaps to MainView.
                profileStore.setActiveProfile(id: profile.id)
            }
        }
    }
}
