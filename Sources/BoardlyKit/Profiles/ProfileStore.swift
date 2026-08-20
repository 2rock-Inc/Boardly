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

    /// Adds a profile without activating it.
    ///
    /// An active profile stands for an *authenticated* session: `RootView` swaps to
    /// `MainView` as soon as `activeProfile` is non-nil. Activating a server the moment it
    /// is added would put the app in a session it holds no token for — and, because the
    /// swap is a full-screen cover, would bury the login screen the caller just pushed.
    /// Activation belongs to the login flow, which calls `setActiveProfile` once a token
    /// is stored.
    public func addProfile(_ profile: ServerProfile) {
        BoardlyLog.tag(.profile).icon("➕").info("Profile added", metadata: ["name": profile.name])
        profiles.append(profile)
        saveToUserDefaults()
    }

    public func removeProfile(id: UUID) {
        BoardlyLog.tag(.profile).icon("🗑️").info("Profile removed", metadata: ["id": id.uuidString])
        // Clear the profile's Keychain token here so every removal path is covered
        // (swipe-to-delete bypasses logout) — a deleted server must leave no
        // stranded, still-valid credential behind.
        try? TokenStore(profileID: id).clearToken()
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

    /// Deactivate the current profile (return to the server picker) without
    /// removing it. Used by "switch server" / logout.
    public func clearActiveProfile() {
        BoardlyLog.tag(.profile).icon("🔄").info("Active profile cleared")
        activeProfileID = nil
        userDefaults.removeObject(forKey: activeProfileKey)
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
        // Restore only an explicitly stored active profile. Falling back to the first
        // one would re-enter a session nobody asked for: after "switch server" or logout
        // the stored key is deliberately absent, and a freshly added server has never had
        // one — in both cases the app must come back to the server picker.
        if let idString = userDefaults.string(forKey: activeProfileKey),
           let id = UUID(uuidString: idString),
           profiles.contains(where: { $0.id == id })
        {
            activeProfileID = id
        }
    }

    private func saveToUserDefaults() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        userDefaults.set(data, forKey: profilesKey)
    }
}
