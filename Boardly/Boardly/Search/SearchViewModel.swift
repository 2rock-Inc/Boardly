import BoardlyKit
import Foundation

enum SearchScope: String, CaseIterable, Identifiable {
    case all = "All"
    case cards = "Cards"
    case boards = "Boards"
    case projects = "Projects"
    var id: String { rawValue }
}

/// A card matched by search, carrying the context needed to display and open it.
struct CardHit: Identifiable {
    let card: Card
    let boardId: String
    let boardName: String
    let projectName: String
    let listName: String
    var id: String { card.id }
}

struct BoardHit: Identifiable {
    let board: Board
    let projectName: String
    let cardCount: Int
    var id: String { board.id }
}

@Observable
@MainActor
final class SearchViewModel {
    private let client: PlankaClient

    var query = ""
    var scope: SearchScope = .all
    private(set) var isIndexing = false
    var error: String?

    // Session index (built once).
    private var projects: [Project] = []
    private var boardHits: [BoardHit] = []
    private var cardHits: [CardHit] = []
    private var indexed = false

    init(client: PlankaClient) {
        self.client = client
    }

    /// Build the search index once per session: projects + boards from
    /// `GET /projects`, then a concurrent fan-out over every board to index its
    /// cards (PLANKA has no global search endpoint).
    func loadIfNeeded() async {
        guard !indexed, !isIndexing else { return }
        isIndexing = true
        error = nil
        defer { isIndexing = false }
        do {
            let payload = try await client.getProjects()
            projects = payload.projects
            let projectName = Dictionary(
                payload.projects.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })

            let (cards, complete) = await indexCards(boards: payload.boards, projectName: projectName)
            cardHits = cards
            let countByBoard = Dictionary(grouping: cards, by: \.boardId).mapValues(\.count)
            boardHits = payload.boards.map {
                BoardHit(
                    board: $0,
                    projectName: projectName[$0.projectId] ?? "",
                    cardCount: countByBoard[$0.id] ?? 0)
            }
            // Only cache the index as done when every board loaded — otherwise a
            // transient per-board failure would leave cards permanently unfindable
            // for the session; leaving `indexed == false` lets a later call rebuild.
            indexed = complete
        } catch {
            self.error = "Couldn’t index the search."
        }
    }

    /// Fan out over boards. Returns the indexed cards and whether *every* board
    /// loaded (a `nil` per-board result marks a failure).
    private func indexCards(boards: [Board], projectName: [String: String]) async -> (cards: [CardHit], complete: Bool) {
        await withTaskGroup(of: [CardHit]?.self) { group in
            for board in boards {
                let boardName = board.name
                let project = projectName[board.projectId] ?? ""
                group.addTask { [client] in
                    guard let payload = try? await client.getBoard(id: board.id) else { return nil }
                    let listName = Dictionary(
                        payload.lists.map { ($0.id, $0.name ?? "") }, uniquingKeysWith: { first, _ in first })
                    return payload.cards.map { card in
                        CardHit(
                            card: card,
                            boardId: board.id,
                            boardName: boardName,
                            projectName: project,
                            listName: listName[card.listId] ?? "")
                    }
                }
            }
            var all: [CardHit] = []
            var complete = true
            for await result in group {
                if let hits = result { all.append(contentsOf: hits) } else { complete = false }
            }
            return (all, complete)
        }
    }

    // MARK: - Results

    private var normalizedQuery: String { Self.normalize(query) }
    var hasQuery: Bool { !normalizedQuery.isEmpty }

    var projectResults: [Project] {
        guard hasQuery, scope == .all || scope == .projects else { return [] }
        return projects.filter { Self.normalize($0.name).contains(normalizedQuery) }
    }

    var boardResults: [BoardHit] {
        guard hasQuery, scope == .all || scope == .boards else { return [] }
        return boardHits.filter { Self.normalize($0.board.name).contains(normalizedQuery) }
    }

    var cardResults: [CardHit] {
        guard hasQuery, scope == .all || scope == .cards else { return [] }
        return cardHits.filter { Self.normalize($0.card.name).contains(normalizedQuery) }
    }

    var hasAnyResult: Bool {
        !projectResults.isEmpty || !boardResults.isEmpty || !cardResults.isEmpty
    }

    /// Case- and diacritic-insensitive normalization for matching.
    static func normalize(_ text: String) -> String {
        text.folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
