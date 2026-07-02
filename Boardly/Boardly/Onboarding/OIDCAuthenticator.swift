import BoardlyKit
import SwiftUI
import WebKit

/// Native OIDC/SSO login for PLANKA via an intercepting `WKWebView`.
///
/// PLANKA advertises a ready-made `authorizationUrl` in `Bootstrap.oidc` and,
/// being a web-first app, configures its OIDC `redirect_uri` as an **https URL on
/// its own host** (e.g. `https://todo.2rock.fr/oidc-callback`). A custom-scheme
/// approach (`ASWebAuthenticationSession`) can't capture that, so we host the auth
/// flow in a `WKWebView` and intercept the navigation to the redirect URL,
/// pulling the `code` out before the page loads. The matching `nonce` is the one
/// PLANKA embedded in `authorizationUrl`; we read it back and hand `(code, nonce)`
/// to `PlankaClient.exchangeOIDC(code:nonce:)`.

// MARK: - Session

/// The parameters needed to run one SSO attempt, parsed from `Bootstrap.oidc`.
struct OIDCSession: Identifiable {
    let id = UUID()
    let authorizationURL: URL
    /// `scheme://host[:port]/path` of the provider's redirect_uri — navigations
    /// to this location carry the authorization `code`.
    let redirectPrefix: String
    let nonce: String

    init?(oidc: Bootstrap.OIDCConfig) {
        guard let url = URL(string: oidc.authorizationUrl),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let nonce = components.queryItems?.first(where: { $0.name == "nonce" })?.value,
              !nonce.isEmpty,
              let redirect = components.queryItems?.first(where: { $0.name == "redirect_uri" })?.value,
              let redirectComponents = URLComponents(string: redirect),
              let scheme = redirectComponents.scheme,
              let host = redirectComponents.host
        else { return nil }

        self.authorizationURL = url
        self.nonce = nonce
        let port = redirectComponents.port.map { ":\($0)" } ?? ""
        self.redirectPrefix = "\(scheme)://\(host)\(port)\(redirectComponents.path)"
    }
}

enum OIDCError: LocalizedError {
    case notConfigured
    case missingCode
    case providerError(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Configuration OIDC invalide (URL, nonce ou redirection manquants)."
        case .missingCode: return "Aucun code d’autorisation reçu du fournisseur."
        case .providerError(let message): return "Le fournisseur SSO a renvoyé une erreur : \(message)."
        }
    }
}

// MARK: - Presented flow

/// Full-screen SSO web flow with a cancel affordance. Reports the captured
/// authorization `code` on success.
struct OIDCWebFlow: View {
    let session: OIDCSession
    let onCode: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            OIDCWebAuthView(session: session) { result in
                switch result {
                case .success(let code): onCode(code)
                case .failure: onCancel()
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Connexion SSO")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler", action: onCancel)
                }
            }
        }
    }
}

// MARK: - Intercepting web view

private struct OIDCWebAuthView: UIViewRepresentable {
    let session: OIDCSession
    let onResult: (Result<String, Error>) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session, onResult: onResult)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: session.authorizationURL))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let session: OIDCSession
        private let onResult: (Result<String, Error>) -> Void
        private var finished = false

        init(session: OIDCSession, onResult: @escaping (Result<String, Error>) -> Void) {
            self.session = session
            self.onResult = onResult
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard !finished, let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            if matchesRedirect(url) {
                finish(with: url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }

        /// True when `url` is the provider's redirect target (ignoring the query).
        private func matchesRedirect(_ url: URL) -> Bool {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let scheme = components.scheme, let host = components.host
            else { return false }
            let port = components.port.map { ":\($0)" } ?? ""
            let base = "\(scheme)://\(host)\(port)\(components.path)"
            return base == session.redirectPrefix
        }

        private func finish(with url: URL) {
            finished = true
            // `code` may arrive in the query (default) or the fragment.
            let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let fragmentItems = fragmentParameters(of: url)
            let all = queryItems + fragmentItems

            if let error = all.first(where: { $0.name == "error" })?.value {
                onResult(.failure(OIDCError.providerError(error)))
            } else if let code = all.first(where: { $0.name == "code" })?.value {
                onResult(.success(code))
            } else {
                onResult(.failure(OIDCError.missingCode))
            }
        }

        private func fragmentParameters(of url: URL) -> [URLQueryItem] {
            guard let fragment = URLComponents(url: url, resolvingAgainstBaseURL: false)?.fragment else { return [] }
            var parser = URLComponents()
            parser.query = fragment
            return parser.queryItems ?? []
        }
    }
}
