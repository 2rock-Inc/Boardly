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
        boardMemberships: [BoardMembership] = []
    ) {
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
}
