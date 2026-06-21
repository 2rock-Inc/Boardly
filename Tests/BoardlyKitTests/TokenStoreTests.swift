import Testing
import Foundation
@testable import BoardlyKit

@Suite("TokenStore")
struct TokenStoreTests {
    @Test("save and load token round-trips")
    func saveAndLoad() throws {
        let keychain = MockKeychainStore()
        let store = TokenStore(profileID: UUID(), keychainStore: keychain)
        try store.saveToken("jwt.token.here")
        let loaded = try store.loadToken()
        #expect(loaded == "jwt.token.here")
    }

    @Test("clearToken removes stored value")
    func clearToken() throws {
        let keychain = MockKeychainStore()
        let store = TokenStore(profileID: UUID(), keychainStore: keychain)
        try store.saveToken("jwt.token.here")
        try store.clearToken()
        let loaded = try store.loadToken()
        #expect(loaded == nil)
    }

    @Test("hasToken returns false when no token stored")
    func hasTokenFalseWhenEmpty() {
        let keychain = MockKeychainStore()
        let store = TokenStore(profileID: UUID(), keychainStore: keychain)
        #expect(store.hasToken() == false)
    }

    @Test("hasToken returns true after saving")
    func hasTokenTrueAfterSave() throws {
        let keychain = MockKeychainStore()
        let store = TokenStore(profileID: UUID(), keychainStore: keychain)
        try store.saveToken("tok")
        #expect(store.hasToken() == true)
    }

    @Test("tokens are scoped by profile ID — different profiles don't share tokens")
    func tokensAreIsolatedByProfileID() throws {
        let keychain = MockKeychainStore()
        let idA = UUID()
        let idB = UUID()
        let storeA = TokenStore(profileID: idA, keychainStore: keychain)
        let storeB = TokenStore(profileID: idB, keychainStore: keychain)

        try storeA.saveToken("tokenA")
        #expect(try storeB.loadToken() == nil)
        #expect(try storeA.loadToken() == "tokenA")
    }
}
