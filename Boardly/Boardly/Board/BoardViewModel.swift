import BoardlyKit
import Foundation

@Observable
@MainActor
final class BoardViewModel {
    var payload: BoardPayload?
    var isLoading = false
    var error: String?

    /// The project's base custom-field groups (loaded on demand for the board's
    /// custom-fields management sheet).
    var baseGroups: [BaseCustomFieldGroup] = []
    private var baseFields: [CustomField] = []

    private let client: PlankaClient
    let boardId: String
    private var connection: ProfileRealtimeConnection?
    private var realtimeTask: Task<Void, Never>?
    /// Stable identity for this session's stream on the shared connection, so a
    /// stale teardown can't close a newer session's board stream.
    private let realtimeOwner = UUID()

    init(client: PlankaClient, boardId: String) {
        self.client = client
        self.boardId = boardId
    }

    // MARK: - Real-time sync

    /// Subscribe this board to live events over the profile's *shared* connection
    /// and apply them to `payload`. Non-blocking: the event loop runs in a stored
    /// Task tied to the view model's lifetime (not the view's), so pushing the card
    /// detail doesn't tear it down. Realtime is owned per profile, not per board —
    /// see `BoardSessionStore`.
    func startRealtime(using connection: ProfileRealtimeConnection) {
        guard realtimeTask == nil else { return }
        self.connection = connection
        let boardId = boardId
        let owner = realtimeOwner
        realtimeTask = Task { [weak self] in
            let stream = await connection.openBoard(boardId, owner: owner)
            // Torn down before the open landed → close the stream we just opened so
            // it doesn't leak (its owner match still holds).
            if Task.isCancelled {
                await connection.closeBoard(boardId, owner: owner)
                return
            }
            for await event in stream {
                guard let self else { break }
                if let current = payload {
                    payload = current.applying(event)
                } else if case let .resynced(fresh) = event {
                    payload = fresh
                }
            }
        }
    }

