//
//  SearchViewModelTests.swift
//  BoardlyTests
//
//  Integration tests for the Recherche view model: indexing projects/boards +
//  fanning out to cards, and the case/diacritic-insensitive filtering by scope.
//

import Foundation
import Testing
import BoardlyKit
@testable import Boardly

private final class SearchStubHTTP: HTTPClient, @unchecked Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let path = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.path ?? ""
        let json: String
        if path.hasSuffix("/api/projects") {
            json = """
            {"items":[{"id":"p1","name":"Refonte 2026","isHidden":false}],
             "included":{"boards":[{"id":"b1","projectId":"p1","name":"Sprint Produit","position":1}]}}
            """
        } else if path.contains("/api/boards/") {
            json = """
            {"item":{"id":"b1","projectId":"p1","name":"Sprint Produit"},
             "included":{"lists":[{"id":"l1","boardId":"b1","type":"active","name":"À faire","position":1}],
             "cards":[{"id":"c1","boardId":"b1","listId":"l1","type":"active","position":1,"name":"Nouvelle page d’accueil"},
                      {"id":"c2","boardId":"b1","listId":"l1","type":"active","position":2,"name":"Refonte tablette"}],
             "taskLists":[],"tasks":[]}}
            """
        } else {
            json = "{}"
        }
        let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (Data(json.utf8), resp)
    }
}

@MainActor
@Suite("SearchViewModel")
struct SearchViewModelTests {
    private func makeViewModel() -> SearchViewModel {
        let profile = ServerProfile(name: "T", baseURL: URL(string: "https://mock.local")!)
        let client = PlankaClient(
            profile: profile,
            tokenStore: TokenStore(profileID: profile.id, keychainStore: EphemeralKeychain()),
            httpClient: SearchStubHTTP()
        )
        return SearchViewModel(client: client)
    }

    @Test("normalize is case- and diacritic-insensitive")
    func normalize() {
        #expect(SearchViewModel.normalize("À Faire") == "a faire")
    }

    @Test("indexes cards via fan-out and matches diacritic-insensitively")
    func cardSearch() async {
        let vm = makeViewModel()
        await vm.loadIfNeeded()
        vm.query = "accueil" // matches "Nouvelle page d’accueil"
        #expect(vm.cardResults.map(\.card.id) == ["c1"])
        #expect(vm.cardResults.first?.listName == "À faire")
        #expect(vm.cardResults.first?.projectName == "Refonte 2026")
    }

    @Test("scope filters which result kinds are returned")
    func scopeFiltering() async {
        let vm = makeViewModel()
        await vm.loadIfNeeded()
        vm.query = "produit" // matches the board "Sprint Produit"
        #expect(!vm.boardResults.isEmpty)

        vm.scope = .cards
        #expect(vm.boardResults.isEmpty) // boards suppressed under the Cartes scope
    }

    @Test("empty query yields no results")
    func emptyQuery() async {
        let vm = makeViewModel()
        await vm.loadIfNeeded()
        #expect(vm.hasQuery == false)
        #expect(vm.hasAnyResult == false)
    }
}

/// Minimal in-memory Keychain for tests that never need a token.
private final class EphemeralKeychain: KeychainStoring, @unchecked Sendable {
    private var store: [String: String] = [:]
    func save(_ value: String, for key: String) throws { store[key] = value }
    func load(for key: String) throws -> String? { store[key] }
    func delete(for key: String) throws { store[key] = nil }
}
