import Foundation

// Pure, network-free reconciliation of realtime events onto a BoardPayload.
// PLANKA sends either a *full* record (normal create/update — carries the parent
// foreign key) or a *partial* one (e.g. reposition: `{ id, position }`). Full
// records replace (so cleared fields like a removed dueDate are reflected);
// partials merge onto the existing record.

extension BoardPayload {
    public func applying(_ event: BoardRealtimeEvent) -> BoardPayload {
        switch event {
        case .resynced(let payload):
            return payload

        case .cardCreated(let card):
            return with(cards: upsert(cards, card))
        case .cardUpdated(let partial):
            return with(cards: applyCardUpdate(partial))
        case .cardDeleted(let id):
            return with(cards: cards.filter { $0.id != id })

        case .listCreated(let list):
            return with(lists: upsert(lists, list))
        case .listUpdated(let partial):
            return with(lists: applyListUpdate(partial))
        case .listDeleted(let id):
            return with(lists: lists.filter { $0.id != id })

        case .taskCreated(let task):
            return with(tasks: upsert(tasks, task))
        case .taskUpdated(let partial):
            return with(tasks: applyTaskUpdate(partial))
        case .taskDeleted(let id):
            return with(tasks: tasks.filter { $0.id != id })
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
        BoardPayload(
            board: board,
            lists: lists ?? self.lists,
            cards: cards ?? self.cards,
            taskLists: taskLists,
            tasks: tasks ?? self.tasks,
            labels: labels,
            cardMemberships: cardMemberships,
            cardLabels: cardLabels,
            users: users
        )
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
            updatedAt: p.updatedAt ?? updatedAt
        )
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
            isClosed: isClosed, listChangedAt: listChangedAt, createdAt: createdAt, updatedAt: updatedAt
        )
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
            updatedAt: p.updatedAt ?? updatedAt
        )
    }
}

extension PartialList {
    func asFullList() -> PlankaList? {
        guard let boardId else { return nil }
        return PlankaList(
            id: id, boardId: boardId, type: type, position: position,
            name: name, color: color, createdAt: createdAt, updatedAt: updatedAt
        )
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
            updatedAt: p.updatedAt ?? updatedAt
        )
    }
}

extension PartialTask {
    func asFullTask() -> PlankaTask? {
        guard let taskListId, let name, let isCompleted else { return nil }
        return PlankaTask(
            id: id, taskListId: taskListId, linkedCardId: linkedCardId,
            assigneeUserId: assigneeUserId, position: position, name: name,
            isCompleted: isCompleted, createdAt: createdAt, updatedAt: updatedAt
        )
    }
}
