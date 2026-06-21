import Testing
import Foundation
@testable import BoardlyKit

@Suite("BoardPayload")
struct BoardPayloadTests {

    // MARK: - Fixture decoding

    @Test("Decode board detail fixture — lists, cards, tasks")
    func decodeBoardDetail() throws {
        let data = loadFixture("board_detail")

        struct BoardIncluded: Decodable {
            let lists: [PlankaList]?
            let cards: [Card]?
            let taskLists: [TaskList]?
            let tasks: [PlankaTask]?
            let labels: [Label]?
            let cardMemberships: [CardMembership]?
            let cardLabels: [CardLabel]?
            let users: [User]?
        }
        struct Response: Decodable {
            let item: Board
            let included: BoardIncluded
        }

        let response = try JSONDecoder.planka.decode(Response.self, from: data)
        let inc = response.included

        #expect(response.item.name == "Sprint 1")
        #expect((inc.lists ?? []).count == 2)
        #expect((inc.cards ?? []).count == 2)
        #expect((inc.taskLists ?? []).count == 1)
        #expect((inc.tasks ?? []).count == 2)
    }

    @Test("Decode projects fixture — items and included boards")
    func decodeProjects() throws {
        let data = loadFixture("projects")

        struct ProjectsIncluded: Decodable { let boards: [Board] }
        struct Response: Decodable { let items: [Project]; let included: ProjectsIncluded }

        let response = try JSONDecoder.planka.decode(Response.self, from: data)
        #expect(response.items.count == 1)
        #expect(response.items[0].name == "My Project")
        #expect(response.included.boards.count == 1)
        #expect(response.included.boards[0].name == "Sprint 1")
    }

    // MARK: - BoardPayload helpers

    @Test("cards(for:) filters and sorts by position")
    func cardsForList() throws {
        let payload = try makePayload()
        let lists = payload.sortedLists()

        #expect(lists.count == 2)
        let todoCards = payload.cards(for: lists[0])
        let inProgressCards = payload.cards(for: lists[1])

        #expect(todoCards.count == 1)
        #expect(todoCards[0].name == "Implement login")
        #expect(inProgressCards.count == 1)
        #expect(inProgressCards[0].name == "Fix crash on startup")
    }

    @Test("taskLists(for:) returns tasks lists of a card")
    func taskListsForCard() throws {
        let payload = try makePayload()
        let card = try #require(payload.card(id: "card-001"))
        let taskLists = payload.taskLists(for: card)

        #expect(taskLists.count == 1)
        #expect(taskLists[0].name == "Tasks")
    }

    @Test("tasks(for:) returns sorted tasks of a task list")
    func tasksForTaskList() throws {
        let payload = try makePayload()
        let card = try #require(payload.card(id: "card-001"))
        let taskList = try #require(payload.taskLists(for: card).first)
        let tasks = payload.tasks(for: taskList)

        #expect(tasks.count == 2)
        #expect(tasks[0].name == "Write unit tests")
        #expect(tasks[0].isCompleted == false)
        #expect(tasks[1].name == "Code review")
        #expect(tasks[1].isCompleted == true)
    }

    @Test("nextCardPosition returns last position + 65536")
    func nextCardPosition() throws {
        let payload = try makePayload()
        let lists = payload.sortedLists()
        let position = payload.nextCardPosition(in: lists[0])
        #expect(position == 65536 + 65536)
    }

    @Test("sortedLists orders by position ascending")
    func sortedLists() throws {
        let payload = try makePayload()
        let lists = payload.sortedLists()
        #expect(lists[0].id == "list-001")
        #expect(lists[1].id == "list-002")
    }

    // MARK: - Helper

    private func makePayload() throws -> BoardPayload {
        let data = loadFixture("board_detail")

        struct BoardIncluded: Decodable {
            let lists: [PlankaList]?
            let cards: [Card]?
            let taskLists: [TaskList]?
            let tasks: [PlankaTask]?
            let labels: [Label]?
            let cardMemberships: [CardMembership]?
            let cardLabels: [CardLabel]?
            let users: [User]?
        }
        struct Response: Decodable {
            let item: Board
            let included: BoardIncluded
        }

        let response = try JSONDecoder.planka.decode(Response.self, from: data)
        let inc = response.included
        return BoardPayload(
            board: response.item,
            lists: inc.lists ?? [],
            cards: inc.cards ?? [],
            taskLists: inc.taskLists ?? [],
            tasks: inc.tasks ?? [],
            labels: inc.labels ?? [],
            cardMemberships: inc.cardMemberships ?? [],
            cardLabels: inc.cardLabels ?? [],
            users: inc.users ?? []
        )
    }
}
