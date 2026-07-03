import Foundation
import Testing
@testable import BoardlyKit

// MARK: - Model builders (internal memberwise inits via @testable)

private func makeBoard(id: String = "b1") -> Board {
    Board(
        id: id,
        projectId: "p1",
        position: 1,
        name: "Board",
        defaultView: nil,
        defaultCardType: nil,
        limitCardTypesToDefaultOne: nil,
        alwaysDisplayCardCreator: nil,
        expandTaskListsByDefault: nil,
        createdAt: nil,
        updatedAt: nil)
}

private func makeCard(
    _ id: String,
    list: String = "l1",
    name: String = "Card",
    pos: Double = 1,
    due: Date? = nil) -> Card
{
    Card(
        id: id,
        boardId: "b1",
        listId: list,
        creatorUserId: nil,
        prevListId: nil,
        coverAttachmentId: nil,
        type: "active",
        position: pos,
        name: name,
        description: nil,
        dueDate: due,
        isDueCompleted: nil,
        stopwatch: nil,
        commentsTotal: nil,
        isClosed: nil,
        listChangedAt: nil,
        createdAt: nil,
        updatedAt: nil)
}

private func makeList(_ id: String, name: String = "List", pos: Double = 1) -> PlankaList {
    PlankaList(
        id: id,
        boardId: "b1",
        type: "active",
        position: pos,
        name: name,
        color: nil,
        createdAt: nil,
        updatedAt: nil)
}

private func makeTask(
    _ id: String,
    taskList: String = "tl1",
    name: String = "Task",
    completed: Bool = false) -> PlankaTask
{
    PlankaTask(
        id: id,
        taskListId: taskList,
        linkedCardId: nil,
        assigneeUserId: nil,
        position: 1,
        name: name,
        isCompleted: completed,
        createdAt: nil,
        updatedAt: nil)
}

private func makeLabel(_ id: String, name: String = "Label") -> Label {
    Label(id: id, boardId: "b1", position: 1, name: name, color: "lagoon-blue", createdAt: nil, updatedAt: nil)
}

private func makeUser(_ id: String, name: String = "User") -> User {
    User(
        id: id,
        email: nil,
        role: "member",
        name: name,
        username: nil,
        avatar: nil,
        gravatarUrl: nil,
        phone: nil,
        organization: nil,
        language: nil,
        apiKeyPrefix: nil,
        subscribeToOwnCards: nil,
        subscribeToCardWhenCommenting: nil,
        turnOffRecentCardHighlighting: nil,
        enableFavoritesByDefault: nil,
        defaultEditorMode: nil,
        defaultHomeView: nil,
        defaultProjectsOrder: nil,
        isSsoUser: nil,
        isDeactivated: false,
        isDefaultAdmin: nil,
        createdAt: nil,
        updatedAt: nil)
}

private func makePayload(
    cards: [Card] = [], lists: [PlankaList] = [], tasks: [PlankaTask] = [],
    labels: [Label] = [], cardLabels: [CardLabel] = [], cardMemberships: [CardMembership] = [], users: [User] = []) -> BoardPayload
{
    BoardPayload(
        board: makeBoard(),
        lists: lists,
        cards: cards,
        taskLists: [],
        tasks: tasks,
        labels: labels,
        cardMemberships: cardMemberships,
        cardLabels: cardLabels,
        users: users)
}

private func event(_ name: String, _ json: String) -> BoardRealtimeEvent {
    BoardRealtimeEvent.parse(event: name, payload: Data(json.utf8))!
}

// MARK: - Event parsing

