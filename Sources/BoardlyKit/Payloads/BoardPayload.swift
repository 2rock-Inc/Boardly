import Foundation

public struct BoardPayload: Sendable {
    public let board: Board
    public let lists: [PlankaList]
    public let cards: [Card]
    public let taskLists: [TaskList]
    public let tasks: [PlankaTask]
    public let labels: [Label]
    public let cardMemberships: [CardMembership]
    public let cardLabels: [CardLabel]
    public let users: [User]

    public init(
        board: Board,
        lists: [PlankaList],
        cards: [Card],
        taskLists: [TaskList],
        tasks: [PlankaTask],
        labels: [Label],
        cardMemberships: [CardMembership],
        cardLabels: [CardLabel],
        users: [User]
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
    }

    public func sortedLists() -> [PlankaList] {
        lists.sorted { $0.position < $1.position }
    }

    public func cards(for list: PlankaList) -> [Card] {
        cards.filter { $0.listId == list.id }
             .sorted { $0.position < $1.position }
    }

    public func card(id: String) -> Card? {
        cards.first { $0.id == id }
    }

    public func taskLists(for card: Card) -> [TaskList] {
        taskLists.filter { $0.cardId == card.id }
                 .sorted { $0.position < $1.position }
    }

    public func tasks(for taskList: TaskList) -> [PlankaTask] {
        tasks.filter { $0.taskListId == taskList.id }
             .sorted { $0.position < $1.position }
    }

    public func nextCardPosition(in list: PlankaList) -> Double {
        let existing = cards(for: list)
        return (existing.last?.position ?? 0) + 65536
    }
}
