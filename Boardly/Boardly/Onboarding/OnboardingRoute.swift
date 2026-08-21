import Foundation

enum OnboardingRoute: Hashable {
    case addServer
    case login(profileID: UUID)
    /// Terms the instance requires before it will issue a token. `pendingToken` carries
    /// the half-finished sign-in and expires within minutes.
    case terms(profileID: UUID, pendingToken: String)
}
