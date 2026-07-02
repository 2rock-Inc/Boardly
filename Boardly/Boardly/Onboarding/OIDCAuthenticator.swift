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

/// The parameters needed to run one SSO attempt, derived from `Bootstrap.oidc`.
///
/// PLANKA advertises a *base* authorization URL without `nonce`/`state` — the
/// client is expected to generate them, add them to the request, and send the
/// nonce back at token exchange (PLANKA has none stored server-side, so it relies
/// on ours). We also force `response_mode=query` so the authorization `code`
/// comes back in the query string, which is reliable to intercept natively (the
/// advertised default is `fragment`, which is not).
struct OIDCSession: Identifiable {
    let id = UUID()
    /// The URL to actually load — the advertised one plus our nonce/state and a
    /// forced `response_mode=query`.
    let requestURL: URL
    /// `scheme://host[:port]/path` of the provider's redirect_uri — navigations
    /// to this location carry the authorization `code`.
    let redirectPrefix: String
    let nonce: String
    let state: String

    /// `baseURL` is the profile's server URL, used to derive the redirect target
    /// when PLANKA keeps `redirect_uri` server-side (absent from the auth URL).
    init?(oidc: Bootstrap.OIDCConfig, baseURL: URL) {
        guard let url = URL(string: oidc.authorizationUrl),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }

        let nonce = Self.randomToken()
        let state = Self.randomToken()
        self.nonce = nonce
        self.state = state

        // Determine the redirect target (from the URL, else derived from base URL)
        // before we rebuild the query.
        let advertisedRedirect = components.queryItems?.first(where: { $0.name == "redirect_uri" })?.value
        if let redirect = advertisedRedirect,
           let rc = URLComponents(string: redirect), let scheme = rc.scheme, let host = rc.host {
            let port = rc.port.map { ":\($0)" } ?? ""
            self.redirectPrefix = "\(scheme)://\(host)\(port)\(rc.path)"
        } else if let scheme = baseURL.scheme, let host = baseURL.host {
            let port = baseURL.port.map { ":\($0)" } ?? ""
            let basePath = baseURL.path.hasSuffix("/") ? String(baseURL.path.dropLast()) : baseURL.path
            self.redirectPrefix = "\(scheme)://\(host)\(port)\(basePath)/oidc-callback"
        } else {
            return nil
        }

        var items = (components.queryItems ?? [])
            .filter { !["response_mode", "nonce", "state"].contains($0.name) }
        items.append(URLQueryItem(name: "response_mode", value: "query"))
        items.append(URLQueryItem(name: "nonce", value: nonce))
        items.append(URLQueryItem(name: "state", value: state))
        // If PLANKA omitted redirect_uri, add the derived one so the IdP redirects back.
        if advertisedRedirect == nil {
            items.append(URLQueryItem(name: "redirect_uri", value: redirectPrefix))
        }
        components.queryItems = items

        guard let requestURL = components.url else { return nil }
        self.requestURL = requestURL
    }

    /// A URL-safe, unguessable token for `nonce` / `state`.
    private static func randomToken() -> String {
        (UUID().uuidString + UUID().uuidString).replacingOccurrences(of: "-", with: "")
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
        // Ephemeral data store: the IdP session cookie lives only for the duration
        // of this flow and is never persisted. This prevents a shared/kiosk device
        // from silently re-authenticating a *previous* user after logout (the app
        // clears the Keychain token, but a persistent web session would otherwise
        // survive and hand back a fresh code for the old identity).
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: session.requestURL))
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
                // CSRF protection: the returned state must be present AND match
                // the one we generated for this session.
                guard let returnedState = all.first(where: { $0.name == "state" })?.value,
                      returnedState == session.state
                else {
                    onResult(.failure(OIDCError.providerError("state mismatch")))
                    return
                }
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
