import Foundation

// Pure, network-free reconciliation of realtime events onto a BoardPayload.
// PLANKA sends either a *full* record (normal create/update — carries the parent
// foreign key) or a *partial* one (e.g. reposition: `{ id, position }`). Full
// records replace (so cleared fields like a removed dueDate are reflected);
// partials merge onto the existing record.

extension BoardPayload {
    public func applying(_ event: BoardRealtimeEvent) -> BoardPayload {
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
