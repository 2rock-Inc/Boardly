import Foundation
import Testing
@testable import BoardlyKit

@Suite("ProfileStore")
@MainActor
struct ProfileStoreTests {
    func makeSut() -> ProfileStore {
        ProfileStore(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
    }

    @Test("starts with no profiles")
    func startsEmpty() {
        let sut = makeSut()
        #expect(sut.profiles.isEmpty)
        #expect(sut.activeProfile == nil)
    }

    @Test("addProfile appends without activating, even for the first profile")
    func addFirstProfile() {
        // An active profile means an authenticated session, so adding a server must never
        // activate it — doing so sent the very first server straight to the projects list
        // with no token, skipping the login screen entirely.
        let sut = makeSut()
        let profile = makeProfile()
        sut.addProfile(profile)
        #expect(sut.profiles.count == 1)
        #expect(sut.activeProfileID == nil)
    }

    @Test("addProfile second profile does not change active")
    func addSecondProfileKeepsActive() {
        let sut = makeSut()
        let p1 = makeProfile(name: "Server A")
        let p2 = makeProfile(name: "Server B")
        sut.addProfile(p1)
        sut.setActiveProfile(id: p1.id) // as the login flow would, once authenticated
        sut.addProfile(p2)
        #expect(sut.profiles.count == 2)
        #expect(sut.activeProfileID == p1.id)
    }

    @Test("removeProfile removes by ID")
    func removeProfile() {
        let sut = makeSut()
        let profile = makeProfile()
        sut.addProfile(profile)
        sut.removeProfile(id: profile.id)
        #expect(sut.profiles.isEmpty)
    }

    @Test("removeProfile updates activeProfileID when active is removed")
    func removeActiveProfileUpdatesActive() {
        let sut = makeSut()
        let p1 = makeProfile(name: "A")
        let p2 = makeProfile(name: "B")
        sut.addProfile(p1)
        sut.addProfile(p2)
        sut.setActiveProfile(id: p1.id)
        sut.removeProfile(id: p1.id)
        #expect(sut.activeProfileID == p2.id)
    }

    @Test("setActiveProfile switches active")
    func setActiveProfile() {
        let sut = makeSut()
        let p1 = makeProfile(name: "A")
        let p2 = makeProfile(name: "B")
        sut.addProfile(p1)
        sut.addProfile(p2)
        sut.setActiveProfile(id: p2.id)
        #expect(sut.activeProfileID == p2.id)
        #expect(sut.activeProfile?.id == p2.id)
    }

    @Test("clearActiveProfile deactivates without removing the profile")
    func clearActiveProfile() {
        let sut = makeSut()
        let profile = makeProfile()
        sut.addProfile(profile)
        sut.clearActiveProfile()
        #expect(sut.activeProfileID == nil)
        #expect(sut.activeProfile == nil)
        #expect(sut.profiles.count == 1) // profile kept
    }

    @Test("setActiveProfile ignores unknown ID")
    func setActiveProfileUnknownID() {
        let sut = makeSut()
        let p1 = makeProfile()
        sut.addProfile(p1)
        sut.setActiveProfile(id: p1.id)
        sut.setActiveProfile(id: UUID())
        #expect(sut.activeProfileID == p1.id)
    }

    @Test("profiles persist across instances via same UserDefaults")
    func profilesPersist() throws {
        let defaults = try #require(UserDefaults(suiteName: "persist-test-\(UUID().uuidString)"))
        let sut1 = ProfileStore(userDefaults: defaults)
        let profile = makeProfile(name: "Persistent Server")
        sut1.addProfile(profile)

        let sut2 = ProfileStore(userDefaults: defaults)
        #expect(sut2.profiles.count == 1)
        #expect(sut2.profiles[0].name == "Persistent Server")
        // Saved, but never logged into — relaunching must not resume a session.
        #expect(sut2.activeProfileID == nil)
    }

    @Test("an authenticated profile is restored on relaunch")
    func activeProfileRestored() throws {
        let defaults = try #require(UserDefaults(suiteName: "restore-test-\(UUID().uuidString)"))
        let sut1 = ProfileStore(userDefaults: defaults)
        let profile = makeProfile()
        sut1.addProfile(profile)
        sut1.setActiveProfile(id: profile.id)

        let sut2 = ProfileStore(userDefaults: defaults)
        #expect(sut2.activeProfileID == profile.id)
    }

    @Test("clearing the active profile survives a relaunch")
    func clearedProfileStaysCleared() throws {
        // Logout and "switch server" both drop the stored active profile. Relaunching used
        // to fall back to the first profile, dropping the user straight back into a session
        // they had just left — and, once logged out, one with no token at all.
        let defaults = try #require(UserDefaults(suiteName: "logout-test-\(UUID().uuidString)"))
        let sut1 = ProfileStore(userDefaults: defaults)
        let profile = makeProfile()
        sut1.addProfile(profile)
        sut1.setActiveProfile(id: profile.id)
        sut1.clearActiveProfile()

        let sut2 = ProfileStore(userDefaults: defaults)
        #expect(sut2.profiles.count == 1) // the server is still listed
        #expect(sut2.activeProfileID == nil) // but no session is resumed
    }

    @Test("makeClient creates PlankaClient bound to profile")
    func makeClient() {
        let sut = makeSut()
        let profile = makeProfile()
        let client = sut.makeClient(for: profile)
        #expect(client.profile.id == profile.id)
    }
}
