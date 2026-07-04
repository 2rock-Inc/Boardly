import Foundation

// Pure, network-free reconciliation of realtime events onto a BoardPayload.
// PLANKA sends either a *full* record (normal create/update — carries the parent
// foreign key) or a *partial* one (e.g. reposition: `{ id, position }`). Full
// records replace (so cleared fields like a removed dueDate are reflected);
// partials merge onto the existing record.

extension BoardPayload {
    public func applying(_ event: BoardRealtimeEvent) -> BoardPayload {
        // A single per-profile socket carries events for *every* subscribed board,
        // and PLANKA's event names don't name the board — so drop anything that
        // isn't ours before reconciling, or a foreign create would be appended here.
        guard owns(event) else { return self }
        switch event {
        case let .resynced(payload):
            return payload
        case let .cardCreated(card):
            return with(cards: upsert(cards, card))
        case let .cardUpdated(partial):
            return with(cards: applyCardUpdate(partial))
        case let .cardDeleted(id):
            return with(cards: cards.filter { $0.id != id })
        case let .listCreated(list):
            return with(lists: upsert(lists, list))
        case let .listUpdated(partial):
            return with(lists: applyListUpdate(partial))
        case let .listDeleted(id):
            return with(lists: lists.filter { $0.id != id })
        case let .taskCreated(task):
            return with(tasks: upsert(tasks, task))
        case let .taskUpdated(partial):
            return with(tasks: applyTaskUpdate(partial))
        case let .taskDeleted(id):
            return with(tasks: tasks.filter { $0.id != id })
        case let .labelCreated(label):
            var copy = self; copy.labels = upsert(labels, label); return copy
        case let .labelUpdated(label):
            var copy = self; copy.labels = labels.map { $0.id == label.id ? label : $0 }; return copy
        case let .labelDeleted(id):
            var copy = self; copy.labels.removeAll { $0.id == id }; return copy
        case let .cardLabelCreated(cardLabel):
            var copy = self; copy.cardLabels = upsert(cardLabels, cardLabel); return copy
        case let .cardLabelDeleted(id):
            var copy = self; copy.cardLabels.removeAll { $0.id == id }; return copy
        case let .cardMembershipCreated(membership):
            var copy = self; copy.cardMemberships = upsert(cardMemberships, membership); return copy
        case let .cardMembershipDeleted(id):
            var copy = self; copy.cardMemberships.removeAll { $0.id == id }; return copy
        case let .attachmentCreated(attachment):
            var copy = self; copy.attachments = upsert(attachments, attachment); return copy
        case let .attachmentUpdated(attachment):
            var copy = self; copy.attachments = attachments.map { $0.id == attachment.id ? attachment : $0 }; return copy
        case let .attachmentDeleted(id):
            var copy = self; copy.attachments.removeAll { $0.id == id }; return copy
        case let .customFieldGroupCreated(group):
            var copy = self; copy.customFieldGroups = upsert(customFieldGroups, group); return copy
        case let .customFieldGroupUpdated(group):
            var copy = self; copy.customFieldGroups = customFieldGroups.map { $0.id == group.id ? group : $0 }; return copy
        case let .customFieldGroupDeleted(id):
            var copy = self; copy.customFieldGroups.removeAll { $0.id == id }; return copy
        case let .customFieldCreated(field):
            var copy = self; copy.customFields = upsert(customFields, field); return copy
        case let .customFieldUpdated(field):
            var copy = self; copy.customFields = customFields.map { $0.id == field.id ? field : $0 }; return copy
        case let .customFieldDeleted(id):
            var copy = self; copy.customFields.removeAll { $0.id == id }; return copy
        case let .customFieldValueUpdated(value):
            // Upsert: PLANKA emits this even on first set (no separate create event).
            var copy = self; copy.customFieldValues = upsert(customFieldValues, value); return copy
        case let .customFieldValueDeleted(id):
            var copy = self; copy.customFieldValues.removeAll { $0.id == id }; return copy
        }
    }

    // MARK: - Board ownership routing

