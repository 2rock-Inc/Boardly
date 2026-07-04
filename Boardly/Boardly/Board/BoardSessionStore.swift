import BoardlyKit
import SwiftUI

/// Owns the live board sessions for the active profile: one shared `BoardViewModel`
/// per open board, ref-counted across consumers.
///
/// Opening the same board from two tabs (Projects + Search) must not open two
/// socket subscriptions to the same room — both consumers share one session.
/// Realtime starts on the first `acquire` and tears down on the last `release`.
///
/// Injected per profile session (see `MainView`). Call `reset()` on profile switch
/// or logout: a socket must never outlive the profile that opened it (CLAUDE.md —
/// "the Socket.IO connection is per server profile … never kept alive across profiles").
@Observable
@MainActor
final class BoardSessionStore {
    /// One open board: the shared view model plus how many consumers hold it.
    private final class Entry {
        let viewModel: BoardViewModel
        var refCount: Int
        init(viewModel: BoardViewModel) {
            self.viewModel = viewModel
            refCount = 1
        }
    }

    private var entries: [String: Entry] = [:]

    /// The one Socket.IO connection shared by every board of this profile (Tier 1).
    /// Built lazily on the first board that has a token; reused across boards, and
    /// reconnected if all boards close and one later reopens.
    private var connection: ProfileRealtimeConnection?

    /// Board IDs with at least one live consumer — the source of truth a test (or a
    /// future UI) reads to see which boards are open.
    var openBoardIDs: [String] { Array(entries.keys) }

    /// Current consumer count for a board (0 when closed).
    func consumerCount(_ boardId: String) -> Int { entries[boardId]?.refCount ?? 0 }

    /// Acquire the shared session for a board, subscribing it to the profile's
    /// shared connection on the first consumer. Balance every call with exactly one
    /// `release(boardId:)`.
    func acquire(boardId: String, client: PlankaClient) -> BoardViewModel {
        if let entry = entries[boardId] {
            entry.refCount += 1
            return entry.viewModel
        }
        let viewModel = BoardViewModel(client: client, boardId: boardId)
        entries[boardId] = Entry(viewModel: viewModel)
        if let connection = connection(for: client) {
            viewModel.startRealtime(using: connection)
        }
        return viewModel
    }

    /// Release a consumer; the last release leaves the board's room on the shared
    /// connection (which disconnects when its last board leaves).
    func release(boardId: String) {
        guard let entry = entries[boardId] else { return }
        entry.refCount -= 1
        guard entry.refCount <= 0 else { return }
        entries[boardId] = nil
        Task { await entry.viewModel.stopRealtime() }
    }

    /// Tear every session and the shared connection down. Call on profile switch or
    /// logout so no socket outlives the profile that opened it.
    func reset() {
        let live = entries.values.map(\.viewModel)
        entries.removeAll()
        let connection = connection
        self.connection = nil
        Task {
            for viewModel in live { await viewModel.stopRealtime() }
            await connection?.shutdown()
        }
    }

    /// The profile's shared connection, built once from the profile's base URL +
    /// Keychain token. Returns nil (no live sync) when no token is stored yet.
    private func connection(for client: PlankaClient) -> ProfileRealtimeConnection? {
        if let connection { return connection }
        guard let token = try? TokenStore(profileID: client.profile.id).loadToken() else { return nil }
        let connection = ProfileRealtimeConnection(
            transport: SocketIOTransport(baseURL: client.profile.baseURL),
            token: token)
        self.connection = connection
        return connection
    }
}
