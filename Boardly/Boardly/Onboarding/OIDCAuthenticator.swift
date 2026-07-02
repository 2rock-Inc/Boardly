import AuthenticationServices
import BoardlyKit
import UIKit

/// Drives the native OIDC/SSO login leg with `ASWebAuthenticationSession`.
///
/// PLANKA advertises a ready-made `authorizationUrl` in `Bootstrap.oidc`. We open
/// it in the secure in-app browser, let the user authenticate with the identity
/// provider, and capture the `code` from the redirect. The matching `nonce` is
/// the one PLANKA already embedded in `authorizationUrl`, so we read it back out
/// and hand both to `PlankaClient.exchangeOIDC(code:nonce:)`.
///
/// ⚠️ Instance requirement (verify on your server): the provider must redirect to
/// a **custom URL scheme** (e.g. `boardly://oidc-callback`) registered in the OIDC
/// client, otherwise iOS cannot hand control back to the app. An `https` redirect
/// to the PLANKA host cannot be intercepted here and surfaces `unsupportedRedirect`.
@MainActor
final class OIDCAuthenticator: NSObject, ASWebAuthenticationPresentationContextProviding {
    /// The custom scheme the app registers for the OIDC redirect.
    static let callbackScheme = "boardly"

    enum OIDCError: LocalizedError {
        case invalidAuthorizationURL
        case missingNonce
        case unsupportedRedirect(String?)
        case missingCode
        case cancelled

        var errorDescription: String? {
            switch self {
            case .invalidAuthorizationURL: return "URL d’autorisation OIDC invalide."
            case .missingNonce: return "Le serveur n’a pas fourni de nonce OIDC."
            case .unsupportedRedirect(let scheme):
                return "La redirection OIDC utilise « \(scheme ?? "?") » ; un schéma d’URL dédié (ex. boardly://) est requis côté fournisseur."
            case .missingCode: return "Aucun code d’autorisation reçu du fournisseur."
            case .cancelled: return "Connexion SSO annulée."
            }
        }
    }

    private var session: ASWebAuthenticationSession?

    /// Runs the browser leg and returns the `(code, nonce)` needed to exchange
    /// for a PLANKA access token.
    func authenticate(authorizationURL: String) async throws -> (code: String, nonce: String) {
        guard let url = URL(string: authorizationURL),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { throw OIDCError.invalidAuthorizationURL }

        guard let nonce = components.queryItems?.first(where: { $0.name == "nonce" })?.value,
              !nonce.isEmpty
        else { throw OIDCError.missingNonce }

        // The scheme to listen for is dictated by the provider's redirect_uri.
        let redirectScheme = components.queryItems?
            .first(where: { $0.name == "redirect_uri" })?.value
            .flatMap { URL(string: $0)?.scheme }
        let scheme = redirectScheme ?? Self.callbackScheme
        guard scheme.lowercased() != "http", scheme.lowercased() != "https" else {
            throw OIDCError.unsupportedRedirect(scheme)
        }

        BoardlyLog.tag(.auth).icon("🔐").info("Starting OIDC browser session",
                                               metadata: ["scheme": scheme])

        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { callback, error in
                if let callback {
                    continuation.resume(returning: callback)
                } else if let error, (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin {
                    continuation.resume(throwing: OIDCError.cancelled)
                } else {
                    continuation.resume(throwing: error ?? OIDCError.cancelled)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            session.start()
        }

        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value
        else { throw OIDCError.missingCode }

        return (code, nonce)
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        if let window = scene?.keyWindow { return window }
        if let scene { return ASPresentationAnchor(windowScene: scene) }
        return ASPresentationAnchor(frame: .zero)
    }
}