    /// Whether this event belongs to *this* board, so a shared per-profile socket
    /// can broadcast every event to every open board and let each payload keep only
    /// its own. Events carrying a `boardId` route directly; card/list-child events
    /// route via the parent already held here; id-only deletes match a record we
    /// hold (a no-op otherwise). A `resynced` is only ever delivered to its own
    /// board by the connection, so it always belongs.
    func owns(_ event: BoardRealtimeEvent) -> Bool {
        let boardID = board.id
        func hasCard(_ id: String) -> Bool { cards.contains { $0.id == id } }

        switch event {
        case .resynced:
            return true
        case let .cardCreated(card):
            return card.boardId == boardID
        case let .cardUpdated(partial):
            return partial.boardId == boardID || hasCard(partial.id)
        case let .cardDeleted(id):
            return hasCard(id)
        case let .listCreated(list):
            return list.boardId == boardID
        case let .listUpdated(partial):
            return partial.boardId == boardID || lists.contains { $0.id == partial.id }
        case let .listDeleted(id):
            return lists.contains { $0.id == id }
        case let .taskCreated(task):
            return taskLists.contains { $0.id == task.taskListId }
        case let .taskUpdated(partial):
            return tasks.contains { $0.id == partial.id }
                || (partial.taskListId.map { tl in taskLists.contains { $0.id == tl } } ?? false)
        case let .taskDeleted(id):
            return tasks.contains { $0.id == id }
        case let .labelCreated(label):
            return label.boardId == boardID
        case let .labelUpdated(label):
            return label.boardId == boardID || labels.contains { $0.id == label.id }
        case let .labelDeleted(id):
            return labels.contains { $0.id == id }
        case let .cardLabelCreated(cardLabel):
            return hasCard(cardLabel.cardId)
        case let .cardLabelDeleted(id):
            return cardLabels.contains { $0.id == id }
        case let .cardMembershipCreated(membership):
            return hasCard(membership.cardId)
        case let .cardMembershipDeleted(id):
            return cardMemberships.contains { $0.id == id }
        case let .attachmentCreated(attachment):
            return hasCard(attachment.cardId)
        case let .attachmentUpdated(attachment):
            return hasCard(attachment.cardId) || attachments.contains { $0.id == attachment.id }
        case let .attachmentDeleted(id):
            return attachments.contains { $0.id == id }
        case let .customFieldGroupCreated(group):
            return group.boardId == boardID || (group.cardId.map(hasCard) ?? false)
        case let .customFieldGroupUpdated(group):
            return group.boardId == boardID
                || (group.cardId.map(hasCard) ?? false)
                || customFieldGroups.contains { $0.id == group.id }
        case let .customFieldGroupDeleted(id):
            return customFieldGroups.contains { $0.id == id }
        case let .customFieldCreated(field):
            return field.customFieldGroupId.map { gid in customFieldGroups.contains { $0.id == gid } } ?? false
        case let .customFieldUpdated(field):
            return customFields.contains { $0.id == field.id }
                || (field.customFieldGroupId.map { gid in customFieldGroups.contains { $0.id == gid } } ?? false)
        case let .customFieldDeleted(id):
            return customFields.contains { $0.id == id }
        case let .customFieldValueUpdated(value):
            return hasCard(value.cardId)
        case let .customFieldValueDeleted(id):
            return customFieldValues.contains { $0.id == id }
        }
    }

    // MARK: - Update appliers

    private func applyCardUpdate(_ p: PartialCard) -> [Card] {
        if cards.contains(where: { $0.id == p.id }) {
            return cards.map { $0.id == p.id ? (p.asFullCard() ?? $0.merging(p)) : $0 }
        } else if let full = p.asFullCard() {
            return cards + [full]
        }
        return cards
    }

    private func applyListUpdate(_ p: PartialList) -> [PlankaList] {
        if lists.contains(where: { $0.id == p.id }) {
            return lists.map { $0.id == p.id ? (p.asFullList() ?? $0.merging(p)) : $0 }
        } else if let full = p.asFullList() {
            return lists + [full]
        }
        return lists
    }

    private func applyTaskUpdate(_ p: PartialTask) -> [PlankaTask] {
        if tasks.contains(where: { $0.id == p.id }) {
            return tasks.map { $0.id == p.id ? (p.asFullTask() ?? $0.merging(p)) : $0 }
        } else if let full = p.asFullTask() {
            return tasks + [full]
        }
        return tasks
    }

