import Foundation

/// Why PLANKA refused a sign-in attempt with `E_FORBIDDEN`.
///
/// A 403 on `/access-tokens` does not mean one thing: PLANKA distinguishes several
/// situations through the response's `message`, and only one of them is a dead end for
/// the user. Collapsing them all into `.forbidden` cost the app any chance of telling
/// someone what to actually do next.
///
/// The response also carries a `pendingToken` when the flow can be resumed — undocumented
/// in `planka-openapi.json`, but present in practice and required by
/// `POST /access-tokens/accept-terms`.
public struct AuthRestriction: Sendable, Equatable {
    public enum Reason: Sendable, Equatable {
        /// The user must read and accept the instance's terms before a token is issued.
        /// Resumable: pair `pendingToken` with the signature from `GET /terms`.
        case termsAcceptanceRequired
        /// The instance only accepts OIDC sign-in; password login is refused.
        case useSingleSignOn
        /// A fresh instance that no one has initialised yet — an admin has to sign in first.
        case adminLoginRequired
        /// A restriction this version of Boardly does not know about. The raw message is
        /// kept so it can be logged and surfaced rather than swallowed.
        case unknown(String)

        init(message: String) {
            switch message {
            case "Terms acceptance required": self = .termsAcceptanceRequired
            case "Use single sign-on": self = .useSingleSignOn
            case "Admin login required to initialize instance": self = .adminLoginRequired
            default: self = .unknown(message)
            }
        }
    }

    public let reason: Reason
    /// Short-lived token identifying the half-finished sign-in (ten minutes, in practice).
    /// Present only for restrictions that can be resolved by continuing the flow.
    public let pendingToken: String?

    public init(reason: Reason, pendingToken: String?) {
        self.reason = reason
        self.pendingToken = pendingToken
    }
}
