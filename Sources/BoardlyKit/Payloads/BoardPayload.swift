import Foundation

public struct BoardPayload: Sendable {
    public var board: Board
    public var lists: [PlankaList]
    public var cards: [Card]
    public var taskLists: [TaskList]
    public var tasks: [PlankaTask]
    public var labels: [Label]
    public var cardMemberships: [CardMembership]
    public var cardLabels: [CardLabel]
    public var users: [User]
    public var attachments: [Attachment]
    public var boardMemberships: [BoardMembership]
    public var customFieldGroups: [CustomFieldGroup]
    public var customFields: [CustomField]
    public var customFieldValues: [CustomFieldValue]

    public init(
        board: Board,
        lists: [PlankaList],
        cards: [Card],
        taskLists: [TaskList],
        tasks: [PlankaTask],
        labels: [Label],
        cardMemberships: [CardMembership],
        cardLabels: [CardLabel],
        users: [User],
        attachments: [Attachment] = [],
        boardMemberships: [BoardMembership] = [],
        customFieldGroups: [CustomFieldGroup] = [],
        customFields: [CustomField] = [],
        customFieldValues: [CustomFieldValue] = [])
    {
        self.board = board
        self.lists = lists
        self.cards = cards
        self.taskLists = taskLists
        self.tasks = tasks
        self.labels = labels
        self.cardMemberships = cardMemberships
        self.cardLabels = cardLabels
        self.users = users
        self.attachments = attachments
        self.boardMemberships = boardMemberships
        self.customFieldGroups = customFieldGroups
        self.customFields = customFields
        self.customFieldValues = customFieldValues
    }

    public func sortedLists() -> [PlankaList] {
        lists
            .filter { $0.type == "active" }
            .sorted { ($0.position ?? 0) < ($1.position ?? 0) }
    }

    public func cards(for list: PlankaList) -> [Card] {
        cards.filter { $0.listId == list.id }
            .sorted { ($0.position ?? 0) < ($1.position ?? 0) }
    }

    public func card(id: String) -> Card? {
        cards.first { $0.id == id }
    }

    public func taskLists(for card: Card) -> [TaskList] {
        taskLists.filter { $0.cardId == card.id }
            .sorted { ($0.position ?? 0) < ($1.position ?? 0) }
    }

    public func tasks(for taskList: TaskList) -> [PlankaTask] {
        tasks.filter { $0.taskListId == taskList.id }
            .sorted { ($0.position ?? 0) < ($1.position ?? 0) }
    }

    public func nextCardPosition(in list: PlankaList) -> Double {
        let existing = cards(for: list)
        return (existing.last?.position ?? 0) + 65536
    }

    // MARK: - Rich card content (Phase 4)

    /// Labels assigned to a card, in board order.
    public func labels(for card: Card) -> [Label] {
        let ids = Set(cardLabels.filter { $0.cardId == card.id }.map(\.labelId))
        return labels.filter { ids.contains($0.id) }
            .sorted { ($0.position ?? 0) < ($1.position ?? 0) }
    }

    /// Users assigned to a card.
    public func members(for card: Card) -> [User] {
        let ids = Set(cardMemberships.filter { $0.cardId == card.id }.map(\.userId))
        return users.filter { ids.contains($0.id) }
    }

    /// Attachments on a card.
    public func attachments(for card: Card) -> [Attachment] {
        attachments.filter { $0.cardId == card.id }
            .sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
    }

    /// Users who are members of this board (candidates for card assignment).
    public func boardMembers() -> [User] {
        let ids = Set(boardMemberships.map(\.userId))
        return users.filter { ids.contains($0.id) }
    }

    // MARK: - Custom fields (Phase 7)

    /// Board-level custom-field groups, in position order (for board management).
    public func boardCustomFieldGroups() -> [CustomFieldGroup] {
        customFieldGroups.filter { $0.boardId == board.id }
            .sorted { ($0.position ?? 0) < ($1.position ?? 0) }
    }

    /// Custom-field groups applicable to a card — the board's groups plus any
    /// card-specific ones — in position order.
    public func customFieldGroups(for card: Card) -> [CustomFieldGroup] {
        customFieldGroups.filter { $0.boardId == board.id || $0.cardId == card.id }
            .sorted { ($0.position ?? 0) < ($1.position ?? 0) }
    }

    /// Fields belonging to a board/card-level custom-field group, in position order.
    public func fields(in group: CustomFieldGroup) -> [CustomField] {
        customFields.filter { $0.customFieldGroupId == group.id }
            .sorted { ($0.position ?? 0) < ($1.position ?? 0) }
    }

    /// The value a card holds for a given field within a group, if set.
    public func value(on card: Card, group: CustomFieldGroup, field: CustomField) -> CustomFieldValue? {
        customFieldValues.first {
            $0.cardId == card.id && $0.customFieldGroupId == group.id && $0.customFieldId == field.id
        }
    }

    /// Update a card's comment count locally (keeps the board card badge in sync
    /// after the detail view adds/removes a comment).
    public mutating func setCommentsTotal(cardId: String, _ total: Int) {
        cards = cards.map { $0.id == cardId ? $0.withCommentsTotal(total) : $0 }
    }
}

extension Card {
    func withCommentsTotal(_ total: Int) -> Card {
        Card(
            id: id, boardId: boardId, listId: listId, creatorUserId: creatorUserId,
            prevListId: prevListId, coverAttachmentId: coverAttachmentId, type: type,
            position: position, name: name, description: description, dueDate: dueDate,
            isDueCompleted: isDueCompleted, stopwatch: stopwatch, commentsTotal: total,
            isClosed: isClosed, listChangedAt: listChangedAt, createdAt: createdAt, updatedAt: updatedAt)
    }
}