    // MARK: - Rebuild helpers

    private func upsert<T: Identifiable>(_ items: [T], _ new: T) -> [T] where T.ID == String {
        items.contains(where: { $0.id == new.id })
            ? items.map { $0.id == new.id ? new : $0 }
            : items + [new]
    }

    private func with(cards: [Card]? = nil, lists: [PlankaList]? = nil, tasks: [PlankaTask]? = nil) -> BoardPayload {
        var copy = self
        if let cards { copy.cards = cards }
        if let lists { copy.lists = lists }
        if let tasks { copy.tasks = tasks }
        return copy
    }
}

// MARK: - Merge / promotion helpers (BoardlyKit-internal: use memberwise inits)

extension Card {
    func merging(_ p: PartialCard) -> Card {
        Card(
            id: id,
            boardId: p.boardId ?? boardId,
            listId: p.listId ?? listId,
            creatorUserId: p.creatorUserId ?? creatorUserId,
            prevListId: p.prevListId ?? prevListId,
            coverAttachmentId: p.coverAttachmentId ?? coverAttachmentId,
            type: p.type ?? type,
            position: p.position ?? position,
            name: p.name ?? name,
            description: p.description ?? description,
            dueDate: p.dueDate ?? dueDate,
            isDueCompleted: p.isDueCompleted ?? isDueCompleted,
            stopwatch: p.stopwatch ?? stopwatch,
            commentsTotal: p.commentsTotal ?? commentsTotal,
            isClosed: p.isClosed ?? isClosed,
            listChangedAt: p.listChangedAt ?? listChangedAt,
            createdAt: p.createdAt ?? createdAt,
            updatedAt: p.updatedAt ?? updatedAt)
    }
}

extension PartialCard {
    /// A full card when the payload carries the parent FK + required fields,
    /// i.e. a normal create/update rather than a partial (reposition) update.
    func asFullCard() -> Card? {
        guard let boardId, let listId, let name else { return nil }
        return Card(
            id: id, boardId: boardId, listId: listId, creatorUserId: creatorUserId,
            prevListId: prevListId, coverAttachmentId: coverAttachmentId, type: type,
            position: position, name: name, description: description, dueDate: dueDate,
            isDueCompleted: isDueCompleted, stopwatch: stopwatch, commentsTotal: commentsTotal,
            isClosed: isClosed, listChangedAt: listChangedAt, createdAt: createdAt, updatedAt: updatedAt)
    }
}

extension PlankaList {
    func merging(_ p: PartialList) -> PlankaList {
        PlankaList(
            id: id,
            boardId: p.boardId ?? boardId,
            type: p.type ?? type,
            position: p.position ?? position,
            name: p.name ?? name,
            color: p.color ?? color,
            createdAt: p.createdAt ?? createdAt,
            updatedAt: p.updatedAt ?? updatedAt)
    }
}

extension PartialList {
    func asFullList() -> PlankaList? {
        guard let boardId else { return nil }
        return PlankaList(
            id: id, boardId: boardId, type: type, position: position,
            name: name, color: color, createdAt: createdAt, updatedAt: updatedAt)
    }
}

extension PlankaTask {
    func merging(_ p: PartialTask) -> PlankaTask {
        PlankaTask(
            id: id,
            taskListId: p.taskListId ?? taskListId,
            linkedCardId: p.linkedCardId ?? linkedCardId,
            assigneeUserId: p.assigneeUserId ?? assigneeUserId,
            position: p.position ?? position,
            name: p.name ?? name,
            isCompleted: p.isCompleted ?? isCompleted,
            createdAt: p.createdAt ?? createdAt,
            updatedAt: p.updatedAt ?? updatedAt)
    }
}

extension PartialTask {
    func asFullTask() -> PlankaTask? {
        guard let taskListId, let name, let isCompleted else { return nil }
        return PlankaTask(
            id: id, taskListId: taskListId, linkedCardId: linkedCardId,
            assigneeUserId: assigneeUserId, position: position, name: name,
            isCompleted: isCompleted, createdAt: createdAt, updatedAt: updatedAt)
    }
}