@Suite("Realtime event parsing")
struct RealtimeEventParsingTests {
    @Test("cardCreate parses a full Card")
    func cardCreate() {
        let e = event("cardCreate", #"{"item":{"id":"c9","boardId":"b1","listId":"l1","name":"New"}}"#)
        guard case let .cardCreated(card) = e else { Issue.record("wrong case"); return }
        #expect(card.id == "c9")
        #expect(card.name == "New")
    }

    @Test("cardUpdate parses a partial (position-only) update")
    func cardUpdatePartial() {
        let e = event("cardUpdate", #"{"item":{"id":"c1","position":99}}"#)
        guard case let .cardUpdated(partial) = e else { Issue.record("wrong case"); return }
        #expect(partial.id == "c1")
        #expect(partial.position == 99)
        #expect(partial.name == nil)
    }

    @Test("cardDelete parses the id")
    func cardDelete() {
        let e = event("cardDelete", #"{"item":{"id":"c1","boardId":"b1"}}"#)
        guard case let .cardDeleted(id) = e else { Issue.record("wrong case"); return }
        #expect(id == "c1")
    }

    @Test("unknown event returns nil")
    func unknown() {
        #expect(BoardRealtimeEvent.parse(event: "somethingElse", payload: Data(#"{"item":{}}"#.utf8)) == nil)
    }
}

// MARK: - Reconciliation

@Suite("Realtime reconciliation")
struct RealtimeReconcileTests {
    @Test("cardCreate inserts the card")
    func cardCreateInserts() {
        let payload = makePayload(cards: [makeCard("c1")])
        let result = payload.applying(event(
            "cardCreate",
            #"{"item":{"id":"c2","boardId":"b1","listId":"l1","name":"Second"}}"#))
        #expect(result.cards.count == 2)
        #expect(result.cards.contains { $0.id == "c2" })
    }

    @Test("partial cardUpdate merges, keeping unspecified fields")
    func partialUpdateMerges() {
        let payload = makePayload(cards: [makeCard("c1", name: "Original", pos: 1)])
        let result = payload.applying(event("cardUpdate", #"{"item":{"id":"c1","position":500}}"#))
        let c1 = result.cards.first { $0.id == "c1" }
        #expect(c1?.position == 500)
        #expect(c1?.name == "Original") // untouched
    }

    @Test("full cardUpdate replaces, reflecting cleared fields")
    func fullUpdateReplaces() {
        let payload = makePayload(cards: [makeCard("c1", name: "Original", due: Date())])
        // Full record (carries boardId + listId + name) with dueDate omitted → cleared.
        let result = payload.applying(event(
            "cardUpdate",
            #"{"item":{"id":"c1","boardId":"b1","listId":"l1","name":"Renamed"}}"#))
        let c1 = result.cards.first { $0.id == "c1" }
        #expect(c1?.name == "Renamed")
        #expect(c1?.dueDate == nil)
    }

    @Test("cardDelete removes the card")
    func cardDeleteRemoves() {
        let payload = makePayload(cards: [makeCard("c1"), makeCard("c2")])
        let result = payload.applying(event("cardDelete", #"{"item":{"id":"c1"}}"#))
        #expect(result.cards.map(\.id) == ["c2"])
    }

    @Test("listUpdate partial reposition merges")
    func listRepositionMerges() {
        let payload = makePayload(lists: [makeList("l1", name: "To Do", pos: 1)])
        let result = payload.applying(event("listUpdate", #"{"item":{"id":"l1","position":3}}"#))
        let l1 = result.lists.first { $0.id == "l1" }
        #expect(l1?.position == 3)
        #expect(l1?.name == "To Do")
    }

    @Test("taskUpdate toggling isCompleted merges")
    func taskToggleMerges() {
        let payload = makePayload(tasks: [makeTask("t1", name: "Step", completed: false)])
        let result = payload.applying(event("taskUpdate", #"{"item":{"id":"t1","isCompleted":true}}"#))
        let t1 = result.tasks.first { $0.id == "t1" }
        #expect(t1?.isCompleted == true)
        #expect(t1?.name == "Step")
    }

    @Test("cardLabelCreate assigns a label to the card")
    func cardLabelAssign() throws {
        let payload = makePayload(cards: [makeCard("c1")], labels: [makeLabel("lb1", name: "Design")])
        let result = payload.applying(event("cardLabelCreate", #"{"item":{"id":"cl1","cardId":"c1","labelId":"lb1"}}"#))
        let card = try #require(result.card(id: "c1"))
        #expect(result.labels(for: card).map(\.id) == ["lb1"])
    }

    @Test("cardLabelDelete unassigns the label")
    func cardLabelUnassign() throws {
        let payload = makePayload(
            cards: [makeCard("c1")], labels: [makeLabel("lb1")],
            cardLabels: [CardLabel(id: "cl1", cardId: "c1", labelId: "lb1", createdAt: nil, updatedAt: nil)])
        let result = payload.applying(event("cardLabelDelete", #"{"item":{"id":"cl1"}}"#))
        #expect(try result.labels(for: #require(result.card(id: "c1"))).isEmpty)
    }

    @Test("labelDelete removes the label board-wide")
    func labelDelete() {
        let payload = makePayload(labels: [makeLabel("lb1"), makeLabel("lb2")])
        let result = payload.applying(event("labelDelete", #"{"item":{"id":"lb1"}}"#))
        #expect(result.labels.map(\.id) == ["lb2"])
    }

    @Test("cardMembershipCreate assigns a member")
    func cardMemberAssign() throws {
        let payload = makePayload(cards: [makeCard("c1")], users: [makeUser("u1", name: "Marie")])
        let result = payload.applying(event("cardMembershipCreate", #"{"item":{"id":"cm1","cardId":"c1","userId":"u1"}}"#))
        #expect(try result.members(for: #require(result.card(id: "c1"))).map(\.id) == ["u1"])
    }

    @Test("attachment create then delete")
    func attachmentLifecycle() {
        var payload = makePayload(cards: [makeCard("c1")])
        payload = payload.applying(event(
            "attachmentCreate",
            #"{"item":{"id":"at1","cardId":"c1","type":"file","data":{"url":"x"},"name":"f.png"}}"#))
        #expect(payload.attachments.count == 1)
        payload = payload.applying(event("attachmentDelete", #"{"item":{"id":"at1"}}"#))
        #expect(payload.attachments.isEmpty)
    }

    @Test("resynced replaces the whole payload")
    func resyncedReplaces() {
        let payload = makePayload(cards: [makeCard("c1")])
        let fresh = makePayload(cards: [makeCard("c2"), makeCard("c3")])
        let result = payload.applying(.resynced(fresh))
        #expect(result.cards.map(\.id) == ["c2", "c3"])
    }
}

// MARK: - Custom fields (Phase 7)

@Suite("Realtime custom fields")
struct RealtimeCustomFieldsTests {
    @Test("customFieldValueUpdate parses the full value")
    func parseValue() {
        let e = event(
            "customFieldValueUpdate",
            #"{"item":{"id":"v1","cardId":"c1","customFieldGroupId":"g1","customFieldId":"f1","content":"High"}}"#)
        guard case let .customFieldValueUpdated(value) = e else { Issue.record("wrong case"); return }
        #expect(value.id == "v1")
        #expect(value.content == "High")
    }

    @Test("customFieldGroupDelete parses the id")
    func parseGroupDelete() {
        let e = event("customFieldGroupDelete", #"{"item":{"id":"g1"}}"#)
        guard case let .customFieldGroupDeleted(id) = e else { Issue.record("wrong case"); return }
        #expect(id == "g1")
    }

    @Test("group create → update → delete lifecycle")
    func groupLifecycle() {
        var p = makePayload()
        p = p.applying(event(
            "customFieldGroupCreate",
            #"{"item":{"id":"g1","boardId":"b1","cardId":null,"baseCustomFieldGroupId":"bg1","position":1,"name":"Tracking"}}"#))
        #expect(p.customFieldGroups.map(\.id) == ["g1"])
        p = p.applying(event(
            "customFieldGroupUpdate",
            #"{"item":{"id":"g1","boardId":"b1","cardId":null,"baseCustomFieldGroupId":"bg1","position":1,"name":"Renamed"}}"#))
        #expect(p.customFieldGroups.first?.name == "Renamed")
        p = p.applying(event("customFieldGroupDelete", #"{"item":{"id":"g1"}}"#))
        #expect(p.customFieldGroups.isEmpty)
    }

    @Test("field create → delete lifecycle")
    func fieldLifecycle() {
        var p = makePayload()
        p = p.applying(event(
            "customFieldCreate",
            #"{"item":{"id":"f1","customFieldGroupId":"g1","position":1,"name":"Priority"}}"#))
        #expect(p.customFields.map(\.id) == ["f1"])
        p = p.applying(event("customFieldDelete", #"{"item":{"id":"f1"}}"#))
        #expect(p.customFields.isEmpty)
    }

    @Test("value create → update content → delete lifecycle")
    func valueLifecycle() {
        var p = makePayload()
        p = p.applying(event(
            "customFieldValueCreate",
            #"{"item":{"id":"v1","cardId":"c1","customFieldGroupId":"g1","customFieldId":"f1","content":"Low"}}"#))
        #expect(p.customFieldValues.first?.content == "Low")
        p = p.applying(event(
            "customFieldValueUpdate",
            #"{"item":{"id":"v1","cardId":"c1","customFieldGroupId":"g1","customFieldId":"f1","content":"High"}}"#))
        #expect(p.customFieldValues.first?.content == "High")
        p = p.applying(event("customFieldValueDelete", #"{"item":{"id":"v1"}}"#))
        #expect(p.customFieldValues.isEmpty)
    }
}
