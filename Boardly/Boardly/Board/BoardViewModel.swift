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
    private var realtimeTask: Task<Void, Never>?

    init(client: PlankaClient, boardId: String) {
        self.client = client
        self.boardId = boardId
    }

    // MARK: - Real-time sync

    /// Open the live socket for this board and apply incoming events to `payload`.
    /// Non-blocking: the event loop runs in a stored Task tied to the view model's
    /// lifetime (not the view's), so pushing the card detail doesn't tear it down.
    func startRealtime() {
        guard realtime == nil else { return }
        let tokenStore = TokenStore(profileID: client.profile.id)
        guard let token = try? tokenStore.loadToken() else { return }

        let rt = BoardRealtimeClient(
            transport: SocketIOTransport(baseURL: client.profile.baseURL),
            boardId: boardId,
            token: token
        )
        realtime = rt
        realtimeTask = Task { [weak self] in
            for await event in await rt.start() {
                guard let self else { break }
                if let current = self.payload {
                    self.payload = current.applying(event)
                } else if case .resynced(let fresh) = event {
                    self.payload = fresh
                }
            }
        }
    }

    /// Tear down the socket. Must be called only when actually leaving the board.
    func stopRealtime() async {
        realtimeTask?.cancel()
        realtimeTask = nil
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
            var updated = payload
            updated.cards.append(card)
            self.payload = updated
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
            var updated = payload
            updated.cards.removeAll { $0.id == card.id }
            self.payload = updated
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
            var updated = payload
            updated.tasks.append(task)
            self.payload = updated
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteTask(_ task: PlankaTask) async {
        guard let payload else { return }
        do {
            try await client.deleteTask(id: task.id)
            var updated = payload
            updated.tasks.removeAll { $0.id == task.id }
            self.payload = updated
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

    // MARK: - Labels

    func addLabel(_ label: Label, to card: Card) async {
        do {
            let cardLabel = try await client.addCardLabel(cardId: card.id, labelId: label.id)
            guard var copy = payload else { return }
            if !copy.cardLabels.contains(where: { $0.id == cardLabel.id }) {
                copy.cardLabels.append(cardLabel)
            }
            payload = copy
        } catch {
            self.error = error.localizedDescription
        }
    }

    func removeLabel(_ label: Label, from card: Card) async {
        do {
            try await client.removeCardLabel(cardId: card.id, labelId: label.id)
            guard var copy = payload else { return }
            copy.cardLabels.removeAll { $0.cardId == card.id && $0.labelId == label.id }
            payload = copy
        } catch {
            self.error = error.localizedDescription
        }
    }

    func createLabel(name: String, color: String) async {
        guard var copy = payload else { return }
        let position = (copy.labels.map { $0.position ?? 0 }.max() ?? 0) + 65536
        do {
            let label = try await client.createLabel(boardId: boardId, name: name, color: color, position: position)
            copy.labels.append(label)
            payload = copy
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Members

    func addMember(_ user: User, to card: Card) async {
        do {
            let membership = try await client.addCardMember(cardId: card.id, userId: user.id)
            guard var copy = payload else { return }
            if !copy.cardMemberships.contains(where: { $0.id == membership.id }) {
                copy.cardMemberships.append(membership)
            }
            payload = copy
        } catch {
            self.error = error.localizedDescription
        }
    }

    func removeMember(_ user: User, from card: Card) async {
        do {
            try await client.removeCardMember(cardId: card.id, userId: user.id)
            guard var copy = payload else { return }
            copy.cardMemberships.removeAll { $0.cardId == card.id && $0.userId == user.id }
            payload = copy
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Comments

    /// The logged-in user, resolved from the token + board users (for authoring UI).
    var currentUser: User? {
        guard let uid = client.currentUserId() else { return nil }
        return payload?.users.first { $0.id == uid }
    }

    /// Returns nil on failure (so the UI can distinguish "empty" from "couldn't load").
    func loadComments(cardId: String) async -> [Comment]? {
        do {
            return try await client.getComments(cardId: cardId)
                .sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    func postComment(cardId: String, text: String) async -> Comment? {
        do {
            let comment = try await client.createComment(cardId: cardId, text: text)
            adjustCommentsTotal(cardId: cardId, by: 1)
            return comment
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    /// Deletes a comment; returns true on success so the caller only removes it
    /// from local state when the server confirms.
    func deleteComment(id: String, cardId: String) async -> Bool {
        do {
            try await client.deleteComment(id: id)
            adjustCommentsTotal(cardId: cardId, by: -1)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    private func adjustCommentsTotal(cardId: String, by delta: Int) {
        guard var copy = payload, let card = copy.card(id: cardId) else { return }
        copy.setCommentsTotal(cardId: cardId, max(0, (card.commentsTotal ?? 0) + delta))
        payload = copy
    }

    // MARK: - Images

    func loadImage(url: URL) async -> Data? {
        await client.imageData(url: url)
    }

    // MARK: - Attachments

    func uploadAttachment(cardId: String, fileName: String, mimeType: String, data: Data) async {
        do {
            let attachment = try await client.uploadFileAttachment(
                cardId: cardId, fileName: fileName, mimeType: mimeType, data: data
            )
            guard var copy = payload else { return }
            copy.attachments.append(attachment)
            payload = copy
        } catch {
            self.error = error.localizedDescription
        }
    }

    func addLinkAttachment(cardId: String, url: String, name: String) async {
        do {
            let attachment = try await client.addLinkAttachment(cardId: cardId, url: url, name: name)
            guard var copy = payload else { return }
            copy.attachments.append(attachment)
            payload = copy
        } catch {
            self.error = error.localizedDescription
        }
    }

    func removeAttachment(_ attachment: Attachment) async {
        do {
            try await client.deleteAttachment(id: attachment.id)
            guard var copy = payload else { return }
            copy.attachments.removeAll { $0.id == attachment.id }
            payload = copy
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Activity

    func loadActions(cardId: String) async -> [Action] {
        do {
            return try await client.getCardActions(cardId: cardId)
                .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        } catch {
            self.error = error.localizedDescription
            return []
        }
    }

    // MARK: - Stopwatch

    func toggleStopwatch(_ card: Card) async {
        let sw = card.stopwatchValue
        do {
            let updated: Card
            if let sw, sw.isRunning {
                updated = try await client.updateStopwatch(cardId: card.id, total: sw.elapsed(), startedAt: nil)
            } else {
                updated = try await client.updateStopwatch(cardId: card.id, total: sw?.total ?? 0, startedAt: Date())
            }
            replaceCard(updated)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Local state helpers

    private func replaceCard(_ updatedCard: Card) {
        guard var copy = payload else { return }
        copy.cards = copy.cards.map { $0.id == updatedCard.id ? updatedCard : $0 }
        payload = copy
    }

    private func replaceTask(_ updatedTask: PlankaTask) {
        guard var copy = payload else { return }
        copy.tasks = copy.tasks.map { $0.id == updatedTask.id ? updatedTask : $0 }
        payload = copy
    }
}