    /// Leave the board's room on the shared connection. Must be called only when
    /// actually leaving the board (the connection disconnects when its last board
    /// leaves).
    func stopRealtime() async {
        realtimeTask?.cancel()
        realtimeTask = nil
        await connection?.closeBoard(boardId, owner: realtimeOwner)
        connection = nil
    }

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            payload = try await client.getBoard(id: boardId)
        } catch {
            self.error = localizedErrorMessage(error)
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
            self.error = localizedErrorMessage(error)
        }
    }

    func moveCard(_ card: Card, to list: PlankaList) async {
        guard let payload else { return }
        let position = payload.nextCardPosition(in: list)
        do {
            let updated = try await client.updateCard(
                id: card.id,
                patch: CardPatch(listId: list.id, position: position))
            replaceCard(updated)
        } catch {
            self.error = localizedErrorMessage(error)
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
            self.error = localizedErrorMessage(error)
        }
    }

    // MARK: - Task CRUD

    func toggleTask(_ task: PlankaTask) async {
        do {
            let updated = try await client.updateTask(
                id: task.id,
                patch: TaskPatch(isCompleted: !task.isCompleted))
            replaceTask(updated)
        } catch {
            self.error = localizedErrorMessage(error)
        }
    }

    func createTask(in taskList: TaskList, name: String) async {
        guard let payload else { return }
        let position = (payload.tasks(for: taskList).last?.position ?? 0) + 65536
        do {
            let task = try await client.createTask(
                taskListId: taskList.id,
                name: name,
                position: position)
            var updated = payload
            updated.tasks.append(task)
            self.payload = updated
        } catch {
            self.error = localizedErrorMessage(error)
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
            self.error = localizedErrorMessage(error)
        }
    }

    func updateCard(_ card: Card, patch: CardPatch) async {
        do {
            let updated = try await client.updateCard(id: card.id, patch: patch)
            replaceCard(updated)
        } catch {
            self.error = localizedErrorMessage(error)
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
            self.error = localizedErrorMessage(error)
        }
    }

    func removeLabel(_ label: Label, from card: Card) async {
        do {
            try await client.removeCardLabel(cardId: card.id, labelId: label.id)
            guard var copy = payload else { return }
            copy.cardLabels.removeAll { $0.cardId == card.id && $0.labelId == label.id }
            payload = copy
        } catch {
            self.error = localizedErrorMessage(error)
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
            self.error = localizedErrorMessage(error)
        }
    }

    // MARK: - Custom field values (Phase 7)

    func setCustomFieldValue(_ content: String, groupId: String, fieldId: String, card: Card) async {
        do {
            let value = try await client.setCustomFieldValue(
                cardId: card.id, groupId: groupId, fieldId: fieldId, content: content)
            guard var copy = payload else { return }
            if let idx = copy.customFieldValues.firstIndex(where: { $0.id == value.id }) {
                copy.customFieldValues[idx] = value
            } else {
                copy.customFieldValues.append(value)
            }
            payload = copy
        } catch {
            self.error = localizedErrorMessage(error)
        }
    }

    func clearCustomFieldValue(groupId: String, fieldId: String, card: Card) async {
        do {
            try await client.clearCustomFieldValue(cardId: card.id, groupId: groupId, fieldId: fieldId)
            guard var copy = payload else { return }
            copy.customFieldValues.removeAll {
                $0.cardId == card.id && $0.customFieldGroupId == groupId && $0.customFieldId == fieldId
            }
            payload = copy
        } catch {
            self.error = localizedErrorMessage(error)
        }
    }

    // MARK: - Custom field groups (Phase 7 · board management)

    /// Load the project's base custom-field groups (the "inherited" candidates).
    func loadBaseGroups() async {
        guard let projectId = payload?.board.projectId else { return }
        do {
            let projects = try await client.getProjects()
            guard let project = projects.projects.first(where: { $0.id == projectId }) else { return }
            baseGroups = projects.baseGroups(for: project)
            baseFields = projects.customFields
        } catch {
            self.error = localizedErrorMessage(error)
        }
    }

    func fields(inBaseGroup group: BaseCustomFieldGroup) -> [CustomField] {
        baseFields.filter { $0.baseCustomFieldGroupId == group.id }
            .sorted { ($0.position ?? 0) < ($1.position ?? 0) }
    }

    /// The board's instance of a base group, if it has been enabled.
    func instance(ofBase base: BaseCustomFieldGroup) -> CustomFieldGroup? {
        payload?.customFieldGroups.first { $0.baseCustomFieldGroupId == base.id }
    }

    /// Enable a base group on this board (the server copies its fields), then refresh.
    func enableBaseGroup(_ base: BaseCustomFieldGroup) async {
        guard let payload else { return }
        let position = (payload.boardCustomFieldGroups().map { $0.position ?? 0 }.max() ?? 0) + 65536
        do {
            _ = try await client.createBoardCustomFieldGroup(
                boardId: boardId, position: position, baseCustomFieldGroupId: base.id)
            await refreshCustomFields()
        } catch {
            self.error = localizedErrorMessage(error)
        }
    }

    func disableBaseGroup(_ base: BaseCustomFieldGroup) async {
        guard let group = instance(ofBase: base) else { return }
        await deleteCustomFieldGroup(group)
    }

    func addBoardGroup(name: String) async {
        guard let payload else { return }
        let position = (payload.boardCustomFieldGroups().map { $0.position ?? 0 }.max() ?? 0) + 65536
        do {
            let group = try await client.createBoardCustomFieldGroup(boardId: boardId, position: position, name: name)
            guard var copy = self.payload else { return }
            copy.customFieldGroups.append(group)
            self.payload = copy
        } catch {
            self.error = localizedErrorMessage(error)
        }
    }

    func deleteCustomFieldGroup(_ group: CustomFieldGroup) async {
        do {
            try await client.deleteCustomFieldGroup(id: group.id)
            guard var copy = payload else { return }
            copy.customFieldGroups.removeAll { $0.id == group.id }
            copy.customFields.removeAll { $0.customFieldGroupId == group.id }
            copy.customFieldValues.removeAll { $0.customFieldGroupId == group.id }
            payload = copy
        } catch {
            self.error = localizedErrorMessage(error)
        }
    }

    func addCustomField(to group: CustomFieldGroup, name: String) async {
        guard let payload else { return }
        let position = (payload.fields(in: group).map { $0.position ?? 0 }.max() ?? 0) + 65536
        do {
            let field = try await client.createCustomFieldInGroup(groupId: group.id, name: name, position: position)
            guard var copy = self.payload else { return }
            copy.customFields.append(field)
            self.payload = copy
        } catch {
            self.error = localizedErrorMessage(error)
        }
    }

    func deleteCustomField(_ field: CustomField) async {
        do {
            try await client.deleteCustomField(id: field.id)
            guard var copy = payload else { return }
            copy.customFields.removeAll { $0.id == field.id }
            copy.customFieldValues.removeAll { $0.customFieldId == field.id }
            payload = copy
        } catch {
            self.error = localizedErrorMessage(error)
        }
    }

    /// Re-fetch only the custom-field collections from the board (used after
    /// enabling a base group, whose fields are copied server-side).
    private func refreshCustomFields() async {
        do {
            let fresh = try await client.getBoard(id: boardId)
            guard var copy = payload else { return }
            copy.customFieldGroups = fresh.customFieldGroups
            copy.customFields = fresh.customFields
            copy.customFieldValues = fresh.customFieldValues
            payload = copy
        } catch {
            self.error = localizedErrorMessage(error)
        }
    }

    // MARK: - Board actions

    /// Flips to true once the board is deleted server-side; the view pops on it.
    var boardDeleted = false

    func renameBoard(to name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let board = try await client.renameBoard(id: boardId, name: trimmed)
            guard var copy = payload else { return }
            copy.board = board
            payload = copy
        } catch {
            self.error = localizedErrorMessage(error)
        }
    }

    func deleteBoard() async {
        do {
            try await client.deleteBoard(id: boardId)
            boardDeleted = true
        } catch {
            self.error = localizedErrorMessage(error)
        }
    }

    /// CSV of the board's cards (list · card · labels · members · due · completed).
    func exportCSV() -> String {
        guard let payload else { return "" }
        func field(_ s: String) -> String {
            (s.contains(",") || s.contains("\"") || s.contains("\n"))
                ? "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\""
                : s
        }
        let iso = ISO8601DateFormatter()
        var rows = ["List,Card,Labels,Members,Due,Completed"]
        for list in payload.sortedLists() {
            for card in payload.cards(for: list) {
                let labels = payload.labels(for: card).compactMap(\.name).joined(separator: " ")
                let members = payload.members(for: card).map(\.name).joined(separator: " ")
                let due = card.dueDate.map { iso.string(from: $0) } ?? ""
                let done = card.isDueCompleted == true ? "yes" : ""
                rows.append([list.name ?? "", card.name, labels, members, due, done].map(field).joined(separator: ","))
            }
        }
        return rows.joined(separator: "\n")
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
            self.error = localizedErrorMessage(error)
        }
    }

    func removeMember(_ user: User, from card: Card) async {
        do {
            try await client.removeCardMember(cardId: card.id, userId: user.id)
            guard var copy = payload else { return }
            copy.cardMemberships.removeAll { $0.cardId == card.id && $0.userId == user.id }
            payload = copy
        } catch {
            self.error = localizedErrorMessage(error)
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
            self.error = localizedErrorMessage(error)
            return nil
        }
    }

    func postComment(cardId: String, text: String) async -> Comment? {
        do {
            let comment = try await client.createComment(cardId: cardId, text: text)
            adjustCommentsTotal(cardId: cardId, by: 1)
            return comment
        } catch {
            self.error = localizedErrorMessage(error)
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
            self.error = localizedErrorMessage(error)
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
                cardId: cardId, fileName: fileName, mimeType: mimeType, data: data)
            guard var copy = payload else { return }
            copy.attachments.append(attachment)
            payload = copy
        } catch {
            self.error = localizedErrorMessage(error)
        }
    }

    func addLinkAttachment(cardId: String, url: String, name: String) async {
        do {
            let attachment = try await client.addLinkAttachment(cardId: cardId, url: url, name: name)
            guard var copy = payload else { return }
            copy.attachments.append(attachment)
            payload = copy
        } catch {
            self.error = localizedErrorMessage(error)
        }
    }

    func removeAttachment(_ attachment: Attachment) async {
        do {
            try await client.deleteAttachment(id: attachment.id)
            guard var copy = payload else { return }
            copy.attachments.removeAll { $0.id == attachment.id }
            payload = copy
        } catch {
            self.error = localizedErrorMessage(error)
        }
    }

    // MARK: - Activity

    func loadActions(cardId: String) async -> [Action] {
        do {
            return try await client.getCardActions(cardId: cardId)
                .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        } catch {
            self.error = localizedErrorMessage(error)
            return []
        }
    }

    // MARK: - Stopwatch

    func toggleStopwatch(_ card: Card) async {
        let sw = card.stopwatchValue
        do {
            let updated: Card = if let sw, sw.isRunning {
                try await client.updateStopwatch(cardId: card.id, total: sw.elapsed(), startedAt: nil)
            } else {
                try await client.updateStopwatch(cardId: card.id, total: sw?.total ?? 0, startedAt: Date())
            }
            replaceCard(updated)
        } catch {
            self.error = localizedErrorMessage(error)
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
