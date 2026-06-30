import Testing
import Foundation
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

    @Test("addProfile appends and sets as active when it's the first")
    func addFirstProfile() {
        let sut = makeSut()
        let profile = makeProfile()
        sut.addProfile(profile)
        #expect(sut.profiles.count == 1)
        #expect(sut.activeProfileID == profile.id)
    }

    @Test("addProfile second profile does not change active")
    func addSecondProfileKeepsActive() {
        let sut = makeSut()
        let p1 = makeProfile(name: "Server A")
        let p2 = makeProfile(name: "Server B")
        sut.addProfile(p1)
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
        sut.setActiveProfile(id: UUID())
        #expect(sut.activeProfileID == p1.id)
    }

    @Test("profiles persist across instances via same UserDefaults")
    func profilesPersist() {
        let defaults = UserDefaults(suiteName: "persist-test-\(UUID().uuidString)")!
        let sut1 = ProfileStore(userDefaults: defaults)
        let profile = makeProfile(name: "Persistent Server")
        sut1.addProfile(profile)

        let sut2 = ProfileStore(userDefaults: defaults)
        #expect(sut2.profiles.count == 1)
        #expect(sut2.profiles[0].name == "Persistent Server")
        #expect(sut2.activeProfileID == profile.id)
    }

    @Test("makeClient creates PlankaClient bound to profile")
    func makeClient() {
        let sut = makeSut()
        let profile = makeProfile()
        let client = sut.makeClient(for: profile)
        #expect(client.profile.id == profile.id)
    }
}
