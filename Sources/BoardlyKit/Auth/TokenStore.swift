import Foundation

public struct TokenStore: Sendable {
    private let keychainStore: any KeychainStoring
    private let profileID: UUID

    public init(profileID: UUID, keychainStore: any KeychainStoring = KeychainStore()) {
        self.profileID = profileID
        self.keychainStore = keychainStore
    }

    private var key: String { "token.\(profileID.uuidString)" }

    public func saveToken(_ token: String) throws {
        try keychainStore.save(token, for: key)
    }

    public func loadToken() throws -> String? {
        try keychainStore.load(for: key)
    }

    public func clearToken() throws {
        try keychainStore.delete(for: key)
    }

    public func hasToken() -> Bool {
        (try? keychainStore.load(for: key)) != nil
    }
}
