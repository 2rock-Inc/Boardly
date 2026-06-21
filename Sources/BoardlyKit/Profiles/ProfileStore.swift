import Foundation
import Observation

@MainActor
@Observable
public final class ProfileStore {
    public private(set) var profiles: [ServerProfile] = []
    public private(set) var activeProfileID: UUID?

    private let userDefaults: UserDefaults
    private let profilesKey = "boardly.profiles"
    private let activeProfileKey = "boardly.activeProfileID"

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadFromUserDefaults()
    }

    public var activeProfile: ServerProfile? {
        guard let id = activeProfileID else { return nil }
        return profiles.first { $0.id == id }
    }

    public func addProfile(_ profile: ServerProfile) {
        BoardlyLog.tag(.profile).icon("➕").info("Profile added", metadata: ["name": profile.name])
        profiles.append(profile)
        if profiles.count == 1 {
            activeProfileID = profile.id
            userDefaults.set(profile.id.uuidString, forKey: activeProfileKey)
        }
        saveToUserDefaults()
    }

    public func removeProfile(id: UUID) {
        BoardlyLog.tag(.profile).icon("🗑️").info("Profile removed", metadata: ["id": id.uuidString])
        profiles.removeAll { $0.id == id }
        if activeProfileID == id {
            activeProfileID = profiles.first?.id
            userDefaults.set(activeProfileID?.uuidString, forKey: activeProfileKey)
        }
        saveToUserDefaults()
    }

    public func setActiveProfile(id: UUID) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        BoardlyLog.tag(.profile).icon("🔄").info("Active profile set", metadata: ["id": id.uuidString])
        activeProfileID = id
        userDefaults.set(id.uuidString, forKey: activeProfileKey)
    }

    public func makeClient(for profile: ServerProfile, httpClient: any HTTPClient = URLSessionHTTPClient()) -> PlankaClient {
        let tokenStore = TokenStore(profileID: profile.id)
        return PlankaClient(profile: profile, tokenStore: tokenStore, httpClient: httpClient)
    }

    public func makeClientForActive(httpClient: any HTTPClient = URLSessionHTTPClient()) -> PlankaClient? {
        guard let profile = activeProfile else { return nil }
        return makeClient(for: profile, httpClient: httpClient)
    }

    public func tokenStore(for profile: ServerProfile) -> TokenStore {
        TokenStore(profileID: profile.id)
    }

    // MARK: - Persistence

    private func loadFromUserDefaults() {
        guard let data = userDefaults.data(forKey: profilesKey),
              let decoded = try? JSONDecoder().decode([ServerProfile].self, from: data)
        else { return }
        profiles = decoded
        if let idString = userDefaults.string(forKey: activeProfileKey),
           let id = UUID(uuidString: idString),
           profiles.contains(where: { $0.id == id }) {
            activeProfileID = id
        } else {
            activeProfileID = profiles.first?.id
        }
    }

    private func saveToUserDefaults() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        userDefaults.set(data, forKey: profilesKey)
    }
}
