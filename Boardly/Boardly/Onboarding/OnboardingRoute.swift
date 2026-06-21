import Foundation

enum OnboardingRoute: Hashable {
    case addServer
    case login(profileID: UUID)
}
