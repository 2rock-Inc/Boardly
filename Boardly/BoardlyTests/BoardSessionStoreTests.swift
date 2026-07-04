//
//  BoardSessionStoreTests.swift
//  BoardlyTests
//
//  Ref-counting behaviour of the shared board-session registry: the same board
//  opened from two tabs (Projects + Search) must share one session (one socket
//  subscription), and the session must tear down only on the last release.
//
//  Realtime is a no-op here: `startRealtime()` early-returns with no Keychain
//  token, so these exercise the acquire/release bookkeeping with no real socket.
//

import BoardlyKit
import Foundation
import Testing
@testable import Boardly

private final class NoKeychain: KeychainStoring, @unchecked Sendable {
    func save(_: String, for _: String) throws {}
    func load(for _: String) throws -> String? { nil }
    func delete(for _: String) throws {}
}

/// Never reached: acquiring a session only creates a `BoardViewModel` and starts
/// realtime (a no-op with no token). No REST call happens in these tests.
private final class UnusedHTTPClient: HTTPClient, @unchecked Sendable {
    func data(for _: URLRequest) async throws -> (Data, URLResponse) {
        throw URLError(.unsupportedURL)
    }
}

@MainActor
private func makeClient(profileID: UUID = UUID()) -> PlankaClient {
    let profile = ServerProfile(id: profileID, name: "Test", baseURL: URL(string: "https://planka.example.com")!)
    let tokenStore = TokenStore(profileID: profile.id, keychainStore: NoKeychain())
    return PlankaClient(profile: profile, tokenStore: tokenStore, httpClient: UnusedHTTPClient())
}

@MainActor
@Suite("BoardSessionStore — ref-counted board sessions")
struct BoardSessionStoreTests {
    @Test("Opening the same board twice shares one session")
    func sameBoardSharesOneSession() {
        let store = BoardSessionStore()
        let client = makeClient()

        let a = store.acquire(boardId: "b1", client: client)
        let b = store.acquire(boardId: "b1", client: client)

        #expect(a === b, "both consumers get the same view model")
        #expect(store.consumerCount("b1") == 2)
        #expect(store.openBoardIDs == ["b1"], "still a single open board")
    }

    @Test("The session survives until the last consumer releases")
    func teardownOnLastRelease() {
        let store = BoardSessionStore()
        let client = makeClient()

        _ = store.acquire(boardId: "b1", client: client)
        _ = store.acquire(boardId: "b1", client: client)

        store.release(boardId: "b1")
        #expect(store.consumerCount("b1") == 1, "one consumer left — still live")
        #expect(store.openBoardIDs == ["b1"])

        store.release(boardId: "b1")
        #expect(store.consumerCount("b1") == 0, "last release tears it down")
        #expect(store.openBoardIDs.isEmpty)
    }

    @Test("Re-acquiring after full teardown creates a fresh session")
    func reacquireAfterTeardownIsFresh() {
        let store = BoardSessionStore()
        let client = makeClient()

        let first = store.acquire(boardId: "b1", client: client)
        store.release(boardId: "b1")
        let second = store.acquire(boardId: "b1", client: client)

        #expect(first !== second, "the dropped session is not reused")
        #expect(store.consumerCount("b1") == 1)
    }

    @Test("Distinct boards are tracked independently")
    func distinctBoardsIndependent() {
        let store = BoardSessionStore()
        let client = makeClient()

        _ = store.acquire(boardId: "b1", client: client)
        _ = store.acquire(boardId: "b2", client: client)

        #expect(Set(store.openBoardIDs) == ["b1", "b2"])

        store.release(boardId: "b1")
        #expect(store.consumerCount("b1") == 0)
        #expect(store.consumerCount("b2") == 1, "releasing one board leaves the other")
        #expect(store.openBoardIDs == ["b2"])
    }

    @Test("reset() drops every session (profile switch / logout)")
    func resetClearsEverything() {
        let store = BoardSessionStore()
        let client = makeClient()

        _ = store.acquire(boardId: "b1", client: client)
        _ = store.acquire(boardId: "b2", client: client)
        _ = store.acquire(boardId: "b2", client: client)

        store.reset()

        #expect(store.openBoardIDs.isEmpty)
        #expect(store.consumerCount("b1") == 0)
        #expect(store.consumerCount("b2") == 0)
    }

    @Test("Releasing an unknown board is a no-op")
    func releaseUnknownIsSafe() {
        let store = BoardSessionStore()
        store.release(boardId: "ghost")
        #expect(store.openBoardIDs.isEmpty)
    }
}
