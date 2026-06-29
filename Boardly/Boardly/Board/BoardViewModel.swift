import Foundation
import BoardlyKit

@Observable
@MainActor
final class BoardViewModel {
    var payload: BoardPayload?
    var isLoading = false
    var error: String?

    private let client: PlankaClient
    let boardId: String
    private var realtime: BoardRealtimeClient?

    init(client: PlankaClient, boardId: String) {
        self.client = client
        self.boardId = boardId
    }

    // MARK: - Real-time sync

    /// Open the live socket for this board and apply incoming events to `payload`.
    /// Runs until the stream finishes (i.e. `stopRealtime()` is called).
    func startRealtime() async {
        guard realtime == nil else { return }
        let tokenStore = TokenStore(profileID: client.profile.id)
        guard let token = try? tokenStore.loadToken() else { return }

        let rt = BoardRealtimeClient(
            transport: SocketIOTransport(baseURL: client.profile.baseURL),
            boardId: boardId,
            token: token
        )
        realtime = rt

        for await event in await rt.start() {
            if let current = payload {
                payload = current.applying(event)
            } else if case .resynced(let fresh) = event {
                payload = fresh
            }
        }
    }

    /// Tear down the socket. Must be called when leaving the board.
    func stopRealtime() async {
        await realtime?.stop()
        realtime = nil
    }

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            payload = try await client.getBoard(id: boardId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Card CRUD

    func createCard(in list: PlankaList, name: String) async {
        guard let payload else { return }
        let position = payload.nextCardPosition(in: list)
        do {
            let card = try await client.createCard(listId: list.id, name: name, position: position)
            self.payload = BoardPayload(
                board: payload.board,
                lists: payload.lists,
                cards: payload.cards + [card],
                taskLists: payload.taskLists,
                tasks: payload.tasks,
                labels: payload.labels,
                cardMemberships: payload.cardMemberships,
                cardLabels: payload.cardLabels,
                users: payload.users
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    func moveCard(_ card: Card, to list: PlankaList) async {
        guard let payload else { return }
        let position = payload.nextCardPosition(in: list)
        do {
            let updated = try await client.updateCard(
                id: card.id,
                patch: CardPatch(listId: list.id, position: position)
            )
            replaceCard(updated)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteCard(_ card: Card) async {
        guard let payload else { return }
        do {
            try await client.deleteCard(id: card.id)
            self.payload = BoardPayload(
                board: payload.board,
                lists: payload.lists,
                cards: payload.cards.filter { $0.id != card.id },
                taskLists: payload.taskLists,
                tasks: payload.tasks,
                labels: payload.labels,
                cardMemberships: payload.cardMemberships,
                cardLabels: payload.cardLabels,
                users: payload.users
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Task CRUD

    func toggleTask(_ task: PlankaTask) async {
        do {
            let updated = try await client.updateTask(
                id: task.id,
                patch: TaskPatch(isCompleted: !task.isCompleted)
            )
            replaceTask(updated)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func createTask(in taskList: TaskList, name: String) async {
        guard let payload else { return }
        let position = (payload.tasks(for: taskList).last?.position ?? 0) + 65536
        do {
            let task = try await client.createTask(
                taskListId: taskList.id,
                name: name,
                position: position
            )
            self.payload = BoardPayload(
                board: payload.board,
                lists: payload.lists,
                cards: payload.cards,
                taskLists: payload.taskLists,
                tasks: payload.tasks + [task],
                labels: payload.labels,
                cardMemberships: payload.cardMemberships,
                cardLabels: payload.cardLabels,
                users: payload.users
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteTask(_ task: PlankaTask) async {
        guard let payload else { return }
        do {
            try await client.deleteTask(id: task.id)
            self.payload = BoardPayload(
                board: payload.board,
                lists: payload.lists,
                cards: payload.cards,
                taskLists: payload.taskLists,
                tasks: payload.tasks.filter { $0.id != task.id },
                labels: payload.labels,
                cardMemberships: payload.cardMemberships,
                cardLabels: payload.cardLabels,
                users: payload.users
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    func updateCard(_ card: Card, patch: CardPatch) async {
        do {
            let updated = try await client.updateCard(id: card.id, patch: patch)
            replaceCard(updated)
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Set or clear a card's due date. Passing `nil` clears it (sends `dueDate: null`).
    func updateDueDate(_ card: Card, to dueDate: Date?) async {
        let patch = dueDate.map { CardPatch(dueDate: $0) } ?? CardPatch(clearDueDate: true)
        await updateCard(card, patch: patch)
    }

    // MARK: - Local state helpers

    private func replaceCard(_ updated: Card) {
        guard let payload else { return }
        self.payload = BoardPayload(
            board: payload.board,
            lists: payload.lists,
            cards: payload.cards.map { $0.id == updated.id ? updated : $0 },
            taskLists: payload.taskLists,
            tasks: payload.tasks,
            labels: payload.labels,
            cardMemberships: payload.cardMemberships,
            cardLabels: payload.cardLabels,
            users: payload.users
        )
    }

    private func replaceTask(_ updated: PlankaTask) {
        guard let payload else { return }
        self.payload = BoardPayload(
            board: payload.board,
            lists: payload.lists,
            cards: payload.cards,
            taskLists: payload.taskLists,
            tasks: payload.tasks.map { $0.id == updated.id ? updated : $0 },
            labels: payload.labels,
            cardMemberships: payload.cardMemberships,
            cardLabels: payload.cardLabels,
            users: payload.users
        )
    }
}
