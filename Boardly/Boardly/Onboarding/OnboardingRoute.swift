import Foundation

enum OnboardingRoute: Hashable {
    case addServer
    case login(profileID: UUID)
    case main(profileID: UUID)
}
